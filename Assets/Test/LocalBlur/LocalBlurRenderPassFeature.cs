using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class LocalBlurRenderPassFeature : ScriptableRendererFeature
{
    public Settings settings = new Settings();
    
    [System.Serializable]
    public class Settings
    {
        //设置渲染顺序
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
        public Shader shader;
    }
    /// <summary>
    /// 自定义可编程的RenderPass
    /// </summary>
    class LocalBlurRenderPass : ScriptableRenderPass
    {
        private static readonly string RenderTag = "LocalBlur";
        
        private static readonly int BlurBufferID = Shader.PropertyToID("_BlurBuffer");
        
        private int[] downSampleRT;
        private int[] upSampleRT;
        
        private LocalBlurVolume _postProcessVolume;         //后处理的Volume
        
        private Material _postProcessMat;                   //后处理使用材质
        private RenderTargetIdentifier _currentTarget;      //设置当前渲染目标
        
        private float _BlurRange;
        private int _iteration;
        
        #region 设置渲染事件
        public LocalBlurRenderPass(RenderPassEvent evt, Shader postProcessShader)
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
            _postProcessVolume = stack.GetComponent<LocalBlurVolume>();
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
            _BlurRange = _postProcessVolume.blurRadius.value;
            _iteration = _postProcessVolume.iteration.value;
            _postProcessMat.SetFloat("_BlurRange", _BlurRange);
            
            ref var cameraData = ref renderingData.cameraData;
            var camera = cameraData.camera;
            
            // Blitter.BlitCameraTexture();
            cmd.SetRenderTarget(_currentTarget);
            // cmd.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
            // cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, _postProcessMat, 0, 0);
            // cmd.SetViewProjectionMatrices(camera.worldToCameraMatrix, camera.projectionMatrix);
            
            //降采样升采样去模糊处理
            RenderTargetIdentifier tmpRT = _currentTarget;
            int width = camera.scaledPixelWidth;
            int height = camera.scaledPixelHeight;
            // int preDownSample = _postProcessVolume.preDownSample.value;
            downSampleRT = new int[_iteration];
            upSampleRT = new int[_iteration];

            //声明需要使用的RT的ID
            for (int i = 0; i < _iteration; i++)
            {
                downSampleRT[i] = Shader.PropertyToID("DownSample" + i);
                upSampleRT[i] = Shader.PropertyToID("UpSample" + i);
            }

            // width  = width >> preDownSample;
            // height = height >> preDownSample;
            //降采样
            for (int i = 0; i < _iteration; i++)
            {
                width = Mathf.Max(width>>1, 1);
                height = Mathf.Max(height>>1, 1);
                cmd.GetTemporaryRT(downSampleRT[i], width, height, 0, FilterMode.Bilinear, RenderTextureFormat.Default);
                cmd.GetTemporaryRT(upSampleRT[i], width, height, 0, FilterMode.Bilinear, RenderTextureFormat.Default);

                cmd.Blit(tmpRT, downSampleRT[i], _postProcessMat, 0);
                tmpRT = downSampleRT[i];
            }
            //升采样
            for (int j = _iteration - 1; j >= 0; j--)
            {
                cmd.Blit(tmpRT, upSampleRT[j], _postProcessMat, 1);
                tmpRT = upSampleRT[j];
            }
            
            cmd.SetGlobalTexture(BlurBufferID, upSampleRT[0]);
            
            //释放TempRT
            for (int i = 0; i < _iteration; i++)
            {
                cmd.ReleaseTemporaryRT(downSampleRT[i]);
                cmd.ReleaseTemporaryRT(upSampleRT[i]);
            }
        }

        #endregion
        
        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    LocalBlurRenderPass m_ScriptablePass;
    /// <inheritdoc/>
    public override void Create()
    {
        this.name = "LocalBlur";
        m_ScriptablePass = new LocalBlurRenderPass(settings.renderPassEvent, settings.shader);
        // m_ScriptablePass = new LocalBlurRenderPass();
        //
        // // Configures where the render pass should be injected.
        // m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


