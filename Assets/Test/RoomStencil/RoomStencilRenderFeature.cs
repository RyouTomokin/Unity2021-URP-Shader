using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
public class RoomStencilRenderFeature : ScriptableRendererFeature
{
    public Settings settings = new Settings();
    private RoomStencilPass _roomStencilPass;
    
    [System.Serializable]
    public class Settings
    {
        //设置渲染顺序
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
        public Shader shader;
        public bool cameraStackMode;
    }
    
    public override void Create()
    {
        this.name = "RoomStencil";
        _roomStencilPass = new RoomStencilPass(settings.renderPassEvent, settings.shader, settings.cameraStackMode);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //此效果只对Scene场景和带MainCamera标签的相机起作用
        if (renderingData.cameraData.cameraType != CameraType.SceneView &&
            !renderingData.cameraData.camera.CompareTag("MainCamera"))
        {
            return;
        }

        _roomStencilPass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(_roomStencilPass);
    }
}

public class RoomStencilPass : ScriptableRenderPass
{
    private static readonly string RenderTag = "RoomStencil";

    private int[] downSampleRT;
    private int[] upSampleRT;

    private RoomStencilVolume _roomStencilVolume;       //传递到volume
    private Material _postProcessMat;                   //后处理使用材质

    private RenderTargetIdentifier _currentTarget;      //设置当前渲染目标
    private bool _cameraStackMode;

    #region 设置渲染事件

    public RoomStencilPass(RenderPassEvent evt, Shader postProcessShader, bool mode)
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

        _cameraStackMode = mode;
    }

    #endregion

    #region 初始化

    public void Setup(in RenderTargetIdentifier currentTarget)
    {
        this._currentTarget = currentTarget;
    }

    #endregion

    #region 执行

    //必须重载一个名为Execute的方法，该方法便是逻辑执行的地方
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        //此效果只对Scene场景和带MainCamera标签的相机起作用
        if (renderingData.cameraData.cameraType != CameraType.SceneView &&
            !renderingData.cameraData.camera.CompareTag("MainCamera"))
        {
            return;
        }

        if (_postProcessMat == null)
        {
            Debug.LogError("材质初始化失败");
            return;
        }

        //摄像机是否开启后处理
        if (!renderingData.cameraData.postProcessEnabled)
        {
            return;
        }

        //传入volume
        var stack = VolumeManager.instance.stack;
        //获取我们的volume
        _roomStencilVolume = stack.GetComponent<RoomStencilVolume>();
        if (_roomStencilVolume == null)
        {
            Debug.LogError("Volume组件获取失败");
            return;
        }

        if (!_roomStencilVolume.IsActive())
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
        ref var cameraData = ref renderingData.cameraData;
        var camera = cameraData.camera;
        _postProcessMat.SetInt("_RefValue", _roomStencilVolume.stencilRefValue.value);
        _postProcessMat.SetFloat("_BlurRange", _roomStencilVolume.blurSpread.value);

        var source = _currentTarget;
        int tmpSceneColor = Shader.PropertyToID("tmpSceneColor_roomStencil");
        RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
        cmd.GetTemporaryRT(tmpSceneColor, desc);
        cmd.Blit(source, tmpSceneColor);
        cmd.SetRenderTarget(cameraData.renderer.cameraColorTarget, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store,
            cameraData.renderer.cameraDepthTarget, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        cmd.ClearRenderTarget(false, true, Color.clear);

        //获取Stencil遮罩，Scene视口和Game视口不一致
        if (cameraData.cameraType == CameraType.Game && _cameraStackMode)
        {
            //Blit不支持堆栈相机，深度缓冲区无法进入，使用DrawMesh的方式渲染
            cmd.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
            cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, _postProcessMat, 0, 0);
            cmd.SetViewProjectionMatrices(camera.worldToCameraMatrix, camera.projectionMatrix);
        }
        else
        {
            cmd.Blit(null, source, _postProcessMat, 0);
        }

        //降采样升采样去模糊处理
        RenderTargetIdentifier tmpRT = source;
        int width = camera.scaledPixelWidth;
        int height = camera.scaledPixelHeight;
        int iteration = _roomStencilVolume.blurIterations.value;
        int preDownSample = _roomStencilVolume.preDownSample.value;
        downSampleRT = new int[iteration];
        upSampleRT = new int[iteration];

        //声明需要使用的RT的ID
        for (int i = 0; i < iteration; i++)
        {
            downSampleRT[i] = Shader.PropertyToID("DownSample" + i);
            upSampleRT[i] = Shader.PropertyToID("UpSample" + i);
        }

        width  = width >> preDownSample;
        height = height >> preDownSample;
        //降采样
        for (int i = 0; i < iteration; i++)
        {
            width = Mathf.Max(width>>1, 1);
            height = Mathf.Max(height>>1, 1);
            cmd.GetTemporaryRT(downSampleRT[i], width, height, 0, FilterMode.Bilinear, RenderTextureFormat.Default);
            cmd.GetTemporaryRT(upSampleRT[i], width, height, 0, FilterMode.Bilinear, RenderTextureFormat.Default);

            cmd.Blit(tmpRT, downSampleRT[i], _postProcessMat, 1);
            tmpRT = downSampleRT[i];
        }
        //升采样
        for (int j = iteration - 2; j >= 0; j--)
        {
            cmd.Blit(tmpRT, upSampleRT[j], _postProcessMat, 2);
            tmpRT = upSampleRT[j];
        }
        
        
        //合并 释放
        cmd.SetGlobalTexture("_SourceTex", tmpSceneColor);
        cmd.Blit(tmpRT, source, _postProcessMat, 3);
        for (int i = 0; i < iteration; i++)
        {
            cmd.ReleaseTemporaryRT(downSampleRT[i]);
            cmd.ReleaseTemporaryRT(upSampleRT[i]);
        }

        cmd.ReleaseTemporaryRT(tmpSceneColor);
    }

    #endregion
}