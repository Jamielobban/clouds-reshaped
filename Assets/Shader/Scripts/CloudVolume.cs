using System;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
[DisallowMultipleComponent]
public sealed class CloudVolume : MonoBehaviour
{
    public const int MaxShapes = 8;

    [Header("Material")]
    [SerializeField] private Material materialTemplate;

    [Header("Volume Bounds")]
    [SerializeField] private CloudVolumeBounds volumeBounds;

    [Header("Noise")]
    [Tooltip("Offsets this cloud inside its local 3D noise field.")]
    [SerializeField] private Vector3 noiseOffset;

    [Header("Camera Rendering")]
    [SerializeField] private bool renderInGameView = true;
    [SerializeField] private bool renderInSceneView = true;

    private readonly Matrix4x4[] packedShapeMatrices = new Matrix4x4[MaxShapes];
    private readonly Vector4[] packedShapeData0 = new Vector4[MaxShapes];
    private readonly Vector4[] packedShapeData1 = new Vector4[MaxShapes];
    private readonly List<CloudSdfShape> shapes = new List<CloudSdfShape>();

    private Material runtimeMaterial;
    private Material cachedTemplate;
    private bool shapeCacheDirty = true;

    private static readonly int BoundsMinId = Shader.PropertyToID("_BoundsMin");
    private static readonly int BoundsMaxId = Shader.PropertyToID("_BoundsMax");
    private static readonly int CloudWorldToNoiseId = Shader.PropertyToID("_CloudWorldToNoise");
    private static readonly int NoiseOffsetId = Shader.PropertyToID("_NoiseOffset");
    private static readonly int CloudDistanceScaleId = Shader.PropertyToID("_CloudDistanceScale");
    private static readonly int NoiseReferenceSizeId = Shader.PropertyToID("_NoiseReferenceSize");

    private static readonly int ShapeCountId = Shader.PropertyToID("_ShapeCount");
    private static readonly int ShapeMatricesId = Shader.PropertyToID("_ShapeWorldToLocal");
    private static readonly int ShapeData0Id = Shader.PropertyToID("_ShapeData0");
    private static readonly int ShapeData1Id = Shader.PropertyToID("_ShapeData1");

    private static readonly int ShapeWarpStrengthId = Shader.PropertyToID("_ShapeWarpStrength");
    private static readonly int BillowStrengthId = Shader.PropertyToID("_BillowStrength");
    private static readonly int SecondaryBillowStrengthId = Shader.PropertyToID("_SecondaryBillowStrength");
    private static readonly int SurfaceErosionStrengthId = Shader.PropertyToID("_SurfaceErosionStrength");
    private static readonly int ShapeSoftnessId = Shader.PropertyToID("_ShapeSoftness");
    private static readonly int EdgeWispReachId = Shader.PropertyToID("_EdgeWispReach");

    public Material RuntimeMaterial => runtimeMaterial;

    private void OnEnable()
    {
        FindBounds();
        EnsureRuntimeMaterial();
        MarkDirty();

        CloudVolumeRegistry.Register(this);
    }

    private void OnDisable()
    {
        CloudVolumeRegistry.Unregister(this);
        ReleaseRuntimeMaterial();
    }

    private void OnDestroy()
    {
        CloudVolumeRegistry.Unregister(this);
        ReleaseRuntimeMaterial();
    }

    private void OnValidate()
    {
        FindBounds();
        EnsureRuntimeMaterial();
        MarkDirty();
    }

    private void OnTransformChildrenChanged()
    {
        MarkDirty();
    }

    private void FindBounds()
    {
        if (volumeBounds != null) return;

        volumeBounds = GetComponentInChildren<CloudVolumeBounds>(true);
    }

    public void MarkDirty()
    {
        shapeCacheDirty = true;
    }

    private void RefreshShapeCache()
    {
        shapes.Clear();

        CloudSdfShape[] foundShapes =
            GetComponentsInChildren<CloudSdfShape>(true);

        for (int i = 0; i < foundShapes.Length; i++)
        {
            CloudSdfShape shape = foundShapes[i];

            if (shape == null) continue;
            shapes.Add(shape);
        }

        shapes.Sort(CompareShapes);
        shapeCacheDirty = false;
    }

    private static int CompareShapes(
        CloudSdfShape a,
        CloudSdfShape b
    )
    {
        int operationComparison =
            a.Operation.CompareTo(b.Operation);

        if (operationComparison != 0)
        {
            return operationComparison;
        }

        int orderComparison =
            a.Order.CompareTo(b.Order);

        if (orderComparison != 0)
        {
            return orderComparison;
        }

        return a.GetInstanceID().CompareTo(b.GetInstanceID());
    }

