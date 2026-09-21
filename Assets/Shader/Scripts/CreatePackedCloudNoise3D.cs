using UnityEditor;
using UnityEngine;

public static class CreatePackedCloudNoise3D
{
    private const int TextureSize = 64;

    private const string OutputFolder = "Assets/Generated";
    private const string OutputPath =
        OutputFolder + "/CloudBaseNoise64.asset";

    private static readonly Vector3[] Gradients =
    {
        new Vector3( 1,  1,  0).normalized,
        new Vector3(-1,  1,  0).normalized,
        new Vector3( 1, -1,  0).normalized,
        new Vector3(-1, -1,  0).normalized,

        new Vector3( 1,  0,  1).normalized,
        new Vector3(-1,  0,  1).normalized,
        new Vector3( 1,  0, -1).normalized,
        new Vector3(-1,  0, -1).normalized,

        new Vector3( 0,  1,  1).normalized,
        new Vector3( 0, -1,  1).normalized,
        new Vector3( 0,  1, -1).normalized,
        new Vector3( 0, -1, -1).normalized
    };

    [MenuItem("Tools/Clouds/Create Packed Base Noise 64")]
    private static void CreateTexture()
    {
        EnsureOutputFolder();

        var texture = new Texture3D(
            TextureSize,
            TextureSize,
            TextureSize,
            TextureFormat.RGBA32,
            mipChain: true
        )
        {
            name = "CloudBaseNoise64",
            wrapMode = TextureWrapMode.Repeat,
            filterMode = FilterMode.Trilinear,
            anisoLevel = 0
        };

        var pixels = new Color32[
            TextureSize *
            TextureSize *
            TextureSize
        ];

        for (int z = 0; z < TextureSize; z++)
        {
            float normalizedZ =
                (z + 0.5f) / TextureSize;

            for (int y = 0; y < TextureSize; y++)
            {
                float normalizedY =
                    (y + 0.5f) / TextureSize;

                for (int x = 0; x < TextureSize; x++)
                {
                    float normalizedX =
                        (x + 0.5f) / TextureSize;

                    Vector3 uvw = new Vector3(
                        normalizedX,
                        normalizedY,
                        normalizedZ
                    );

                    // Three tileable Worley frequencies.
                    float worleyLow =
                        WorleyNoise(uvw, 4, 100);

                    float worleyMedium =
                        WorleyNoise(uvw, 8, 200);

                    float worleyHigh =
                        WorleyNoise(uvw, 16, 300);

                    float worleyFbm =
                        worleyLow * 0.625f +
                        worleyMedium * 0.25f +
                        worleyHigh * 0.125f;

                    float perlinFbm =
                        PerlinFbm(uvw);

                    // Remap Perlin into the Worley field.
                    // This creates large connected cloud masses
                    // with cellular erosion around their edges.
                    float perlinWorley = Mathf.Lerp(
                        worleyFbm,
                        1f,
                        perlinFbm
                    );

                    int index =
                        x +
                        TextureSize *
                        (
                            y +
                            TextureSize * z
                        );

                    pixels[index] = new Color32(
                        ToByte(perlinWorley),
                        ToByte(worleyLow),
                        ToByte(worleyMedium),
                        ToByte(worleyHigh)
                    );
                }
            }
        }

        texture.SetPixels32(pixels);

        texture.Apply(
            updateMipmaps: true,
            makeNoLongerReadable: true
        );

        AssetDatabase.DeleteAsset(OutputPath);
        AssetDatabase.CreateAsset(texture, OutputPath);
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        Selection.activeObject = texture;

        Debug.Log(
            $"Created packed cloud base noise at {OutputPath}"
        );
    }

    private static float PerlinFbm(Vector3 uvw)
    {
        float result = 0f;
        float totalWeight = 0f;

        float amplitude = 0.5f;
        int frequency = 4;

        for (int octave = 0; octave < 3; octave++)
        {
            result += PerlinNoise(
                uvw,
                frequency,
                500 + octave * 31
            ) * amplitude;

            totalWeight += amplitude;

            frequency *= 2;
            amplitude *= 0.5f;
        }

        return Mathf.Clamp01(
            result / Mathf.Max(totalWeight, 0.0001f)
        );
    }

    private static float PerlinNoise(
        Vector3 uvw,
        int period,
        int seed
    )
    {
        Vector3 position = uvw * period;

        int x0 = Mathf.FloorToInt(position.x);
        int y0 = Mathf.FloorToInt(position.y);
        int z0 = Mathf.FloorToInt(position.z);

        int x1 = x0 + 1;
        int y1 = y0 + 1;
        int z1 = z0 + 1;

        float localX = position.x - x0;
        float localY = position.y - y0;
        float localZ = position.z - z0;

        float fadeX = Fade(localX);
        float fadeY = Fade(localY);
        float fadeZ = Fade(localZ);

        float n000 = GradientDot(
            x0, y0, z0,
            localX,
            localY,
            localZ,
            period,
            seed
        );

        float n100 = GradientDot(
            x1, y0, z0,
            localX - 1f,
            localY,
            localZ,
            period,
            seed
        );

        float n010 = GradientDot(
            x0, y1, z0,
            localX,
            localY - 1f,
            localZ,
            period,
            seed
        );

        float n110 = GradientDot(
            x1, y1, z0,
            localX - 1f,
            localY - 1f,
            localZ,
            period,
            seed
        );

        float n001 = GradientDot(
            x0, y0, z1,
            localX,
            localY,
            localZ - 1f,
            period,
            seed
        );

        float n101 = GradientDot(
            x1, y0, z1,
            localX - 1f,
            localY,
            localZ - 1f,
            period,
            seed
        );

        float n011 = GradientDot(
            x0, y1, z1,
            localX,
            localY - 1f,
            localZ - 1f,
            period,
            seed
        );

        float n111 = GradientDot(
            x1, y1, z1,
            localX - 1f,
            localY - 1f,
            localZ - 1f,
            period,
            seed
        );

        float x00 = Mathf.Lerp(n000, n100, fadeX);
        float x10 = Mathf.Lerp(n010, n110, fadeX);
        float x01 = Mathf.Lerp(n001, n101, fadeX);
        float x11 = Mathf.Lerp(n011, n111, fadeX);

        float y0Value = Mathf.Lerp(
            x00,
            x10,
            fadeY
        );

        float y1Value = Mathf.Lerp(
            x01,
            x11,
            fadeY
        );

        float value = Mathf.Lerp(
            y0Value,
            y1Value,
            fadeZ
        );

        return Mathf.Clamp01(
            value * 0.5f + 0.5f
        );
    }

