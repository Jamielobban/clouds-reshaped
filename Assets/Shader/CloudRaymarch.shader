Shader "Custom/CloudRaymarchVolumes"
{
    Properties
    {
        [HideInInspector] _BoundsMin ("Bounds Min", Vector) = (-1, -1, -1, 0)
        [HideInInspector] _BoundsMax ("Bounds Max", Vector) = (1, 1, 1, 0)
        [HideInInspector] _NoiseOffset ("Noise Offset", Vector) = (0, 0, 0, 0)
        [HideInInspector] _CloudDistanceScale ("Cloud Distance Scale", Float) = 1

        _NoiseReferenceSize ("Reference Cloud Size", Range(0.25, 100)) = 24

        _CloudColor ("Overall Cloud Tint", Color) = (1, 1, 1, 1)
        _Density ("Density", Range(0, 3)) = 0.82
        _Extinction ("Extinction", Range(0, 5)) = 1.15
        _OpacityPower ("Opacity Power", Range(0.25, 5)) = 0.85

        _RayStepSize ("World Ray Step Size", Range(0.01, 1)) = 0.18
        _RayJitter ("Ray Jitter", Range(0, 1)) = 0.86
        _DetailStepScale ("Surface Detail Step Scale", Range(0.25, 1)) = 0.52

        _NoiseTex ("3D Noise", 3D) = "" {}

        [Header(Volume Shaping Mode)]
        [Toggle] _UseSdfShape ("Use SDF Shape Envelope", Float) = 0
        [Toggle] _UseShapeGuides ("Use SDF Placement Guides", Float) = 1
        _HorizontalFade ("Bounds Side Fade Distance", Range(0.01, 10)) = 4.0
        _BottomFade ("Bounds Bottom Fade Distance", Range(0.01, 10)) = 2.5
        _TopFadeStart ("Bounds Top Fade Distance", Range(0.01, 10)) = 3.0

        _ShapeDetailStrength ("Shape Detail Influence", Range(0, 1)) = 0.92
        _ShapeInset ("Base Shape Inset", Range(0, 0.25)) = 0.075
        _ShapeWarpScale ("Large Shape Noise Scale", Float) = 0.03
        _ShapeWarpStrength ("Large Shape Warp", Range(0, 2)) = 0.8

        _BillowScale ("Billow Noise Scale", Float) = 0.104
        _BillowStrength ("Billow Shape Strength", Range(0, 2)) = 0.85
        _BillowDensityVariation ("Billow Density Variation", Range(0, 0.5)) = 0.10

        _SecondaryBillowScale ("Secondary Billow Scale", Float) = 0.25
        _SecondaryBillowStrength ("Secondary Billow Strength", Range(0, 1)) = 0.24

        _SurfaceErosionScale ("Surface Erosion Scale", Float) = 0.56
        _SurfaceErosionStrength ("Surface Erosion Strength", Range(0, 1)) = 0.025
        _SurfaceErosionDepth ("Surface Erosion Depth", Range(0.001, 2)) = 0.65

        _InteriorDensityRamp ("Interior Density Ramp", Range(0.01, 2)) = 0.72
        _DensityContrast ("Density Contrast", Range(0.25, 4)) = 1.35
        _ShapeSoftness ("Density Edge Softness", Range(0.001, 1)) = 0.16
        _LengthTaper ("Length Taper", Range(-0.35, 0.35)) = 0.06
        _BottomWarpMultiplier ("Bottom Warp Multiplier", Range(0, 1)) = 0.42
        _DensityCutoff ("Low Density Cutoff", Range(0, 0.3)) = 0.035

        [Header(Wispy Interior Coverage)]
        _CoverageScale ("Coverage Noise Scale", Float) = 0.04
        _CoverageThreshold ("Coverage Threshold", Range(0, 1)) = 0.64
        _CoverageSoftness ("Coverage Softness", Range(0.001, 0.5)) = 0.10
        _CoverageStrength ("Coverage Carving", Range(0, 1)) = 0.50
        _CoverageContrast ("Coverage Contrast", Range(0.25, 4)) = 1.25
        _CoverageInteriorBias ("Interior Fill Bias", Range(0, 0.5)) = 0.06
        _CoverageWarpStrength ("Coverage Domain Warp", Range(0, 5)) = 1.35

        [Header(Edge Wisps)]
        _EdgeWispReach ("Edge Wisp Reach", Range(0, 3)) = 0.75
        _EdgeWispStrength ("Edge Wisp Extension", Range(0, 1)) = 0.26
        _EdgeWispThreshold ("Edge Wisp Threshold", Range(0, 1)) = 0.56
        _EdgeWispSoftness ("Edge Wisp Softness", Range(0.001, 0.5)) = 0.12

        _WindDirection ("Local Wind Direction", Vector) = (1, 0, 0.2, 0)
        _WindSpeed ("Wind Speed", Float) = 0.1

        [HDR] _LightCloudColor ("Lit Cloud Color", Color) = (1.08, 1.03, 0.94, 1)
        [HDR] _ShadowCloudColor ("Shadow Cloud Color", Color) = (0.48, 0.55, 0.68, 1)
        [HDR] _DeepCloudColor ("Deep Cloud Color", Color) = (0.20, 0.25, 0.34, 1)

        _LightColorPower ("Light Color Contrast", Range(0.25, 4)) = 1.1
        _DeepColorStrength ("Deep Color Strength", Range(0, 4)) = 1.35

        [HDR] _AmbientColor ("Ambient Color", Color) = (0.48, 0.57, 0.72, 1)
        _AmbientStrength ("Ambient Strength", Range(0, 3)) = 0.82
        _AmbientHeightContrast ("Ambient Height Contrast", Range(0, 1)) = 0.48
        _SunStrength ("Sun Strength", Range(0, 10)) = 1.45
        _LightStepLength ("Light Step Length", Range(0.1, 10)) = 0.9
        _PowderStrength ("Powder Highlight Strength", Range(0, 2)) = 0.62

        _ForwardScattering ("Forward Scattering", Range(0, 0.95)) = 0.62
        _BackwardScattering ("Backward Scattering", Range(0, 0.95)) = 0.18
        _PhaseBlend ("Forward Phase Blend", Range(0, 1)) = 0.82
        _PhaseStrength ("Phase Strength", Range(0, 1)) = 0.34
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

            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            #define MAX_CLOUD_SHAPES 8

            TEXTURE3D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

            float4x4 _ShapeWorldToLocal[MAX_CLOUD_SHAPES];
            float4 _ShapeData0[MAX_CLOUD_SHAPES];
            float4 _ShapeData1[MAX_CLOUD_SHAPES];

            CBUFFER_START(UnityPerMaterial)
                float4 _BoundsMin;
                float4 _BoundsMax;
                float4 _NoiseOffset;
                float4x4 _CloudWorldToNoise;
                float _CloudDistanceScale;
                float _NoiseReferenceSize;

                int _ShapeCount;

                float4 _CloudColor;
                float _Density;
                float _Extinction;
                float _OpacityPower;

                float _RayStepSize;
                float _RayJitter;
                float _DetailStepScale;

                float _UseSdfShape;
                float _UseShapeGuides;
                float _HorizontalFade;
                float _BottomFade;
                float _TopFadeStart;

                float _ShapeDetailStrength;
                float _ShapeInset;
                float _ShapeWarpScale;
                float _ShapeWarpStrength;

                float _BillowScale;
                float _BillowStrength;
                float _BillowDensityVariation;

                float _SecondaryBillowScale;
                float _SecondaryBillowStrength;

                float _SurfaceErosionScale;
                float _SurfaceErosionStrength;
                float _SurfaceErosionDepth;

                float _InteriorDensityRamp;
                float _DensityContrast;
                float _ShapeSoftness;
                float _LengthTaper;
                float _BottomWarpMultiplier;
                float _DensityCutoff;

                float _CoverageScale;
                float _CoverageThreshold;
                float _CoverageSoftness;
                float _CoverageStrength;
                float _CoverageContrast;
                float _CoverageInteriorBias;
                float _CoverageWarpStrength;

                float _EdgeWispReach;
                float _EdgeWispStrength;
                float _EdgeWispThreshold;
                float _EdgeWispSoftness;

                float4 _WindDirection;
                float _WindSpeed;

                float4 _LightCloudColor;
                float4 _ShadowCloudColor;
                float4 _DeepCloudColor;

                float _LightColorPower;
                float _DeepColorStrength;

                float4 _AmbientColor;
                float _AmbientStrength;
                float _AmbientHeightContrast;
                float _SunStrength;
                float _LightStepLength;
                float _PowderStrength;

                float _ForwardScattering;
                float _BackwardScattering;
                float _PhaseBlend;
                float _PhaseStrength;
            CBUFFER_END

            void GetCameraRay(float2 uv, out float3 rayOrigin, out float3 rayDirection)
            {
                #if UNITY_REVERSED_Z
                    float nearDepth = 1.0;
                    float farDepth = 0.0;
                #else
                    float nearDepth = UNITY_NEAR_CLIP_VALUE;
                    float farDepth = 1.0;
                #endif

                float3 nearPositionWS = ComputeWorldSpacePosition(uv, nearDepth, UNITY_MATRIX_I_VP);
                float3 farPositionWS = ComputeWorldSpacePosition(uv, farDepth, UNITY_MATRIX_I_VP);

                rayDirection = normalize(farPositionWS - nearPositionWS);
                rayOrigin = lerp(GetCameraPositionWS(), nearPositionWS, unity_OrthoParams.w);
            }

            float2 RayBoxIntersection(float3 rayOrigin, float3 rayDirection, float3 boundsMin, float3 boundsMax)
            {
                float3 zeroDirectionMask = 1.0 - step(0.000001, abs(rayDirection));
                float3 safeDirection = rayDirection + zeroDirectionMask * 0.000001;

                float3 inverseDirection = rcp(safeDirection);
                float3 t0 = (boundsMin - rayOrigin) * inverseDirection;
                float3 t1 = (boundsMax - rayOrigin) * inverseDirection;
                float3 tMin = min(t0, t1);
                float3 tMax = max(t0, t1);

                float entryDistance = max(max(tMin.x, tMin.y), tMin.z);
                float exitDistance = min(min(tMax.x, tMax.y), tMax.z);
                float distanceToBox = max(entryDistance, 0.0);
                float distanceInsideBox = max(exitDistance - distanceToBox, 0.0);

                return float2(distanceToBox, distanceInsideBox);
            }

            float GetSceneDistance(float2 uv, float3 rayOrigin, float3 rayDirection)
            {
                float rawDepth = SampleSceneDepth(uv);

                #if !UNITY_REVERSED_Z
                    rawDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1.0, rawDepth);
                #endif

                float3 scenePositionWS = ComputeWorldSpacePosition(uv, rawDepth, UNITY_MATRIX_I_VP);
                return max(dot(scenePositionWS - rayOrigin, rayDirection), 0.0);
            }

            float Hash12(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.x + p3.y) * p3.z);
            }

            float Hash13(float3 p3)
            {
                p3 = frac(p3 * 0.1031);
                p3 += dot(p3, p3.zyx + 31.32);
                return frac((p3.x + p3.y) * p3.z);
            }

            float4 SampleCloudNoise(float3 coordinates)
            {
                // Implicit derivatives become unreliable after neighbouring
                // pixels take different branches through the raymarch. Force a
                // consistent mip so 2x2 pixel quads cannot form box seams.
                return SAMPLE_TEXTURE3D_LOD(
                    _NoiseTex,
                    sampler_NoiseTex,
                    coordinates,
                    0.0
                );
            }

            float3 GetNormalizedWindDirection()
            {
                float3 windDirection = _WindDirection.xyz;
                float lengthSquared = dot(windDirection, windDirection);

                return lengthSquared > 0.000001
                    ? windDirection * rsqrt(lengthSquared)
                    : float3(1.0, 0.0, 0.0);
            }

            float InterleavedGradientNoise(float2 pixelPosition)
            {
                // A stable, low-discrepancy screen-space sequence. Compared
                // with white-noise hashing, neighbouring pixels cover a ray
                // interval more evenly and produce much less salt-and-pepper
                // breakup when a cloud is small on screen.
                return frac(
                    52.9829189 *
                    frac(dot(pixelPosition, float2(0.06711056, 0.00583715)))
                );
            }

            float GetCloudDistanceScale()
            {
                return max(_CloudDistanceScale, 0.001);
            }

            float3 GetShapeLocalPosition(float3 positionWS, int shapeIndex)
            {
                return mul(_ShapeWorldToLocal[shapeIndex], float4(positionWS, 1.0)).xyz;
            }

            float EllipsoidSDF(float3 localPosition)
            {
                return length(localPosition) - 0.5;
            }

            float CapsuleSDF(float3 localPosition, float radius)
            {
                radius = clamp(radius, 0.01, 0.49);

                float halfSegment = max(0.5 - radius, 0.001);
                float3 pointA = float3(-halfSegment, 0.0, 0.0);
                float3 pointB = float3(halfSegment, 0.0, 0.0);
                float3 pointVector = localPosition - pointA;
                float3 segmentVector = pointB - pointA;

                float segmentAmount = saturate(
                    dot(pointVector, segmentVector) /
                    max(dot(segmentVector, segmentVector), 0.0001)
                );

                return length(pointVector - segmentVector * segmentAmount) - radius;
            }

            float RoundedBoxSDF(float3 localPosition, float radius)
            {
                radius = clamp(radius, 0.001, 0.49);

                float3 distanceToBox = abs(localPosition) - (0.5 - radius);
                float outsideDistance = length(max(distanceToBox, 0.0));
                float insideDistance = min(
                    max(distanceToBox.x, max(distanceToBox.y, distanceToBox.z)),
                    0.0
                );

                return outsideDistance + insideDistance - radius;
            }

            float BoxSDF(float3 localPosition)
            {
                float3 distanceToBox = abs(localPosition) - 0.5;
                float outsideDistance = length(max(distanceToBox, 0.0));
                float insideDistance = min(
                    max(distanceToBox.x, max(distanceToBox.y, distanceToBox.z)),
                    0.0
                );

                return outsideDistance + insideDistance;
            }

            float EvaluateShapeSDF(float3 positionWS, int shapeIndex)
            {
                float4 shapeData0 = _ShapeData0[shapeIndex];
                float4 shapeData1 = _ShapeData1[shapeIndex];

                float shapeType = shapeData0.x;
                float radius = shapeData1.x;
                float distanceScale = max(shapeData1.y, 0.0001);
                float3 localPosition = GetShapeLocalPosition(positionWS, shapeIndex);

                if (shapeIndex == 0)
                {
                    float alongShape = saturate(localPosition.x + 0.5);
                    float taperScale = 1.0 + lerp(_LengthTaper, -_LengthTaper, alongShape);
                    localPosition.yz /= max(taperScale, 0.2);
                }

                float shapeSdf;

                if (shapeType < 0.5)
                {
                    shapeSdf = EllipsoidSDF(localPosition);
                }
                else if (shapeType < 1.5)
                {
                    shapeSdf = CapsuleSDF(localPosition, radius);
                }
                else if (shapeType < 2.5)
                {
                    shapeSdf = RoundedBoxSDF(localPosition, radius);
                }
                else
                {
                    shapeSdf = BoxSDF(localPosition);
                }

                return shapeSdf * distanceScale;
            }

            float SmoothMinimum(float a, float b, float smoothing)
            {
                smoothing = max(smoothing, 0.0001);
                float h = saturate(0.5 + 0.5 * (b - a) / smoothing);
                return lerp(b, a, h) - smoothing * h * (1.0 - h);
            }

            float SmoothMaximum(float a, float b, float smoothing)
            {
                return -SmoothMinimum(-a, -b, smoothing);
            }

            float EvaluateCombinedShapeSDF(
                float3 positionWS,
                out float blendedDistanceScale
            )
            {
                float combinedSdf = 1000000.0;
                float hasAdditiveShape = 0.0;
                blendedDistanceScale = max(_CloudDistanceScale, 0.001);

                [loop]
                for (int i = 0; i < MAX_CLOUD_SHAPES; i++)
                {
                    if (i >= _ShapeCount) break;

                    float4 shapeData = _ShapeData0[i];
                    if (shapeData.w < 0.5) continue;

                    float operation = shapeData.y;
                    float blend = max(shapeData.z, 0.0001);
                    float shapeSdf = EvaluateShapeSDF(positionWS, i);

                    if (operation < 0.5)
                    {
                        float shapeDistanceScale = max(
                            _ShapeData1[i].y /
                            max(_NoiseReferenceSize, 0.001),
                            0.001
                        );

                        if (hasAdditiveShape > 0.5)
                        {
                            float blendAmount = saturate(
                                0.5 +
                                0.5 *
                                (shapeSdf - combinedSdf) /
                                blend
                            );

                            combinedSdf =
                                lerp(shapeSdf, combinedSdf, blendAmount) -
                                blend *
                                blendAmount *
                                (1.0 - blendAmount);

                            blendedDistanceScale = lerp(
                                shapeDistanceScale,
                                blendedDistanceScale,
                                blendAmount
                            );
                        }
                        else
                        {
                            combinedSdf = shapeSdf;
                            blendedDistanceScale = shapeDistanceScale;
                        }

                        hasAdditiveShape = 1.0;
                    }
                    else if (hasAdditiveShape > 0.5)
                    {
                        combinedSdf = SmoothMaximum(combinedSdf, -shapeSdf, blend);
                    }
                }

                return hasAdditiveShape > 0.5 ? combinedSdf : 1000000.0;
            }

            float EvaluateCombinedShapeSDF(float3 positionWS)
            {
                float unusedDistanceScale;
                return EvaluateCombinedShapeSDF(
                    positionWS,
                    unusedDistanceScale
                );
            }

            float3 GetWorldNoisePosition(float3 positionWS)
            {
                // A single world-aligned field is shared by every guide in the
                // volume. Translation moves a guide through the field, while
                // rotating it cannot rotate either the noise or the wind.
                return positionWS / max(_CloudDistanceScale, 0.001);
            }

            float SampleSdfCloudDensity(float3 positionWS)
            {
                if (any(positionWS < _BoundsMin.xyz) || any(positionWS > _BoundsMax.xyz)) return 0.0;

                float cloudDistanceScale;
                float rawShapeSdf = EvaluateCombinedShapeSDF(
                    positionWS,
                    cloudDistanceScale
                );
                if (rawShapeSdf > 999999.0) return 0.0;

                float3 cloudNoisePosition = GetWorldNoisePosition(positionWS);

                // Use a volume-wide vertical mask so blended guides never
                // switch abruptly between different local coordinate frames.
                float heightAmount = saturate(
                    (positionWS.y - _BoundsMin.y) /
                    max(_BoundsMax.y - _BoundsMin.y, 0.001)
                );
                float directionalAmount = smoothstep(0.12, 0.58, heightAmount);

                float boundaryWarpMask = lerp(
                    _BottomWarpMultiplier,
                    1.0,
                    directionalAmount
                );

                float3 windDirection = GetNormalizedWindDirection();
                float3 windOffset = windDirection * (_Time.y * _WindSpeed);
                float3 noisePosition = cloudNoisePosition + _NoiseOffset.xyz + windOffset;

                float3 largeCoordinates = noisePosition * _ShapeWarpScale;
                float3 billowCoordinates = noisePosition * _BillowScale;
                float3 secondaryCoordinates = noisePosition * _SecondaryBillowScale;
                float3 erosionCoordinates = noisePosition * _SurfaceErosionScale;

                float4 largeSample = SampleCloudNoise(largeCoordinates);

                float4 billowSample = SampleCloudNoise(billowCoordinates);

                float4 secondarySample = SampleCloudNoise(
                    secondaryCoordinates
                );

                float4 erosionSample = SampleCloudNoise(erosionCoordinates);

                // Treat the SDF as a container rather than a solid density
                // volume. A broad, gently warped field leaves connected wisps
                // and open air while the SDF still defines the outer region.
                float3 coveragePosition =
                    noisePosition +
                    (largeSample.gba - 0.5) *
                    _CoverageWarpStrength;

                // Stretch this broad 3D field along the wind direction. The
                // resulting connected ribbons read as vapor trails instead of
                // another layer of round Worley cells.
                float3 wispForward = windDirection;
                float3 wispReferenceAxis =
                    abs(wispForward.y) < 0.9
                    ? float3(0.0, 1.0, 0.0)
                    : float3(1.0, 0.0, 0.0);
                float3 wispSide = normalize(cross(
                    wispReferenceAxis,
                    wispForward
                ));
                float3 wispUp = cross(wispForward, wispSide);
                float3 coverageCoordinates = float3(
                    dot(coveragePosition, wispForward) * 0.42,
                    dot(coveragePosition, wispUp) * 1.15,
                    dot(coveragePosition, wispSide) * 0.78
                ) * _CoverageScale;

                float4 coverageSample = SampleCloudNoise(
                    coverageCoordinates
                );

                float largeNoise =
                    largeSample.r * 0.7 +
                    largeSample.g * 0.3;

                float largeShapeField = smoothstep(
                    0.28,
                    0.74,
                    largeNoise
                );

                // Unlike the previous one-way bulge, this centered field can
                // push the guide shape outward or cut it inward. Slightly
                // stronger variation keeps the authored guide from retaining
                // a perfectly smooth primitive silhouette.
                float signedLargeShape = largeShapeField * 2.0 - 1.0;
                float outwardMacroShape = max(signedLargeShape, 0.0);
                float inwardMacroShape = max(-signedLargeShape, 0.0);
                float macroShapeDisplacement =
                    (outwardMacroShape - inwardMacroShape * 0.85) *
                    _ShapeWarpStrength *
                    cloudDistanceScale *
                    boundaryWarpMask;

                float shapeReferenceScale = max(
                    cloudDistanceScale * _NoiseReferenceSize,
                    0.001
                );

                float largeWarpedSdf =
                    rawShapeSdf +
                    _ShapeInset *
                    shapeReferenceScale -
                    macroShapeDisplacement;

                float largeDepth = max(-largeWarpedSdf, 0.0);

                // Blend the packed Perlin-Worley and low-frequency Worley
                // channels. A signed cloud signal produces round lobes without
                // the cellular ridges caused by taking an absolute value.
                float billowBase =
                    billowSample.r * 0.72 +
                    billowSample.g * 0.28;

                float secondaryBase =
                    secondarySample.r * 0.78 +
                    secondarySample.g * 0.22;

                float surfaceLobeMask = 1.0 - smoothstep(
                    0.0,
                    max(_InteriorDensityRamp * cloudDistanceScale * 1.4, 0.001),
                    largeDepth
                );

                float middleLobeMask = 1.0 - smoothstep(
                    0.0,
                    max(_InteriorDensityRamp * cloudDistanceScale * 2.0, 0.001),
                    largeDepth
                );

                float billowBulge = smoothstep(
                    0.40,
                    0.76,
                    billowBase
                );

                float secondaryBulge = smoothstep(
                    0.44,
                    0.80,
                    secondaryBase
                );

                // Signed displacement is essential here. Purely outward
                // billows preserve a recognizable sphere/capsule underneath;
                // signed lobes also excavate valleys and break that primitive
                // silhouette into a cauliflower-like cloud mass.
                float signedBillow = billowBulge * 2.0 - 1.0;
                float signedSecondaryBillow = secondaryBulge * 2.0 - 1.0;

                float lobeWarp =
                    signedBillow *
                    _BillowStrength *
                    cloudDistanceScale *
                    lerp(0.35, 1.0, surfaceLobeMask) *
                    boundaryWarpMask;

                lobeWarp +=
                    signedSecondaryBillow *
                    _SecondaryBillowStrength *
                    cloudDistanceScale *
                    lerp(0.15, 0.7, middleLobeMask) *
                    boundaryWarpMask;

                float lobeSdf = largeWarpedSdf - lobeWarp;
                float lobeDepth = max(-lobeSdf, 0.0);

                float erosionSurfaceMask = 1.0 - smoothstep(
                    0.0,
                    max(_SurfaceErosionDepth * cloudDistanceScale, 0.001),
                    lobeDepth
                );

                float worleyFbm =
                    erosionSample.g * 0.625 +
                    erosionSample.b * 0.25 +
                    erosionSample.a * 0.125;

                float erosionPattern = saturate(1.0 - worleyFbm);

                float erosionAmount =
                    erosionPattern *
                    _SurfaceErosionStrength *
                    cloudDistanceScale *
                    erosionSurfaceMask *
                    boundaryWarpMask;

                float detailedShapeSdf = lobeSdf + erosionAmount;

                // Keep the authored primitive recognizable. Detail is applied
                // as a controlled deviation from the original combined SDF,
                // rather than replacing its silhouette outright.
                float finalShapeSdf = lerp(
                    rawShapeSdf,
                    detailedShapeSdf,
                    saturate(_ShapeDetailStrength)
                );
                float signedInteriorDistance = -finalShapeSdf;

                float edgeWispReach = max(
                    _EdgeWispReach * cloudDistanceScale,
                    0.001
                );

                if (signedInteriorDistance <= -edgeWispReach) return 0.0;

                float edgeWidth = max(
                    _ShapeSoftness * cloudDistanceScale,
                    0.001
                );
                float densityRange = max(
                    _InteriorDensityRamp * cloudDistanceScale,
                    edgeWidth
                );

                // Use only the smooth Perlin-Worley channel plus a small
                // amount of large-scale noise. Fine Worley channels create the
                // visibly repeating bead pattern this layer is meant to avoid.
                float coverageNoise = saturate(
                    coverageSample.r * 0.62 +
                    largeSample.r * 0.13 +
                    billowBase * 0.18 +
                    secondaryBase * 0.07
                );

                float interiorAmount = saturate(
                    signedInteriorDistance /
                    max(_InteriorDensityRamp * 2.0, 0.001)
                );

                float coverageThreshold =
                    _CoverageThreshold -
                    interiorAmount *
                    _CoverageInteriorBias;

                float coverageMask = smoothstep(
                    coverageThreshold - _CoverageSoftness,
                    coverageThreshold + _CoverageSoftness,
                    coverageNoise
                );

                coverageMask = pow(
                    saturate(coverageMask),
                    max(_CoverageContrast, 0.001)
                );

                // Carve shallow low-density channels into the SDF interior.
                // The carve is strongest at the silhouette and fades into the
                // core so the authored shape remains cohesive.
                float coverageCarveDistance =
                    (1.0 - coverageMask) *
                    saturate(_CoverageStrength) *
                    densityRange *
                    1.15 *
                    lerp(1.0, 0.28, interiorAmount);

                float edgeWispNoise = saturate(
                    largeSample.r * 0.58 +
                    billowSample.r * 0.42
                );

                float edgeWispPattern = smoothstep(
                    _EdgeWispThreshold - _EdgeWispSoftness,
                    _EdgeWispThreshold + _EdgeWispSoftness,
                    edgeWispNoise
                );

                // Extend the same signed boundary in sparse patches instead
                // of layering a second density shell over the cloud. Squaring
                // the mask keeps the extension broken up and avoids a halo.
                float edgeWispExtension =
                    edgeWispPattern *
                    edgeWispPattern *
                    edgeWispReach *
                    _EdgeWispStrength *
                    1.6 *
                    lerp(0.30, 1.0, directionalAmount);

                float positiveInteriorDistance = max(
                    signedInteriorDistance +
                    edgeWispExtension -
                    coverageCarveDistance,
                    0.0
                );

                float interiorDensity = saturate(
                    positiveInteriorDistance /
                    densityRange
                );

                interiorDensity =
                    interiorDensity *
                    interiorDensity *
                    (3.0 - 2.0 * interiorDensity);

                interiorDensity *= smoothstep(
                    0.0,
                    edgeWidth,
                    positiveInteriorDistance
                );

                interiorDensity = pow(
                    max(interiorDensity, 0.0001),
                    max(_DensityContrast, 0.001)
                );

                float densityBillowSignal = saturate(
                    billowBase * 0.7 +
                    secondaryBase * 0.3
                );

                float densityBillow = lerp(
                    1.0 - _BillowDensityVariation,
                    1.0 + _BillowDensityVariation,
                    densityBillowSignal
                );

                // Coverage now owns real occupancy throughout the SDF instead
                // of merely tinting an otherwise solid primitive. The small
                // residual is removed by DensityCutoff, leaving connected
                // opaque lobes separated by genuine empty pockets.
                float carvedCoverage = pow(
                    saturate(coverageMask),
                    0.85
                );
                float wispyMask = lerp(
                    1.0,
                    lerp(0.04, 1.0, carvedCoverage),
                    saturate(_CoverageStrength)
                );

                float coreDensity =
                    interiorDensity *
                    densityBillow *
                    wispyMask;

                float baseDensity = coreDensity;

                baseDensity = saturate(
                    (baseDensity - _DensityCutoff) /
                    max(1.0 - _DensityCutoff, 0.001)
                );

                return baseDensity * _Density;
            }

            float EvaluateShapeGuideInfluence(float3 positionWS)
            {
                if (_ShapeCount <= 0) return 1.0;

                float cloudDistanceScale = GetCloudDistanceScale();

                float additiveInfluence = 0.0;
                float subtractiveInfluence = 0.0;

                [loop]
                for (int i = 0; i < MAX_CLOUD_SHAPES; i++)
                {
                    if (i >= _ShapeCount) break;

                    float4 shapeData = _ShapeData0[i];
                    if (shapeData.w < 0.5) continue;

                    float shapeSdf = EvaluateShapeSDF(positionWS, i);
                    float shapeScale = max(_ShapeData1[i].y, 0.001);
                    float innerFalloff = max(
                        _ShapeSoftness * cloudDistanceScale,
                        shapeScale * 0.02
                    );
                    float outerFalloff = max(
                        _EdgeWispReach * cloudDistanceScale,
                        shapeScale * 0.045
                    );
                    float influence = 1.0 - smoothstep(
                        -innerFalloff,
                        outerFalloff,
                        shapeSdf
                    );

                    // Additive guides remain independent instead of being
                    // smooth-unioned, so moving one shape molds one region and
                    // cannot create an unintended density bridge to another.
                    if (shapeData.y < 0.5)
                    {
                        additiveInfluence = max(
                            additiveInfluence,
                            influence
                        );
                    }
                    else
                    {
                        subtractiveInfluence = max(
                            subtractiveInfluence,
                            influence
                        );
                    }
                }

                return saturate(
                    additiveInfluence *
                    (1.0 - subtractiveInfluence)
                );
            }

            float SampleBoundsCloudDensity(float3 positionWS)
            {
                if (
                    any(positionWS < _BoundsMin.xyz) ||
                    any(positionWS > _BoundsMax.xyz)
                )
                {
                    return 0.0;
                }

                float3 distanceToFace = min(
                    positionWS - _BoundsMin.xyz,
                    _BoundsMax.xyz - positionWS
                );
                float cloudDistanceScale = GetCloudDistanceScale();

                float3 cloudNoisePosition = mul(
                    _CloudWorldToNoise,
                    float4(positionWS, 1.0)
                ).xyz;
                float3 windDirection = GetNormalizedWindDirection();
                float3 windOffset =
                    windDirection *
                    (_Time.y * _WindSpeed);
                float3 noisePosition =
                    cloudNoisePosition +
                    _NoiseOffset.xyz +
                    windOffset;

                float4 largeSample = SampleCloudNoise(
                    noisePosition * _ShapeWarpScale
                );

                // The AABB is only a raymarch container. Density fades before
                // reaching its faces so no part of its silhouette is visible.
                float sideFade = smoothstep(
                    0.0,
                    max(_HorizontalFade * cloudDistanceScale, 0.001),
                    min(distanceToFace.x, distanceToFace.z)
                );
                float bottomFade = smoothstep(
                    0.0,
                    max(_BottomFade * cloudDistanceScale, 0.001),
                    positionWS.y - _BoundsMin.y
                );
                float topFade = smoothstep(
                    0.0,
                    max(_TopFadeStart * cloudDistanceScale, 0.001),
                    _BoundsMax.y - positionWS.y
                );
                float containerFade = sideFade * bottomFade * topFade;

                if (containerFade <= 0.0001) return 0.0;

                float3 coveragePosition =
                    noisePosition +
                    (largeSample.gba - 0.5) *
                    _CoverageWarpStrength;

                // Anisotropic sampling produces elongated, connected masses
                // along the wind instead of uniformly distributed noise blobs.
                float3 cloudForward = windDirection;
                float3 referenceAxis =
                    abs(cloudForward.y) < 0.9
                    ? float3(0.0, 1.0, 0.0)
                    : float3(1.0, 0.0, 0.0);
                float3 cloudSide = normalize(cross(
                    referenceAxis,
                    cloudForward
                ));
                float3 cloudUp = cross(cloudForward, cloudSide);
                float3 coverageCoordinates = float3(
                    dot(coveragePosition, cloudForward) * 0.78,
                    dot(coveragePosition, cloudUp) * 1.05,
                    dot(coveragePosition, cloudSide) * 0.90
                ) * _CoverageScale;

                float4 coverageSample = SampleCloudNoise(
                    coverageCoordinates
                );
                float4 billowSample = SampleCloudNoise(
                    noisePosition * _BillowScale
                );
                float4 secondarySample = SampleCloudNoise(
                    noisePosition * _SecondaryBillowScale
                );
                float4 erosionSample = SampleCloudNoise(
                    noisePosition * _SurfaceErosionScale
                );

                float billowNoise = saturate(
                    billowSample.r * 0.78 +
                    billowSample.g * 0.22
                );
                float secondaryNoise = saturate(
                    secondarySample.r * 0.82 +
                    secondarySample.g * 0.18
                );

                // Coverage defines the cloud itself. Larger and smaller noise
                // only reshape that field; no primitive distance is involved.
                float broadCoverage =
                    coverageSample.r -
                    (1.0 - coverageSample.g) *
                    0.32;
                float detailedDensitySignal = broadCoverage;
                detailedDensitySignal +=
                    (largeSample.r - 0.5) *
                    _ShapeWarpStrength *
                    0.26;
                detailedDensitySignal +=
                    (billowNoise - 0.5) *
                    _BillowStrength *
                    0.18;
                detailedDensitySignal +=
                    (secondaryNoise - 0.5) *
                    _SecondaryBillowStrength *
                    0.12;
                detailedDensitySignal -=
                    (1.0 - coverageSample.r) *
                    _CoverageStrength *
                    0.08;

                float densitySignal = lerp(
                    broadCoverage,
                    detailedDensitySignal,
                    saturate(_ShapeDetailStrength)
                );

                // Multiplying by a soft box fade is insufficient in a volume:
                // many weak samples still accumulate into opaque planar faces.
                // Raising the empty-space requirement near the container makes
                // density reach zero well before those faces instead.
                densitySignal -=
                    (1.0 - containerFade) *
                    0.72;

                if (_UseShapeGuides > 0.5 && _ShapeCount > 0)
                {
                    float shapeGuideInfluence =
                        EvaluateShapeGuideInfluence(positionWS);

                    // The guide modifies the occupancy requirement rather than
                    // multiplying the final density. Noise therefore owns the
                    // visible outline, while regions between authored shapes
                    // are guaranteed to remain empty.
                    densitySignal -=
                        (1.0 - shapeGuideInfluence) *
                        0.90;
                }

                float wispNoise = saturate(
                    coverageSample.r * 0.58 +
                    largeSample.r * 0.42
                );
                float wispPattern = smoothstep(
                    _EdgeWispThreshold - _EdgeWispSoftness,
                    _EdgeWispThreshold + _EdgeWispSoftness,
                    wispNoise
                );

                // Sparse patches lower the same isosurface threshold, creating
                // natural extensions without adding a separate fuzzy shell.
                float localThreshold =
                    _CoverageThreshold -
                    wispPattern *
                    _EdgeWispStrength *
                    0.10;
                float fieldSoftness = max(_CoverageSoftness, 0.001);

                // One continuous field produces both the substantial cloud
                // body and its vaporous transition. The wider presence range
                // retains low-density material while the core remap prevents
                // the whole formation from becoming uniformly translucent.
                float cloudPresence = smoothstep(
                    localThreshold - fieldSoftness * 1.65,
                    localThreshold + fieldSoftness,
                    densitySignal
                );
                float coreDensity = smoothstep(
                    localThreshold - fieldSoftness * 0.15,
                    localThreshold + fieldSoftness * 0.85,
                    densitySignal
                );
                coreDensity = pow(
                    saturate(coreDensity),
                    max(_CoverageContrast, 0.001)
                );
                float baseDensity =
                    cloudPresence *
                    lerp(0.28, 1.0, coreDensity);

                float worleyFbm =
                    erosionSample.g * 0.625 +
                    erosionSample.b * 0.25 +
                    erosionSample.a * 0.125;
                float erosionPattern = saturate(1.0 - worleyFbm);
                float surfaceAmount = 1.0 - smoothstep(
                    0.18,
                    0.78,
                    baseDensity
                );

                baseDensity = saturate(
                    baseDensity -
                    erosionPattern *
                    _SurfaceErosionStrength *
                    surfaceAmount
                );

                float billowVariation = lerp(
                    1.0 - _BillowDensityVariation,
                    1.0 + _BillowDensityVariation,
                    billowNoise
                );

                baseDensity *= billowVariation * containerFade;
                baseDensity = pow(
                    max(baseDensity, 0.0001),
                    max(_DensityContrast, 0.001)
                );
                baseDensity = saturate(
                    (baseDensity - _DensityCutoff) /
                    max(1.0 - _DensityCutoff, 0.001)
                );

                return baseDensity * _Density;
            }

            float SampleCloudDensity(float3 positionWS)
            {
                if (_UseSdfShape > 0.5)
                {
                    return SampleSdfCloudDensity(positionWS);
                }

                return SampleBoundsCloudDensity(positionWS);
            }

            float SampleCloudDensityForLighting(float3 positionWS)
            {
                if (_UseSdfShape <= 0.5)
                {
                    return SampleBoundsCloudDensity(positionWS);
                }

                if (
                    any(positionWS < _BoundsMin.xyz) ||
                    any(positionWS > _BoundsMax.xyz)
                )
                {
                    return 0.0;
                }

                float shapeDistanceScale;
                float rawShapeSdf = EvaluateCombinedShapeSDF(
                    positionWS,
                    shapeDistanceScale
                );

                if (rawShapeSdf > 999999.0) return 0.0;

                float3 noisePosition =
                    GetWorldNoisePosition(positionWS) +
                    _NoiseOffset.xyz +
                    GetNormalizedWindDirection() *
                    (_Time.y * _WindSpeed);

                // Shadows only need the broad density structure. Sampling two
                // fields here instead of the five-field surface density keeps
                // full/three-quarter-resolution rendering affordable.
                float4 largeSample = SampleCloudNoise(
                    noisePosition * _ShapeWarpScale
                );
                float4 coverageSample = SampleCloudNoise(
                    noisePosition * _CoverageScale
                );

                float largeSignal = saturate(
                    largeSample.r * 0.72 +
                    largeSample.g * 0.28
                );
                float signedLargeSignal = largeSignal * 2.0 - 1.0;
                float coarseSdf =
                    rawShapeSdf -
                    signedLargeSignal *
                    _ShapeWarpStrength *
                    shapeDistanceScale *
                    0.72;

                float interiorDensity = smoothstep(
                    -_EdgeWispReach * shapeDistanceScale,
                    _InteriorDensityRamp * shapeDistanceScale,
                    -coarseSdf
                );
                float coverageSignal = saturate(
                    coverageSample.r * 0.82 +
                    largeSample.r * 0.18
                );
                float coverageMask = smoothstep(
                    _CoverageThreshold - _CoverageSoftness * 1.4,
                    _CoverageThreshold + _CoverageSoftness,
                    coverageSignal
                );

                return
                    interiorDensity *
                    lerp(0.06, 1.0, coverageMask) *
                    _Density;
            }

            float GetLightTransmittance(float3 positionWS, float3 lightDirection)
            {
                const int LIGHT_STEP_COUNT = 3;

                float opticalDepth = 0.0;
                float cloudDistanceScale = GetCloudDistanceScale();
                float lightStepLength = max(
                    _LightStepLength * cloudDistanceScale,
                    0.001
                );
                float lightJitter = lerp(
                    0.35,
                    1.0,
                    Hash13(positionWS * 1.731)
                );

                float3 lightSamplePosition =
                    positionWS +
                    lightDirection *
                    (lightStepLength * lightJitter);

                [unroll]
                for (int i = 0; i < LIGHT_STEP_COUNT; i++)
                {
                    opticalDepth +=
                        SampleCloudDensityForLighting(lightSamplePosition) *
                        lightStepLength;

                    // Expanding steps see substantially farther into large
                    // volumes while keeping the first shadow sample detailed.
                    lightStepLength *= 2.1;

                    lightSamplePosition +=
                        lightDirection *
                        lightStepLength;
                }

                return exp(
                    -opticalDepth *
                    _Extinction /
                    cloudDistanceScale
                );
            }

            float HenyeyGreenstein(float cosTheta, float g)
            {
                float gSquared = g * g;

                float denominator = pow(
                    max(
                        1.0 +
                        gSquared -
                        2.0 * g * cosTheta,
                        0.001
                    ),
                    1.5
                );

                return (1.0 - gSquared) / denominator;
            }

            float GetCloudPhase(float cosTheta)
            {
                float forwardPhase = HenyeyGreenstein(
                    cosTheta,
                    _ForwardScattering
                );

                float backwardPhase = HenyeyGreenstein(
                    cosTheta,
                    -_BackwardScattering
                );

                float dualPhase = min(
                    lerp(
                        backwardPhase,
                        forwardPhase,
                        _PhaseBlend
                    ),
                    10.0
                );

                return lerp(
                    1.0,
                    dualPhase,
                    _PhaseStrength
                );
            }

            float4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;

                float3 rayOrigin;
                float3 rayDirection;
                GetCameraRay(uv, rayOrigin, rayDirection);

                float2 boxInfo = RayBoxIntersection(
                    rayOrigin,
                    rayDirection,
                    _BoundsMin.xyz,
                    _BoundsMax.xyz
                );

                float distanceToBox = boxInfo.x;
                float distanceInsideBox = boxInfo.y;

                if (distanceInsideBox <= 0.0)
                {
                    return float4(0.0, 0.0, 0.0, 1.0);
                }

                float sceneDistance = GetSceneDistance(
                    uv,
                    rayOrigin,
                    rayDirection
                );

                float cloudStart = distanceToBox;

                float cloudEnd = min(
                    distanceToBox + distanceInsideBox,
                    sceneDistance
                );

                float marchLength = max(
                    cloudEnd - cloudStart,
                    0.0
                );

                if (marchLength <= 0.0)
                {
                    return float4(0.0, 0.0, 0.0, 1.0);
                }

                // The high cap protects elongated authored clouds. Empty-space
                // SDF skipping means most rays still execute far fewer steps.
                const int MAX_MARCH_ITERATIONS = 768;

                float cloudDistanceScale = GetCloudDistanceScale();
                float stepLength = max(
                    _RayStepSize * cloudDistanceScale,
                    0.001
                );

                float jitterOffset = lerp(
                    0.5,
                    InterleavedGradientNoise(uv * _ScreenParams.xy),
                    saturate(_RayJitter)
                );

                float travelledDistance = stepLength * jitterOffset;
                float transmittance = 1.0;
                float3 accumulatedLight = 0.0;
                float cachedLightTransmittance = 1.0;
                int occupiedSampleCount = 0;

                float maximumOutwardDisplacement =
                    (
                        _ShapeWarpStrength +
                        _BillowStrength +
                        _SecondaryBillowStrength +
                        _ShapeSoftness
                    ) * cloudDistanceScale;

                Light mainLight = GetMainLight();
                float3 lightDirection = normalize(mainLight.direction);
                float3 sunColor = mainLight.color * _SunStrength;

                float phase = GetCloudPhase(
                    dot(rayDirection, lightDirection)
                );

                [loop]
                for (int i = 0; i < MAX_MARCH_ITERATIONS; i++)
                {
                    if (travelledDistance >= marchLength) break;

                    float3 samplePosition =
                        rayOrigin +
                        rayDirection *
                        (cloudStart + travelledDistance);

                    float surfaceDetailAmount = 1.0;

                    // SDF distance skipping is only valid for the legacy
                    // envelope mode. Bounds-density clouds may occur anywhere
                    // inside the container and must sample the full interval.
                    if (_UseSdfShape > 0.5)
                    {
                        float rawShapeSdf = EvaluateCombinedShapeSDF(
                            samplePosition
                        );
                        float safeEmptyDistance =
                            rawShapeSdf -
                            maximumOutwardDisplacement;

                        if (safeEmptyDistance > stepLength * 1.5)
                        {
                            travelledDistance += max(
                                stepLength,
                                safeEmptyDistance * 0.8
                            );

                            continue;
                        }

                        surfaceDetailAmount = saturate(
                            (maximumOutwardDisplacement - rawShapeSdf) /
                            max(
                                maximumOutwardDisplacement +
                                _InteriorDensityRamp * cloudDistanceScale,
                                0.001
                            )
                        );
                    }

                    // Spend the fine steps on the displaced silhouette where
                    // they are visible. The previous interpolation was
                    // reversed, making empty space expensive and the cloud
                    // surface visibly coarse at close range.
                    float sampleStepLength = stepLength * lerp(
                        1.0,
                        saturate(_DetailStepScale),
                        surfaceDetailAmount
                    );

                    float density = SampleCloudDensity(samplePosition);

                    if (density > 0.001)
                    {
                        float stepTransmittance = exp(
                            -density *
                            _Extinction *
                            sampleStepLength /
                            cloudDistanceScale
                        );

                        float scatteredAmount =
                            1.0 -
                            stepTransmittance;

                        // Lighting changes much more slowly along the view ray
                        // than density. Reuse it for one neighbouring occupied
                        // sample, halving the nested shadow-ray work without a
                        // visible loss at the current fine view step.
                        if ((occupiedSampleCount & 1) == 0)
                        {
                            cachedLightTransmittance = GetLightTransmittance(
                                samplePosition,
                                lightDirection
                            );
                        }

                        occupiedSampleCount++;

                        float lightTransmittance =
                            cachedLightTransmittance;

                        float lightAmount = pow(
                            saturate(lightTransmittance),
                            _LightColorPower
                        );

                        float powderAmount =
                            1.0 -
                            exp(
                                -density *
                                sampleStepLength /
                                cloudDistanceScale *
                                4.0
                            );

                        float directVisibility =
                            lightTransmittance *
                            (1.0 + powderAmount * _PowderStrength);

                        float3 sampleColor = lerp(
                            _ShadowCloudColor.rgb,
                            _LightCloudColor.rgb,
                            lightAmount
                        );

                        float deepAmount = saturate(
                            (1.0 - transmittance) *
                            _DeepColorStrength
                        );

                        deepAmount *= lerp(
                            0.35,
                            1.0,
                            1.0 - lightAmount
                        );

                        sampleColor = lerp(
                            sampleColor,
                            _DeepCloudColor.rgb,
                            deepAmount
                        );

                        float3 directLighting =
                            sunColor *
                            directVisibility *
                            phase;

                        float primaryHeight = saturate(
                            (samplePosition.y - _BoundsMin.y) /
                            max(_BoundsMax.y - _BoundsMin.y, 0.001)
                        );

                        float ambientHeight = lerp(
                            1.0 - _AmbientHeightContrast,
                            1.0 + _AmbientHeightContrast,
                            primaryHeight
                        );

                        float3 ambientLighting =
                            _AmbientColor.rgb *
                            _AmbientStrength *
                            ambientHeight;

                        float3 cloudLighting =
                            ambientLighting +
                            directLighting;

                        accumulatedLight +=
                            transmittance *
                            scatteredAmount *
                            cloudLighting *
                            sampleColor *
                            _CloudColor.rgb;

                        transmittance *= stepTransmittance;

                        if (transmittance < 0.01) break;
                    }

                    travelledDistance += sampleStepLength;
                }

                float physicalAlpha = 1.0 - transmittance;

                float artisticTransmittance = pow(
                    saturate(transmittance),
                    max(_OpacityPower, 0.001)
                );

                float artisticAlpha =
                    1.0 -
                    artisticTransmittance;

                if (physicalAlpha > 0.0001)
                {
                    accumulatedLight *=
                        artisticAlpha /
                        physicalAlpha;
                }

                transmittance = artisticTransmittance;

                return float4(
                    accumulatedLight,
                    transmittance
                );
            }

            ENDHLSL
        }

        Pass
        {
            Name "CloudComposite"

            // Cloud RGB is premultiplied radiance and alpha stores remaining
            // transmittance, so C = cloud + scene * transmittance. Preserve the
            // destination alpha channel for downstream post-processing.
            Blend One SrcAlpha, Zero One

            HLSLPROGRAM

            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment FragComposite

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            float4 FragComposite(Varyings input) : SV_Target
            {
                float2 textureSize = _BlitTexture_TexelSize.zw;
                float2 samplePosition =
                    input.texcoord * textureSize;
                float2 texelCenter =
                    floor(samplePosition - 0.5) + 0.5;
                float2 f = samplePosition - texelCenter;

                float2 w0 =
                    f * (-0.5 + f * (1.0 - 0.5 * f));
                float2 w1 =
                    1.0 + f * f * (-2.5 + 1.5 * f);
                float2 w2 =
                    f * (0.5 + f * (2.0 - 1.5 * f));
                float2 w3 =
                    f * f * (-0.5 + 0.5 * f);
                float2 w12 = w1 + w2;
                float2 offset12 = w2 / max(w12, 0.0001);

                float2 uv0 =
                    (texelCenter - 1.0) / textureSize;
                float2 uv12 =
                    (texelCenter + offset12) / textureSize;
                float2 uv3 =
                    (texelCenter + 2.0) / textureSize;

                float4 result = 0.0;

                result += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    float2(uv0.x, uv0.y)
                ) * w0.x * w0.y;
                result += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    float2(uv12.x, uv0.y)
                ) * w12.x * w0.y;
                result += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    float2(uv3.x, uv0.y)
                ) * w3.x * w0.y;
                result += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    float2(uv0.x, uv12.y)
                ) * w0.x * w12.y;
                result += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    float2(uv12.x, uv12.y)
                ) * w12.x * w12.y;
                result += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    float2(uv3.x, uv12.y)
                ) * w3.x * w12.y;
                result += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    float2(uv0.x, uv3.y)
                ) * w0.x * w3.y;
                result += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    float2(uv12.x, uv3.y)
                ) * w12.x * w3.y;
                result += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    float2(uv3.x, uv3.y)
                ) * w3.x * w3.y;

                return float4(
                    max(result.rgb, 0.0),
                    saturate(result.a)
                );
            }

            ENDHLSL
        }
    }
}
