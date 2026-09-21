using System.IO;
using UnityEditor;
using UnityEngine;

public static class CreateCloudNoise3D
{
    private const int TextureSize = 32;
    private const string OutputDirectory = "Assets/Generated";
    private const string OutputPath = OutputDirectory + "/CloudNoise3D.asset";

    [MenuItem("Tools/Clouds/Create Basic 3D Noise")]
    private static void CreateNoiseTexture()
    {
        var texture = new Texture3D(
            TextureSize,
            TextureSize,
            TextureSize,
            TextureFormat.RGBA32,
            true
        )
        {
            name = "CloudNoise3D",
            wrapMode = TextureWrapMode.Repeat,
            filterMode = FilterMode.Bilinear
        };

        var colors = new Color[
            TextureSize *
            TextureSize *
            TextureSize
        ];

        for (int z = 0; z < TextureSize; z++)
        {
            for (int y = 0; y < TextureSize; y++)
            {
                for (int x = 0; x < TextureSize; x++)
                {
                    Vector3 uvw = new Vector3(x, y, z) / TextureSize;

                    float noise = FractalNoise(uvw);

                    int index =
                        x +
                        TextureSize *
                        (y + TextureSize * z);

                    colors[index] = new Color(
                        noise,
                        noise,
                        noise,
                        1f
                    );
                }
            }
        }

        texture.SetPixels(colors);
        texture.Apply(
            updateMipmaps: true,
            makeNoLongerReadable: true
        );

        Directory.CreateDirectory(OutputDirectory);

        AssetDatabase.DeleteAsset(OutputPath);
        AssetDatabase.CreateAsset(texture, OutputPath);
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        Selection.activeObject = texture;

        Debug.Log($"Created 3D noise texture: {OutputPath}");
    }

    private static float FractalNoise(Vector3 uvw)
    {
        float result = 0f;
        float amplitude = 0.5f;
        float totalAmplitude = 0f;

        int frequency = 2;

        for (int octave = 0; octave < 4; octave++)
        {
            result += ValueNoise(
                uvw * frequency,
                frequency,
                1200 + octave * 37
            ) * amplitude;

            totalAmplitude += amplitude;
            amplitude *= 0.5f;
            frequency *= 2;
        }

        return result / totalAmplitude;
    }

    private static float ValueNoise(
        Vector3 position,
        int period,
        int seed)
    {
        int x0 = Mathf.FloorToInt(position.x);
        int y0 = Mathf.FloorToInt(position.y);
        int z0 = Mathf.FloorToInt(position.z);

        int x1 = x0 + 1;
        int y1 = y0 + 1;
        int z1 = z0 + 1;

        float tx = Smooth(position.x - x0);
        float ty = Smooth(position.y - y0);
        float tz = Smooth(position.z - z0);

        float c000 = RandomValue(x0, y0, z0, period, seed);
        float c100 = RandomValue(x1, y0, z0, period, seed);
        float c010 = RandomValue(x0, y1, z0, period, seed);
        float c110 = RandomValue(x1, y1, z0, period, seed);

        float c001 = RandomValue(x0, y0, z1, period, seed);
        float c101 = RandomValue(x1, y0, z1, period, seed);
        float c011 = RandomValue(x0, y1, z1, period, seed);
        float c111 = RandomValue(x1, y1, z1, period, seed);

        float x00 = Mathf.Lerp(c000, c100, tx);
        float x10 = Mathf.Lerp(c010, c110, tx);
        float x01 = Mathf.Lerp(c001, c101, tx);
        float x11 = Mathf.Lerp(c011, c111, tx);

        float y0Value = Mathf.Lerp(x00, x10, ty);
        float y1Value = Mathf.Lerp(x01, x11, ty);

        return Mathf.Lerp(y0Value, y1Value, tz);
    }

    private static float RandomValue(
        int x,
        int y,
        int z,
        int period,
        int seed)
    {
        x = PositiveModulo(x, period);
        y = PositiveModulo(y, period);
        z = PositiveModulo(z, period);

        unchecked
        {
            uint hash =
                (uint)x * 374761393u +
                (uint)y * 668265263u +
                (uint)z * 2246822519u +
                (uint)seed * 3266489917u;

            hash = (hash ^ (hash >> 13)) * 1274126177u;
            hash ^= hash >> 16;

            return (hash & 0x00FFFFFFu) / 16777215f;
        }
    }

    private static int PositiveModulo(int value, int modulus)
    {
        int result = value % modulus;
        return result < 0 ? result + modulus : result;
    }

    private static float Smooth(float value)
    {
        return value * value * (3f - 2f * value);
    }
}