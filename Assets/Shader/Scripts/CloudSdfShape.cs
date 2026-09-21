using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;
#endif

public enum CloudSdfShapeType
{
    Ellipsoid = 0,
    Capsule = 1,
    RoundedBox = 2,
    Box = 3
}

public enum CloudSdfOperation
{
    Add = 0,
    Subtract = 1
}

[DisallowMultipleComponent]
public sealed class CloudSdfShape : MonoBehaviour
{
    [Header("SDF Shape")]
    [SerializeField] private CloudSdfShapeType shapeType = CloudSdfShapeType.Ellipsoid;
    [SerializeField] private CloudSdfOperation operation = CloudSdfOperation.Add;

    [Tooltip("Controls how smoothly this shape blends with the accumulated SDF.")]
    [SerializeField, Min(0.001f)] private float blend = 0.08f;

    [Tooltip("Used by Capsule and Rounded Box shapes.")]
    [SerializeField, Range(0.01f, 0.49f)] private float radius = 0.3f;

    [Tooltip("Lower values are evaluated first. Additive shapes are always packed before subtractive shapes.")]
    [SerializeField] private int order;

    [Header("Scene Gizmo")]
    [SerializeField] private Color additiveColor = new Color(0f, 0.8f, 1f, 1f);
    [SerializeField] private Color subtractiveColor = new Color(1f, 0.2f, 0.15f, 1f);

    private CloudVolume owner;

    public CloudSdfShapeType ShapeType => shapeType;
    public CloudSdfOperation Operation => operation;
    public float Blend => Mathf.Max(blend, 0.001f);
    public float Radius => Mathf.Clamp(radius, 0.01f, 0.49f);
    public int Order => order;

    public float DistanceScale
    {
        get
        {
            Vector3 scale = transform.lossyScale;

            return Mathf.Max(
                Mathf.Min(
                    Mathf.Abs(scale.x),
                    Mathf.Abs(scale.y),
                    Mathf.Abs(scale.z)
                ),
                0.0001f
            );
        }
    }

    private void OnEnable()
    {
        RefreshOwner();
    }

    private void OnDisable()
    {
        if (owner != null) owner.MarkDirty();
    }

    private void OnValidate()
    {
        blend = Mathf.Max(blend, 0.001f);
        radius = Mathf.Clamp(radius, 0.01f, 0.49f);

        RefreshOwner();

        if (owner != null) owner.MarkDirty();
    }

    private void OnTransformParentChanged()
    {
        RefreshOwner();
    }

    private void RefreshOwner()
    {
        CloudVolume newOwner = GetComponentInParent<CloudVolume>();

        if (newOwner == owner) return;

        if (owner != null) owner.MarkDirty();

        owner = newOwner;

        if (owner != null) owner.MarkDirty();
    }

    public Bounds GetWorldBounds()
    {
        return shapeType == CloudSdfShapeType.Ellipsoid
            ? GetEllipsoidWorldBounds()
            : GetBoxWorldBounds();
    }

    private Bounds GetEllipsoidWorldBounds()
    {
        Matrix4x4 matrix = transform.localToWorldMatrix;
        Vector3 center = matrix.MultiplyPoint3x4(Vector3.zero);

        Vector3 extents = new Vector3(
            0.5f * Mathf.Sqrt(
                matrix.m00 * matrix.m00 +
                matrix.m01 * matrix.m01 +
                matrix.m02 * matrix.m02
            ),
            0.5f * Mathf.Sqrt(
                matrix.m10 * matrix.m10 +
                matrix.m11 * matrix.m11 +
                matrix.m12 * matrix.m12
            ),
            0.5f * Mathf.Sqrt(
                matrix.m20 * matrix.m20 +
                matrix.m21 * matrix.m21 +
                matrix.m22 * matrix.m22
            )
        );

        return new Bounds(center, extents * 2f);
    }

