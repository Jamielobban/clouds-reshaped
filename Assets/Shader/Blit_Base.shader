Shader "Custom/CloudRaymarch"
{
    Properties
    {
        _BoundsMin ("Bounds Min", Vector) = (-10, 0, -10, 0)
        _BoundsMax ("Bounds Max", Vector) = (10, 10, 10, 0)

        _CloudColor ("Cloud Color", Color) = (1, 1, 1, 1)
        _Density ("Density", Range(0, 2)) = 0.15
        _Extinction ("Extinction", Range(0, 5)) = 1.0

        _NoiseTex ("3D Noise", 3D) = "" {}

        _NoiseScale ("Noise Scale", Float) = 0.08
        _NoiseThreshold ("Noise Threshold", Range(0, 1)) = 0.5
        _NoiseMultiplier ("Noise Multiplier", Range(0, 10)) = 4.0

        _WindDirection ("Wind Direction", Vector) = (1, 0, 0.2, 0)
        _WindSpeed ("Wind Speed", Float) = 0.5
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        ZWrite Off
        ZTest Always
        Cull Off

        Pass
        {
            Name "CloudRaymarch"

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BoundsMin;
                float4 _BoundsMax;

                float4 _CloudColor;
                float _Density;
                float _Extinction;

                float _NoiseScale;
                float _NoiseThreshold;
                float _NoiseMultiplier;

                float4 _WindDirection;
                float _WindSpeed;
            CBUFFER_END

            TEXTURE3D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            void GetCameraRay(
                float2 uv,
                out float3 rayOrigin,
                out float3 rayDirection)
            {
                #if UNITY_REVERSED_Z
                    float nearDepth = 1.0;
                    float farDepth = 0.0;
                #else
                    float nearDepth = UNITY_NEAR_CLIP_VALUE;
                    float farDepth = 1.0;
                #endif

                float3 nearPositionWS = ComputeWorldSpacePosition(
                    uv,
                    nearDepth,
                    UNITY_MATRIX_I_VP
                );

                float3 farPositionWS = ComputeWorldSpacePosition(
                    uv,
                    farDepth,
                    UNITY_MATRIX_I_VP
                );

                rayDirection = normalize(
                    farPositionWS - nearPositionWS
                );

                // Camera position for perspective cameras.
                // Near-plane position for orthographic cameras.
                rayOrigin = lerp(
                    GetCameraPositionWS(),
                    nearPositionWS,
                    unity_OrthoParams.w
                );
            }

            float2 RayBoxIntersection(
                float3 rayOrigin,
                float3 rayDirection,
                float3 boundsMin,
                float3 boundsMax)
            {
                float3 inverseDirection = rcp(rayDirection);

                float3 t0 =
                    (boundsMin - rayOrigin) *
                    inverseDirection;

                float3 t1 =
                    (boundsMax - rayOrigin) *
                    inverseDirection;

                float3 tMin = min(t0, t1);
                float3 tMax = max(t0, t1);

                float entryDistance = max(
                    max(tMin.x, tMin.y),
                    tMin.z
                );

                float exitDistance = min(
                    min(tMax.x, tMax.y),
                    tMax.z
                );

                // Distance from the camera to the box.
                float distanceToBox = max(0.0, entryDistance);

                // Total distance travelled inside the box.
                float distanceInsideBox = max(
                    0.0,
                    exitDistance - distanceToBox
                );

                return float2(
                    distanceToBox,
                    distanceInsideBox
                );
            }

            float SampleCloudDensity(float3 positionWS)
            {
                float3 windOffset =
                    _WindDirection.xyz *
                    (_Time.y * _WindSpeed);

                float3 noiseCoordinates =
                    (positionWS + windOffset) *
                    _NoiseScale;

                float noise = SAMPLE_TEXTURE3D(
                    _NoiseTex,
                    sampler_NoiseTex,
                    noiseCoordinates
                ).r;

                float density = saturate(
                    (noise - _NoiseThreshold) *
                    _NoiseMultiplier
                );

                return density * _Density;
            }

            float4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;

                float4 sceneColor = SAMPLE_TEXTURE2D(
                    _BlitTexture,
                    sampler_LinearClamp,
                    uv
                );

                float3 rayOrigin;
                float3 rayDirection;

                GetCameraRay(
                    uv,
                    rayOrigin,
                    rayDirection
                );

                float2 boxInfo = RayBoxIntersection(
                    rayOrigin,
                    rayDirection,
                    _BoundsMin.xyz,
                    _BoundsMax.xyz
                );

                float distanceToBox = boxInfo.x;
                float distanceInsideBox = boxInfo.y;

                if (distanceInsideBox <= 0.0)
                    return sceneColor;

                const int STEP_COUNT = 64;

                float stepLength =
                    distanceInsideBox / STEP_COUNT;

                float3 samplePosition =
                    rayOrigin +
                    rayDirection *
                    (distanceToBox + stepLength * 0.5);

                float transmittance = 1.0;
                float3 accumulatedLight = 0.0;

                [loop]
                for (int i = 0; i < STEP_COUNT; i++)
                {
                    // Constant density for now.
                    float density = SampleCloudDensity(samplePosition);

                    // Beer-Lambert extinction over this step.
                    float stepTransmittance = exp(
                        -density *
                        _Extinction *
                        stepLength
                    );

                    // Amount of light scattered during this step.
                    float absorbedLight =
                        1.0 - stepTransmittance;

                    accumulatedLight +=
                        transmittance *
                        absorbedLight *
                        _CloudColor.rgb;

                    transmittance *= stepTransmittance;

                    samplePosition +=
                        rayDirection * stepLength;

                    if (transmittance < 0.01)
                        break;
                }

                float3 finalColor =
                    accumulatedLight +
                    sceneColor.rgb * transmittance;

                return float4(finalColor, 1.0);
            }

            ENDHLSL
        }
    }
}