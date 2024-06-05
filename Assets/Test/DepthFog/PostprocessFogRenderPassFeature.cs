using System;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PostprocessFogRenderPassFeature : ScriptableRendererFeature
{
    public Settings settings = new Settings();
    
    [System.Serializable]
    public class Settings
    {
        //设置渲染顺序
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
        public Material materia;
    }
    /// <summary>
    /// 自定义可编程的RenderPass
    /// </summary>
    class PostprocessFogRenderPass : ScriptableRenderPass
    {
        private static readonly string RenderTag = "PostprocessFog";

        // private PostprocessFogVolume _postProcessVolume; //后处理的Volume
        
        private Material _postProcessMat;                   //后处理使用材质
        private RenderTargetIdentifier _currentTarget;      //设置当前渲染目标
        
        private bool _desaturateOpaque;
        
        #region 设置渲染事件
        public PostprocessFogRenderPass(RenderPassEvent evt, Material postProcessMaterial, Settings settings)
        {
            renderPassEvent = evt;
            var material = postProcessMaterial;
            if (material == null)
            {
                Debug.LogError("没有指定后处理雾材质");
                return;
            }
            _postProcessMat = postProcessMaterial;
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
            
            var cmd = CommandBufferPool.Get(RenderTag);       //设置渲染标签
            Render(cmd, ref renderingData);                                     //设置渲染函数
            context.ExecuteCommandBuffer(cmd);                                  //执行函数
            CommandBufferPool.Release(cmd);                                     //释放
        }
        
        #endregion
        
        #region 渲染

        void Render(CommandBuffer cmd, ref RenderingData renderingData)
        {
            // //从Volume获取参数并设置到材质中
            // _postProcessMat.SetInt("_RefValue", _postProcessVolume.stencilRefValue.value);
            // _postProcessMat.SetFloat("_Desaturate", _postProcessVolume.desaturate.value);
            // _postProcessMat.SetInt("_StencilComp", (int)_postProcessVolume.stencilCompare.value);
            
            ref var cameraData = ref renderingData.cameraData;
            var camera = cameraData.camera;
            Matrix4x4 M_V = camera.cameraToWorldMatrix;
            // Vector4 cameraWP = new Vector4(M_V.m30,M_V.m31,M_V.m32,M_V.m33);
            Vector4 cameraWP = new Vector4(M_V.m03,M_V.m13,M_V.m23,M_V.m33);
            // Debug.Log(cameraWP);
            
            _postProcessMat.SetVector("_CameraPositionWS", cameraWP);
            
            // cmd.SetViewProjectionMatrices(camera.worldToCameraMatrix, camera.projectionMatrix);
            cmd.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, _postProcessMat, 0, 0);
            // cmd.Blit(null, _currentTarget, _postProcessMat, 0);
            cmd.SetViewProjectionMatrices(camera.worldToCameraMatrix, camera.projectionMatrix);
        }

        #endregion
        
        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    PostprocessFogRenderPass m_ScriptablePass;
    /// <inheritdoc/>
    public override void Create()
    {
        this.name = "PostprocessFog";
        m_ScriptablePass = new PostprocessFogRenderPass(settings.renderPassEvent, settings.materia, settings);
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


