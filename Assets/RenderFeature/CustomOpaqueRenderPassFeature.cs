using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CustomOpaqueRenderPassFeature : ScriptableRendererFeature
{
    public Settings settings = new Settings();
    
    [System.Serializable]
    public class Settings
    {
        //设置渲染顺序
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
    }
    /// <summary>
    /// 自定义可编程的RenderPass
    /// </summary>
    class DesaturateStencilRenderPass : ScriptableRenderPass
    {
        private static readonly string RenderTag = "CustomOpaque";
        private RenderTargetIdentifier _currentTarget;      //设置当前渲染目标
        
        #region 设置渲染事件
        public DesaturateStencilRenderPass(RenderPassEvent evt)
        {
            renderPassEvent = evt;
        }
        #endregion
        
        #region 初始化
        public void Setup(in RenderTargetIdentifier currentTarget)
        {
            this._currentTarget = currentTarget;
        }
        #endregion
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        #region 执行
        
        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(RenderTag);       //设置渲染标签
            Render(cmd, ref renderingData);                                     //设置渲染函数
            context.ExecuteCommandBuffer(cmd);                                  //执行函数
            CommandBufferPool.Release(cmd);                                     //释放
        }
        
        #endregion
        
        #region 渲染

        void Render(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ref var cameraData = ref renderingData.cameraData;
            var camera = cameraData.camera;
            
            var source = _currentTarget;

            //暂存当前的颜色并传递给
            int tmpSceneColor = Shader.PropertyToID("CustomOpaqueTexture");
            RenderTextureDescriptor desc = cameraData.cameraTargetDescriptor;
            cmd.GetTemporaryRT(tmpSceneColor, desc);
            cmd.Blit(source, tmpSceneColor);
            cmd.SetGlobalTexture("_CameraOpaqueTexture", tmpSceneColor);
            
            cmd.ReleaseTemporaryRT(tmpSceneColor);
            // 修改回渲染目标
            cmd.SetRenderTarget(cameraData.renderer.cameraColorTarget, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store,
                cameraData.renderer.cameraDepthTarget, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);

        }

        #endregion
        
        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    DesaturateStencilRenderPass m_ScriptablePass;
    /// <inheritdoc/>
    public override void Create()
    {
        // this.name = "CustomOpaque";
        m_ScriptablePass = new DesaturateStencilRenderPass(settings.renderPassEvent);
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //此效果只对Scene场景和带MainCamera标签的相机起作用
        if (renderingData.cameraData.cameraType != CameraType.SceneView &&
            !renderingData.cameraData.camera.CompareTag("MainCamera"))
        {
            return;
        }
        m_ScriptablePass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


