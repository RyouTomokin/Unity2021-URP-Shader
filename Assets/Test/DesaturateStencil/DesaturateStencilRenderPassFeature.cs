using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DesaturateStencilRenderPassFeature : ScriptableRendererFeature
{
    public Settings settings = new Settings();
    
    [System.Serializable]
    public class Settings
    {
        //设置渲染顺序
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
        public Shader shader;
        // public bool desaturateOpaque = false;
    }
    /// <summary>
    /// 自定义可编程的RenderPass
    /// </summary>
    class DesaturateStencilRenderPass : ScriptableRenderPass
    {
        private static readonly string RenderTag = "DesaturateStencil";
        
        private static readonly int BlurBufferID = Shader.PropertyToID("_BlurBuffer");
        
        // private int[] downSampleRT;
        // private int[] upSampleRT;
        
        private DesaturateStencilVolume _postProcessVolume; //后处理的Volume
        
        private Material _postProcessMat;                   //后处理使用材质
        private RenderTargetIdentifier _currentTarget;      //设置当前渲染目标
        
        private bool _desaturateOpaque;
        
        #region 设置渲染事件
        public DesaturateStencilRenderPass(RenderPassEvent evt, Shader postProcessShader, Settings settings)
        {
            renderPassEvent = evt;
            var shader = postProcessShader;
            //判断shader是否为空
            if (shader == null)
            {
                Debug.LogError("没有指定Shader");
                return;
            }
            //如果存在则新建材质
            _postProcessMat = CoreUtils.CreateEngineMaterial(postProcessShader);

            _desaturateOpaque = evt == RenderPassEvent.BeforeRenderingTransparents;

            // _desaturateOpaque = settings.desaturateOpaque;
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
            if (_postProcessMat == null)
            {
                Debug.LogError("材质初始化失败");
                return;
            }
            
            //传入volume
            var stack = VolumeManager.instance.stack;
            //获取我们的volume
            _postProcessVolume = stack.GetComponent<DesaturateStencilVolume>();
            if (_postProcessVolume == null)
            {
                Debug.LogError("Volume组件获取失败");
                return;
            }
            //判断Volume是否开启
            if (!_postProcessVolume.IsActive())
            {
                return;
            }
            
            var cmd = CommandBufferPool.Get(RenderTag);       //设置渲染标签
            Render(cmd, ref renderingData);                                     //设置渲染函数
            context.ExecuteCommandBuffer(cmd);                                  //执行函数
            CommandBufferPool.Release(cmd);                                     //释放
        }
        
        #endregion
        
        #region 渲染

        void Render(CommandBuffer cmd, ref RenderingData renderingData)
        {
            //从Volume获取参数并设置到材质中
            _postProcessMat.SetInt("_RefValue", _postProcessVolume.stencilRefValue.value);
            _postProcessMat.SetFloat("_Desaturate", _postProcessVolume.desaturate.value);
            _postProcessMat.SetInt("_StencilComp", (int)_postProcessVolume.stencilCompare.value);
            
            ref var cameraData = ref renderingData.cameraData;
            var camera = cameraData.camera;
            
            var source = _currentTarget;

            if (!_desaturateOpaque)
            {
                //暂存当前的颜色并传递给
                int tmpSceneColor = Shader.PropertyToID("tmpSceneColor_desaturate");
                RenderTextureDescriptor desc = cameraData.cameraTargetDescriptor;
                cmd.GetTemporaryRT(tmpSceneColor, desc);
                cmd.Blit(source, tmpSceneColor);
                cmd.SetGlobalTexture("_CameraTransparentTexture", tmpSceneColor);
                
                cmd.Blit(null, source, _postProcessMat, 0);
                
                cmd.ReleaseTemporaryRT(tmpSceneColor);
            }
            else
            {
                cmd.SetRenderTarget(_currentTarget);
                cmd.Blit(null, source, _postProcessMat, 1);
                // cmd.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
                // cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, _postProcessMat, 0, 1);
                // cmd.SetViewProjectionMatrices(camera.worldToCameraMatrix, camera.projectionMatrix);
            }
            
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
        this.name = "DesaturateStencil";
        m_ScriptablePass = new DesaturateStencilRenderPass(settings.renderPassEvent, settings.shader, settings);
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


