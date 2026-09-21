Shader "Skybox/Portfolio Atmosphere"
{
    Properties
    {
        [HDR] _ZenithColor ("Zenith Color", Color) = (0.055, 0.20, 0.46, 1)
        [HDR] _HorizonColor ("Horizon Color", Color) = (0.65, 0.56, 0.48, 1)
        [HDR] _LowerColor ("Lower Sky Color", Color) = (0.18, 0.27, 0.39, 1)
        [HDR] _HazeColor ("Haze Color", Color) = (0.85, 0.45, 0.24, 1)
        _HazeStrength ("Haze Strength", Range(0, 1)) = 0.14
        _GradientPower ("Gradient Power", Range(0.25, 4)) = 1.15
        [HDR] _SunColor ("Sun Color", Color) = (3.2, 1.7, 0.8, 1)
        _SunDirection ("Sun Direction", Vector) = (0.45, 0.42, -0.79, 0)
        _SunSize ("Sun Size", Range(0.0001, 0.02)) = 0.0012
        _SunHaloIntensity ("Sun Halo Intensity", Range(0, 2)) = 0.32
        _SunHaloFalloff ("Sun Halo Falloff", Range(2, 64)) = 18
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Background"
            "RenderType" = "Background"
            "PreviewType" = "Skybox"
            "RenderPipeline" = "UniversalPipeline"
        }

        Cull Off
        ZWrite Off
        ZTest LEqual

        Pass
        {
            Name "PortfolioAtmosphere"

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 directionWS : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _ZenithColor;
                float4 _HorizonColor;
                float4 _LowerColor;
                float4 _HazeColor;
                float4 _SunColor;
                float4 _SunDirection;
                float _HazeStrength;
                float _GradientPower;
                float _SunSize;
                float _SunHaloIntensity;
                float _SunHaloFalloff;
            CBUFFER_END

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.directionWS = TransformObjectToWorldDir(input.positionOS.xyz);
                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float3 direction = normalize(input.directionWS);
                float height = direction.y;

                float upperGradient = pow(
                    smoothstep(-0.05, 0.82, height),
                    max(_GradientPower, 0.001)
                );
                float3 color = lerp(
                    _HorizonColor.rgb,
                    _ZenithColor.rgb,
                    upperGradient
                );

                float lowerBlend = smoothstep(0.0, 0.55, -height);
                color = lerp(color, _LowerColor.rgb, lowerBlend);

                float horizonBand = pow(
                    saturate(1.0 - abs(height)),
                    10.0
                );
                color += _HazeColor.rgb * horizonBand * _HazeStrength;

                float3 sunDirection = normalize(_SunDirection.xyz);
                float sunDot = saturate(dot(direction, sunDirection));
                float sunDisc = smoothstep(
                    1.0 - _SunSize,
                    1.0 - _SunSize * 0.25,
                    sunDot
                );
                float sunHalo = pow(
                    sunDot,
                    max(_SunHaloFalloff, 1.0)
                ) * _SunHaloIntensity;

                color += _SunColor.rgb * (sunDisc + sunHalo);
                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }

    Fallback Off
}