    private Bounds GetBoxWorldBounds()
    {
        Matrix4x4 matrix = transform.localToWorldMatrix;
        Vector3 center = matrix.MultiplyPoint3x4(Vector3.zero);

        Vector3 extents = new Vector3(
            0.5f * (
                Mathf.Abs(matrix.m00) +
                Mathf.Abs(matrix.m01) +
                Mathf.Abs(matrix.m02)
            ),
            0.5f * (
                Mathf.Abs(matrix.m10) +
                Mathf.Abs(matrix.m11) +
                Mathf.Abs(matrix.m12)
            ),
            0.5f * (
                Mathf.Abs(matrix.m20) +
                Mathf.Abs(matrix.m21) +
                Mathf.Abs(matrix.m22)
            )
        );

        return new Bounds(center, extents * 2f);
    }

    private void OnDrawGizmosSelected()
    {
        Color color = operation == CloudSdfOperation.Add
            ? additiveColor
            : subtractiveColor;

        #if UNITY_EDITOR
        Matrix4x4 previousMatrix = Handles.matrix;
        Color previousColor = Handles.color;

        Handles.matrix = transform.localToWorldMatrix;
        Handles.color = color;

        switch (shapeType)
        {
            case CloudSdfShapeType.Ellipsoid:
                DrawEllipsoidGizmo();
                break;

            case CloudSdfShapeType.Capsule:
                DrawCapsuleGizmo();
                break;

            case CloudSdfShapeType.RoundedBox:
            case CloudSdfShapeType.Box:
                Handles.DrawWireCube(Vector3.zero, Vector3.one);
                break;
        }

        Handles.matrix = previousMatrix;
        Handles.color = previousColor;
        #else
        Matrix4x4 previousMatrix = Gizmos.matrix;
        Color previousColor = Gizmos.color;

        Gizmos.matrix = transform.localToWorldMatrix;
        Gizmos.color = color;

        if (shapeType == CloudSdfShapeType.Ellipsoid)
        {
            Gizmos.DrawWireSphere(Vector3.zero, 0.5f);
        }
        else
        {
            Gizmos.DrawWireCube(Vector3.zero, Vector3.one);
        }

        Gizmos.matrix = previousMatrix;
        Gizmos.color = previousColor;
        #endif
    }

    #if UNITY_EDITOR
    private static void DrawEllipsoidGizmo()
    {
        Handles.DrawWireDisc(Vector3.zero, Vector3.right, 0.5f);
        Handles.DrawWireDisc(Vector3.zero, Vector3.up, 0.5f);
        Handles.DrawWireDisc(Vector3.zero, Vector3.forward, 0.5f);
    }

    private void DrawCapsuleGizmo()
    {
        float capsuleRadius = Radius;
        float halfSegment = Mathf.Max(0.5f - capsuleRadius, 0.001f);

        Vector3 leftCenter = new Vector3(-halfSegment, 0f, 0f);
        Vector3 rightCenter = new Vector3(halfSegment, 0f, 0f);

        Handles.DrawWireDisc(leftCenter, Vector3.right, capsuleRadius);
        Handles.DrawWireDisc(rightCenter, Vector3.right, capsuleRadius);

        Handles.DrawLine(
            leftCenter + Vector3.up * capsuleRadius,
            rightCenter + Vector3.up * capsuleRadius
        );

        Handles.DrawLine(
            leftCenter - Vector3.up * capsuleRadius,
            rightCenter - Vector3.up * capsuleRadius
        );

        Handles.DrawLine(
            leftCenter + Vector3.forward * capsuleRadius,
            rightCenter + Vector3.forward * capsuleRadius
        );

        Handles.DrawLine(
            leftCenter - Vector3.forward * capsuleRadius,
            rightCenter - Vector3.forward * capsuleRadius
        );

        Handles.DrawWireArc(
            leftCenter,
            Vector3.forward,
            Vector3.up,
            180f,
            capsuleRadius
        );

        Handles.DrawWireArc(
            leftCenter,
            Vector3.up,
            Vector3.forward,
            -180f,
            capsuleRadius
        );

        Handles.DrawWireArc(
            rightCenter,
            Vector3.forward,
            Vector3.down,
            180f,
            capsuleRadius
        );

        Handles.DrawWireArc(
            rightCenter,
            Vector3.up,
            Vector3.forward,
            180f,
            capsuleRadius
        );
    }
    #endif
}