    private static float GradientDot(
        int gridX,
        int gridY,
        int gridZ,
        float offsetX,
        float offsetY,
        float offsetZ,
        int period,
        int seed
    )
    {
        int wrappedX = PositiveModulo(
            gridX,
            period
        );

        int wrappedY = PositiveModulo(
            gridY,
            period
        );

        int wrappedZ = PositiveModulo(
            gridZ,
            period
        );

        uint hash = Hash(
            wrappedX,
            wrappedY,
            wrappedZ,
            seed
        );

        Vector3 gradient = Gradients[
            hash % (uint)Gradients.Length
        ];

        return Vector3.Dot(
            gradient,
            new Vector3(
                offsetX,
                offsetY,
                offsetZ
            )
        );
    }

    private static float WorleyNoise(
        Vector3 uvw,
        int cellCount,
        int seed
    )
    {
        Vector3 position = uvw * cellCount;

        int cellX = Mathf.FloorToInt(position.x);
        int cellY = Mathf.FloorToInt(position.y);
        int cellZ = Mathf.FloorToInt(position.z);

        Vector3 localPosition = new Vector3(
            position.x - cellX,
            position.y - cellY,
            position.z - cellZ
        );

        float minimumDistance = float.MaxValue;

        for (int offsetZ = -1; offsetZ <= 1; offsetZ++)
        {
            for (int offsetY = -1; offsetY <= 1; offsetY++)
            {
                for (int offsetX = -1; offsetX <= 1; offsetX++)
                {
                    int neighbourX =
                        cellX + offsetX;

                    int neighbourY =
                        cellY + offsetY;

                    int neighbourZ =
                        cellZ + offsetZ;

                    int wrappedX = PositiveModulo(
                        neighbourX,
                        cellCount
                    );

                    int wrappedY = PositiveModulo(
                        neighbourY,
                        cellCount
                    );

                    int wrappedZ = PositiveModulo(
                        neighbourZ,
                        cellCount
                    );

                    Vector3 featurePoint =
                        GetFeaturePoint(
                            wrappedX,
                            wrappedY,
                            wrappedZ,
                            seed
                        );

                    Vector3 difference = new Vector3(
                        offsetX + featurePoint.x -
                        localPosition.x,

                        offsetY + featurePoint.y -
                        localPosition.y,

                        offsetZ + featurePoint.z -
                        localPosition.z
                    );

                    float distance =
                        difference.magnitude;

                    minimumDistance = Mathf.Min(
                        minimumDistance,
                        distance
                    );
                }
            }
        }

        // Inverted Worley:
        // feature centres are bright and boundaries dark.
        return 1f - Mathf.Clamp01(
            minimumDistance
        );
    }

    private static Vector3 GetFeaturePoint(
        int x,
        int y,
        int z,
        int seed
    )
    {
        return new Vector3(
            Hash01(x, y, z, seed + 11),
            Hash01(x, y, z, seed + 29),
            Hash01(x, y, z, seed + 47)
        );
    }

    private static float Fade(float value)
    {
        return value *
               value *
               value *
               (
                   value *
                   (
                       value * 6f - 15f
                   ) +
                   10f
               );
    }

    private static uint Hash(
        int x,
        int y,
        int z,
        int seed
    )
    {
        unchecked
        {
            uint hash =
                (uint)x * 374761393u +
                (uint)y * 668265263u +
                (uint)z * 2246822519u +
                (uint)seed * 3266489917u;

            hash =
                (hash ^ (hash >> 13)) *
                1274126177u;

            return hash ^ (hash >> 16);
        }
    }

    private static float Hash01(
        int x,
        int y,
        int z,
        int seed
    )
    {
        uint hash = Hash(
            x,
            y,
            z,
            seed
        );

        return (
            hash & 0x00FFFFFFu
        ) / 16777215f;
    }

    private static int PositiveModulo(
        int value,
        int modulus
    )
    {
        int result = value % modulus;

        return result < 0
            ? result + modulus
            : result;
    }

    private static byte ToByte(float value)
    {
        return (byte)Mathf.RoundToInt(
            Mathf.Clamp01(value) * 255f
        );
    }

    private static void EnsureOutputFolder()
    {
        if (!AssetDatabase.IsValidFolder(OutputFolder))
        {
            AssetDatabase.CreateFolder(
                "Assets",
                "Generated"
            );
        }
    }
}