    private void EnsureRuntimeMaterial()
    {
        if (materialTemplate == null)
        {
            ReleaseRuntimeMaterial();
            return;
        }

        bool requiresNewMaterial =
            runtimeMaterial == null ||
            cachedTemplate != materialTemplate ||
            runtimeMaterial.shader != materialTemplate.shader;

        if (!requiresNewMaterial) return;

        ReleaseRuntimeMaterial();

        runtimeMaterial = new Material(materialTemplate)
        {
            name = $"{materialTemplate.name} ({name} Runtime)",
            hideFlags = HideFlags.HideAndDontSave
        };

        cachedTemplate = materialTemplate;
    }

    private void ReleaseRuntimeMaterial()
    {
        if (runtimeMaterial == null) return;

        if (Application.isPlaying)
        {
            Destroy(runtimeMaterial);
        }
        else
        {
            DestroyImmediate(runtimeMaterial);
        }

        runtimeMaterial = null;
        cachedTemplate = null;
    }

    public bool ShouldRender(Camera camera)
    {
        if (!isActiveAndEnabled || camera == null) return false;

        switch (camera.cameraType)
        {
            case CameraType.Game:
                return renderInGameView;

            case CameraType.SceneView:
                return renderInSceneView;

            default:
                return false;
        }
    }

    public bool PrepareForRendering(Camera camera)
    {
        return PrepareForRendering(camera, null);
    }

    public bool PrepareForRendering(
        Camera camera,
        Plane[] cameraFrustumPlanes
    )
    {
        if (!ShouldRender(camera)) return false;

        FindBounds();
        EnsureRuntimeMaterial();

        if (
            runtimeMaterial == null ||
            materialTemplate == null ||
            volumeBounds == null
        )
        {
            return false;
        }

        if (shapeCacheDirty) RefreshShapeCache();

        runtimeMaterial.CopyPropertiesFromMaterial(materialTemplate);

        Bounds bounds = volumeBounds.GetWorldBounds(this);

        if (
            cameraFrustumPlanes != null &&
            !GeometryUtility.TestPlanesAABB(
                cameraFrustumPlanes,
                bounds
            )
        )
        {
            return false;
        }

        runtimeMaterial.SetVector(
            BoundsMinId,
            new Vector4(
                bounds.min.x,
                bounds.min.y,
                bounds.min.z,
                0f
            )
        );

        runtimeMaterial.SetVector(
            BoundsMaxId,
            new Vector4(
                bounds.max.x,
                bounds.max.y,
                bounds.max.z,
                0f
            )
        );

        // Author all cloud-detail distances at a reference cloud size, then
        // scale them as one coherent system. This makes a small copy retain the
        // same lobes, wisps, opacity and sampling quality as the large source.
        float referenceSize = Mathf.Max(
            runtimeMaterial.HasProperty(NoiseReferenceSizeId)
                ? runtimeMaterial.GetFloat(NoiseReferenceSizeId)
                : 24f,
            0.001f
        );

        float cloudWorldSize = EstimateCloudWorldSize(bounds);
        float cloudDistanceScale = Mathf.Max(
            cloudWorldSize / referenceSize,
            0.001f
        );

        runtimeMaterial.SetFloat(
            CloudDistanceScaleId,
            cloudDistanceScale
        );

        // Keep the procedural field in world space. Cloud transforms still
        // define the density envelope, but translating or rotating one volume
        // cannot rotate its wind or create a different noise frame from its
        // neighbours. The uniform scale remains independent of bounds padding.
        Matrix4x4 noiseLocalToWorld = Matrix4x4.TRS(
            Vector3.zero,
            Quaternion.identity,
            Vector3.one * cloudDistanceScale
        );

        runtimeMaterial.SetMatrix(
            CloudWorldToNoiseId,
            noiseLocalToWorld.inverse
        );

        runtimeMaterial.SetVector(
            NoiseOffsetId,
            new Vector4(
                noiseOffset.x,
                noiseOffset.y,
                noiseOffset.z,
                0f
            )
        );

        ClearPackedShapeData();

        int packedCount = 0;

        for (
            int i = 0;
            i < shapes.Count && packedCount < MaxShapes;
            i++
        )
        {
            CloudSdfShape shape = shapes[i];

            if (
                shape == null ||
                !shape.isActiveAndEnabled ||
                !shape.gameObject.activeInHierarchy
            )
            {
                continue;
            }

            packedShapeMatrices[packedCount] =
                shape.transform.worldToLocalMatrix;

            packedShapeData0[packedCount] = new Vector4(
                (float)shape.ShapeType,
                (float)shape.Operation,
                shape.Blend,
                1f
            );

            packedShapeData1[packedCount] = new Vector4(
                shape.Radius,
                shape.DistanceScale,
                0f,
                0f
            );

            packedCount++;
        }

        runtimeMaterial.SetInt(ShapeCountId, packedCount);
        runtimeMaterial.SetMatrixArray(ShapeMatricesId, packedShapeMatrices);
        runtimeMaterial.SetVectorArray(ShapeData0Id, packedShapeData0);
        runtimeMaterial.SetVectorArray(ShapeData1Id, packedShapeData1);

        // Bounds-driven density does not require an SDF child. Shape data is
        // still uploaded so materials can opt into the legacy SDF envelope.
        return true;
    }

