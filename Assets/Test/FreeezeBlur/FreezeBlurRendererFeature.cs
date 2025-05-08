using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class FreezeBlurRendererFeature : ScriptableRendererFeature
{
    public static FreezeBlurRendererFeature Instance { get; private set; }

    [System.Serializable]
    public class FreezeBlurSettings
    {
        public Material blurMaterial;
        public float freezeDuration = 1f;
    }

    public FreezeBlurSettings settings = new FreezeBlurSettings();

    private FreezeBlurPass freezePass;

    private bool freezeRequested = false;
    private bool freezeActive = false;
    private bool cullMaskRecover = false;
    private float freezeTimer = 0f;

    private RenderTexture freezeRT;
    private RenderTexture permanentRT;
    
    private int originalCullingMask = -1;

    public void TriggerFreeze()
    {
        if (!freezeActive)
        {
            freezeRequested = true;
        }
    }

    public override void Create()
    {
        Instance = this;
        freezePass = new FreezeBlurPass(this);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //此效果只对Scene场景和带MainCamera标签的相机起作用
        if (renderingData.cameraData.cameraType != CameraType.SceneView &&
            !renderingData.cameraData.camera.CompareTag("MainCamera"))
        {
            return;
        }
        freezePass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(freezePass);

        // 冻帧期间不需要渲染其他物件
        if (freezeRequested && !cullMaskRecover)
        {
            originalCullingMask = renderingData.cameraData.camera.cullingMask;
            renderingData.cameraData.camera.cullingMask = 0;
            cullMaskRecover = true;
        }
        if (cullMaskRecover && !freezeActive)
        {
            renderingData.cameraData.camera.cullingMask = originalCullingMask;
            originalCullingMask = -1;
            cullMaskRecover = false;
        }
    }

    class FreezeBlurPass : ScriptableRenderPass
    {
        private FreezeBlurRendererFeature parent;
        private RenderTargetIdentifier cameraColorTarget;
        private string profilerTag = "FreezeBlurPass";

        public FreezeBlurPass(FreezeBlurRendererFeature parent)
        {
            this.parent = parent;
            renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        }

        public void Setup(RenderTargetIdentifier cameraColorTarget)
        {
            this.cameraColorTarget = cameraColorTarget;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (parent.settings.blurMaterial == null)
            {
                Debug.LogWarning("FreezeBlur: Missing blur material.");
                return;
            }

            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);

            var cameraDesc = renderingData.cameraData.cameraTargetDescriptor;
            int width = cameraDesc.width / 2;
            int height = cameraDesc.height / 2;

            if (parent.freezeRequested)
            {
                // Lazy init RTs
                if (parent.freezeRT == null)
                {
                    parent.freezeRT = new RenderTexture(width, height, 0, RenderTextureFormat.Default);
                    parent.freezeRT.Create();
                }
                if (parent.permanentRT == null)
                {
                    parent.permanentRT = new RenderTexture(width, height, 0, RenderTextureFormat.Default);
                    parent.permanentRT.Create();
                }

                int tempBlurID = Shader.PropertyToID("_TempBlurRT");
                cmd.GetTemporaryRT(tempBlurID, width, height, 0, FilterMode.Bilinear);

                // Capture current frame → freezeRT
                cmd.Blit(cameraColorTarget, parent.freezeRT);

                // Apply blur once → freezeRT
                cmd.Blit(parent.freezeRT, tempBlurID, parent.settings.blurMaterial);
                cmd.Blit(tempBlurID, parent.freezeRT);

                cmd.ReleaseTemporaryRT(tempBlurID);

                // Copy blurred result to permanentRT
                cmd.Blit(parent.freezeRT, parent.permanentRT);

                // Draw blurred frame immediately this frame
                cmd.Blit(parent.permanentRT, cameraColorTarget);

                parent.freezeRequested = false;
                parent.freezeActive = true;
                parent.freezeTimer = parent.settings.freezeDuration;

                Debug.Log("Freeze: Captured and blurred.");
            }
            else if (parent.freezeActive)
            {
                parent.freezeTimer -= Time.deltaTime;
                if (parent.freezeTimer <= 0f)
                {
                    parent.freezeActive = false;
                    Debug.Log("Freeze: Finished.");
                }
                else
                {
                    // Output permanentRT instead of re-rendering main camera
                    cmd.Blit(parent.permanentRT, cameraColorTarget);
                }
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (freezeRT != null)
        {
            freezeRT.Release();
            freezeRT = null;
        }
        if (permanentRT != null)
        {
            permanentRT.Release();
            permanentRT = null;
        }
    }
}
