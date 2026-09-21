using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public sealed class CloudVolumeRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public sealed class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

        [Tooltip("Fraction of camera resolution used for the expensive cloud raymarch. The cloud is composited back at full resolution.")]
        [Range(0.25f, 1f)]
        public float raymarchRenderScale = 0.75f;
    }

    [SerializeField] private Settings settings = new Settings();

    private CloudVolumeRenderPass renderPass;

    public override void Create()
    {
        renderPass = new CloudVolumeRenderPass
        {
            renderPassEvent = settings.renderPassEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (renderPass == null) return;

        CameraType cameraType = renderingData.cameraData.cameraType;

        if (cameraType == CameraType.Preview || cameraType == CameraType.Reflection) return;
        if (renderingData.cameraData.renderType == CameraRenderType.Overlay) return;

        renderPass.renderPassEvent = settings.renderPassEvent;
        renderPass.RaymarchRenderScale = Mathf.Clamp(
            settings.raymarchRenderScale,
            0.25f,
            1f
        );

        // SampleSceneDepth requires URP's camera depth texture.
        renderPass.ConfigureInput(ScriptableRenderPassInput.Depth);

        // The shader samples the existing camera color through _BlitTexture,
        // so the pass cannot render directly into the backbuffer.
        renderPass.requiresIntermediateTexture = true;

        renderer.EnqueuePass(renderPass);
    }

    private sealed class CloudVolumeRenderPass : ScriptableRenderPass
    {
        private readonly Plane[] cameraFrustumPlanes = new Plane[6];

        private sealed class PassData
        {
            public TextureHandle source;
            public TextureHandle destination;
            public TextureHandle depth;
            public Material material;
        }

        private sealed class CompositePassData
        {
            public TextureHandle source;
            public TextureHandle cloud;
            public TextureHandle destination;
            public Material material;
        }

        public float RaymarchRenderScale { get; set; } = 0.75f;

        public CloudVolumeRenderPass()
        {
            profilingSampler = new ProfilingSampler("Cloud Volumes");
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
            UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();

            Camera camera = cameraData.camera;

            if (camera == null) return;
            if (!resourceData.cameraColor.IsValid()) return;

            IReadOnlyList<CloudVolume> volumes = CloudVolumeRegistry.Volumes;

            if (volumes == null || volumes.Count == 0) return;

            GeometryUtility.CalculateFrustumPlanes(camera, cameraFrustumPlanes);

            TextureHandle currentSource = resourceData.cameraColor;
            int renderedVolumeCount = 0;

            for (int i = 0; i < volumes.Count; i++)
            {
                CloudVolume volume = volumes[i];

                if (
                    volume == null ||
                    !volume.PrepareForRendering(camera, cameraFrustumPlanes)
                )
                {
                    continue;
                }

                Material material = volume.RuntimeMaterial;

                if (
                    material == null ||
                    material.shader == null ||
                    !material.shader.isSupported ||
                    material.passCount <= 0
                )
                {
                    continue;
                }

                TextureDesc cloudDescriptor = renderGraph.GetTextureDesc(currentSource);
                cloudDescriptor.name = $"_CloudRaymarchHalfRes_{renderedVolumeCount}";
                cloudDescriptor.width = Mathf.Max(
                    1,
                    Mathf.CeilToInt(cloudDescriptor.width * RaymarchRenderScale)
                );
                cloudDescriptor.height = Mathf.Max(
                    1,
                    Mathf.CeilToInt(cloudDescriptor.height * RaymarchRenderScale)
                );
                cloudDescriptor.msaaSamples = MSAASamples.None;
                cloudDescriptor.depthBufferBits = 0;
                // Camera color can use an HDR format without alpha (for
                // example R11G11B10). Cloud alpha stores transmittance, so it
                // must live in an explicit four-channel render target.
                cloudDescriptor.format = GraphicsFormat.R16G16B16A16_SFloat;
                cloudDescriptor.filterMode = FilterMode.Bilinear;
                cloudDescriptor.wrapMode = TextureWrapMode.Clamp;
                cloudDescriptor.clearBuffer = false;

                TextureHandle cloudTexture = renderGraph.CreateTexture(cloudDescriptor);

                if (!cloudTexture.IsValid()) continue;

                string raymarchPassName = $"Cloud Raymarch: {volume.name}";

                using (IRasterRenderGraphBuilder builder =
                    renderGraph.AddRasterRenderPass<PassData>(
                        raymarchPassName,
                        out PassData passData,
                        profilingSampler))
                {
                    passData.source = currentSource;
                    passData.destination = cloudTexture;
                    passData.depth = resourceData.cameraDepthTexture;
                    passData.material = material;

                    builder.UseTexture(passData.source, AccessFlags.Read);

                    if (passData.depth.IsValid())
                    {
                        builder.UseTexture(passData.depth, AccessFlags.Read);
                    }

                    builder.SetRenderAttachment(
                        passData.destination,
                        0,
                        AccessFlags.WriteAll
                    );

                    builder.SetRenderFunc(static (PassData data, RasterGraphContext context) =>
                    {
                        if (data.material == null) return;

                        Blitter.BlitTexture(
                            context.cmd,
                            data.source,
                            Vector2.one,
                            data.material,
                            0
                        );
                    });
                }

                TextureDesc destinationDescriptor = renderGraph.GetTextureDesc(currentSource);
                destinationDescriptor.name = $"_CloudCompositeColor_{renderedVolumeCount}";
                destinationDescriptor.msaaSamples = MSAASamples.None;
                destinationDescriptor.depthBufferBits = 0;
                destinationDescriptor.clearBuffer = false;

                TextureHandle destination = renderGraph.CreateTexture(destinationDescriptor);

                if (!destination.IsValid()) continue;

                string compositePassName = $"Cloud Composite: {volume.name}";

                using (IRasterRenderGraphBuilder builder =
                    renderGraph.AddRasterRenderPass<CompositePassData>(
                        compositePassName,
                        out CompositePassData passData,
                        profilingSampler))
                {
                    passData.source = currentSource;
                    passData.cloud = cloudTexture;
                    passData.destination = destination;
                    passData.material = material;

                    builder.UseTexture(passData.source, AccessFlags.Read);
                    builder.UseTexture(passData.cloud, AccessFlags.Read);

                    builder.SetRenderAttachment(
                        passData.destination,
                        0,
                        AccessFlags.Write
                    );

                    builder.SetRenderFunc(static (CompositePassData data, RasterGraphContext context) =>
                    {
                        if (data.material == null) return;

                        // Preserve the full-resolution scene, then blend the
                        // low-resolution cloud radiance/transmittance over it.
                        Blitter.BlitTexture(
                            context.cmd,
                            data.source,
                            new Vector4(1f, 1f, 0f, 0f),
                            0f,
                            false
                        );

                        Blitter.BlitTexture(
                            context.cmd,
                            data.cloud,
                            Vector2.one,
                            data.material,
                            1
                        );
                    });
                }

                currentSource = destination;
                renderedVolumeCount++;
            }

            if (renderedVolumeCount > 0)
            {
                // Downstream URP passes now use the final cloud-composited texture.
                resourceData.cameraColor = currentSource;
            }
        }
    }
}