    private float EstimateCloudWorldSize(Bounds fallbackBounds)
    {
        float largestAdditiveShape = 0f;

        for (int i = 0; i < shapes.Count; i++)
        {
            CloudSdfShape shape = shapes[i];

            if (
                shape == null ||
                !shape.isActiveAndEnabled ||
                !shape.gameObject.activeInHierarchy ||
                shape.Operation != CloudSdfOperation.Add
            )
            {
                continue;
            }

            largestAdditiveShape = Mathf.Max(
                largestAdditiveShape,
                shape.DistanceScale
            );
        }

        if (largestAdditiveShape > 0.001f)
        {
            return largestAdditiveShape;
        }

        Vector3 fallbackSize = fallbackBounds.size;

        return Mathf.Max(
            Mathf.Min(
                fallbackSize.x,
                fallbackSize.y,
                fallbackSize.z
            ),
            0.001f
        );
    }

    private void ClearPackedShapeData()
    {
        for (int i = 0; i < MaxShapes; i++)
        {
            packedShapeMatrices[i] = Matrix4x4.identity;
            packedShapeData0[i] = Vector4.zero;
            packedShapeData1[i] = Vector4.zero;
        }
    }

    public bool TryGetShapeBounds(out Bounds bounds)
    {
        if (shapeCacheDirty) RefreshShapeCache();

        bounds = default;
        bool foundAdditiveShape = false;

        for (int i = 0; i < shapes.Count; i++)
        {
            CloudSdfShape shape = shapes[i];

            if (
                shape == null ||
                !shape.isActiveAndEnabled ||
                !shape.gameObject.activeInHierarchy ||
                shape.Operation != CloudSdfOperation.Add
            )
            {
                continue;
            }

            Bounds shapeBounds = shape.GetWorldBounds();

            if (!foundAdditiveShape)
            {
                bounds = shapeBounds;
                foundAdditiveShape = true;
            }
            else
            {
                bounds.Encapsulate(shapeBounds.min);
                bounds.Encapsulate(shapeBounds.max);
            }
        }

        return foundAdditiveShape;
    }

    public float EstimateWorldDeformationPadding()
    {
        Material source =
            materialTemplate != null
                ? materialTemplate
                : runtimeMaterial;

        if (source == null) return 0f;

        float total = 0f;

        total += GetPositiveMaterialFloat(
            source,
            ShapeWarpStrengthId
        );

        total += GetPositiveMaterialFloat(
            source,
            BillowStrengthId
        );

        total += GetPositiveMaterialFloat(
            source,
            SecondaryBillowStrengthId
        );

        total += GetPositiveMaterialFloat(
            source,
            SurfaceErosionStrengthId
        );

        total += GetPositiveMaterialFloat(
            source,
            ShapeSoftnessId
        );

        total += GetPositiveMaterialFloat(
            source,
            EdgeWispReachId
        );

        return total;
    }

    private static float GetPositiveMaterialFloat(
        Material material,
        int propertyId
    )
    {
        if (
            material == null ||
            !material.HasProperty(propertyId)
        )
        {
            return 0f;
        }

        return Mathf.Max(
            material.GetFloat(propertyId),
            0f
        );
    }
}

public static class CloudVolumeRegistry
{
    private static readonly List<CloudVolume> VolumesInternal =
        new List<CloudVolume>();

    public static IReadOnlyList<CloudVolume> Volumes =>
        VolumesInternal;

    public static void Register(CloudVolume volume)
    {
        if (
            volume == null ||
            VolumesInternal.Contains(volume)
        )
        {
            return;
        }

        VolumesInternal.Add(volume);
    }

    public static void Unregister(CloudVolume volume)
    {
        if (volume == null) return;

        VolumesInternal.Remove(volume);
    }

    [RuntimeInitializeOnLoadMethod(
        RuntimeInitializeLoadType.SubsystemRegistration
    )]
    private static void ResetRegistry()
    {
        VolumesInternal.Clear();
    }
}
