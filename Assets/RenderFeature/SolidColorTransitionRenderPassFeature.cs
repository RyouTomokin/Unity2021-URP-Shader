using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SolidColorTransitionRenderPassFeature : ScriptableRendererFeature
{
    public Settings settings = new Settings();
    public RenderSettings renderSettings = new RenderSettings();

    [System.Serializable]
    public class Settings
    {
        //设置渲染顺序
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
    }
    [System.Serializable]
    public class RenderSettings
    {
        public Material material;
        public Color transitionColor = Color.black;
        [Range(0, 1)]
        public float levelTransition = 0;
    }
    /// <summary>
    /// 自定义可编程的RenderPass
    /// </summary>
    class DesaturateStencilRenderPass : ScriptableRenderPass
    {
        private static readonly string RenderTag = "SolidColorTransition";
        // private RenderTargetIdentifier _currentTarget;      //设置当前渲染目标
        private Material _postProcessMat;
        private Color _transitionColor;
        private float _levelTransition;
        
        #region 设置渲染事件
        public DesaturateStencilRenderPass(RenderSettings renderSettings, RenderPassEvent evt)
        {
            renderPassEvent = evt;
            _postProcessMat = renderSettings.material;
            _transitionColor = renderSettings.transitionColor;
            _levelTransition = renderSettings.levelTransition;
        }
        #endregion
        
        #region 初始化
        // public void Setup(in RenderTargetIdentifier currentTarget)
        public void Setup(ScriptableRenderer renderer,
            in RenderingData renderingData)
        {
            
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
            Camera camera = renderingData.cameraData.camera;
            Color color = _transitionColor;
            color.a *= _levelTransition;
            _postProcessMat.SetColor("_BaseColor", color);

            cmd.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, _postProcessMat, 0, 0);
            cmd.SetViewProjectionMatrices(camera.worldToCameraMatrix, camera.projectionMatrix);

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
        // this.name = "SolidColorTransition";
        m_ScriptablePass = new DesaturateStencilRenderPass(renderSettings ,settings.renderPassEvent);
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

        if (renderSettings.material != null)
        {
            renderer.EnqueuePass(m_ScriptablePass);
        }
        // m_ScriptablePass.Setup(renderer.cameraColorTarget);
        // m_ScriptablePass.Setup(renderer, renderingData);
    }
}


