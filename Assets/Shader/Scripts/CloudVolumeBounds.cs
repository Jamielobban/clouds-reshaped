using UnityEngine;

public enum CloudBoundsMode
{
    Manual = 0,
    AutoFitShapes = 1
}

[DisallowMultipleComponent]
public sealed class CloudVolumeBounds : MonoBehaviour
{
    [Header("Bounds")]
    [SerializeField] private CloudBoundsMode mode = CloudBoundsMode.AutoFitShapes;

    [Tooltip("Extra world-space padding around the raymarch bounds.")]
    [SerializeField, Min(0f)] private float padding = 4f;

    [SerializeField, Min(0.001f)] private float minimumSize = 0.25f;

    [Header("Selected Gizmo")]
    [SerializeField] private Color gizmoColor = new Color(0f, 0.8f, 1f, 1f);

    public CloudBoundsMode Mode => mode;

    private void OnValidate()
    {
        padding = Mathf.Max(padding, 0f);
        minimumSize = Mathf.Max(minimumSize, 0.001f);

        CloudVolume owner = GetComponentInParent<CloudVolume>();

        if (owner != null) owner.MarkDirty();
    }

    public Bounds GetWorldBounds(CloudVolume owner)
    {
        Bounds bounds;

        if (
            mode == CloudBoundsMode.AutoFitShapes &&
            owner != null &&
            owner.TryGetShapeBounds(out Bounds automaticBounds)
        )
        {
            bounds = automaticBounds;

            // The bounds are now the raymarch container, not a deformable SDF
            // surface. Noise density fades inside these faces and cannot grow
            // beyond them, so only the authored padding is required.
            bounds.Expand(padding * 2f);
        }
        else
        {
            bounds = GetManualWorldBounds();
            bounds.Expand(padding * 2f);
        }

        bounds.size = new Vector3(
            Mathf.Max(bounds.size.x, minimumSize),
            Mathf.Max(bounds.size.y, minimumSize),
            Mathf.Max(bounds.size.z, minimumSize)
        );

        return bounds;
    }

    private Bounds GetManualWorldBounds()
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
        CloudVolume owner = GetComponentInParent<CloudVolume>();
        Bounds bounds = GetWorldBounds(owner);

        Color previousColor = Gizmos.color;
        Matrix4x4 previousMatrix = Gizmos.matrix;

        Gizmos.color = gizmoColor;
        Gizmos.matrix = Matrix4x4.identity;
        Gizmos.DrawWireCube(bounds.center, bounds.size);

        Gizmos.color = previousColor;
        Gizmos.matrix = previousMatrix;
    }
}
