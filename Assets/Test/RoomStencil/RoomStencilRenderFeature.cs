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
    }
    
    public override void Create()
    {
        this.name = "RoomStencil";
        _roomStencilPass = new RoomStencilPass(settings.renderPassEvent, settings.shader);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        _roomStencilPass.Setup(renderer.cameraColorTarget);
        renderer.EnqueuePass(_roomStencilPass);
    }
}

public class RoomStencilPass : ScriptableRenderPass
{
    private static readonly string RenderTag = "RoomStencil";
    private static readonly int MainTexId = Shader.PropertyToID("_MainTex");
    // 设置存储图像信息
    static readonly int TempTargetId = Shader.PropertyToID("_StencilMask");
    private int[] downSampleRT;
    private int[] upSampleRT;

    private RoomStencilVolume _roomStencilVolume;       //传递到volume
    private Material _postProcessMat;                   //后处理使用材质

    private RenderTargetIdentifier _currentTarget;      //设置当前渲染目标

    #region 设置渲染事件
    public RoomStencilPass(RenderPassEvent evt, Shader postProcessShader)
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

    #region 执行

    //必须重载一个名为Execute的方法，该方法便是逻辑执行的地方
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
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
        int destination = TempTargetId;
        int tmpSceneColor = Shader.PropertyToID("tmpSceneColor");
        _postProcessMat.SetInt("_RefValue", _roomStencilVolume.StencilRefValue.value);
        _postProcessMat.SetFloat("_BlurRange", _roomStencilVolume.blurSpread.value);

        
        cmd.GetTemporaryRT(destination, camera.scaledPixelWidth, camera.scaledPixelHeight);
        cmd.GetTemporaryRT(tmpSceneColor, camera.scaledPixelWidth, camera.scaledPixelHeight);
        cmd.Blit(source, tmpSceneColor);
        
        //在Stencil区域绘制
        
        //cmd.ClearRenderTarget(true,true,Color.black);
        cmd.Blit(destination,source, _postProcessMat, 4);
        //cmd.SetRenderTarget(destination);
        cmd.Blit(destination,source, _postProcessMat, 0);
        
        
        //降采样升采样去模糊处理
        RenderTargetIdentifier tmpRT = source;
        int width = camera.scaledPixelWidth;
        int height = camera.scaledPixelHeight;
        int iteration = _roomStencilVolume.BlurIterations.value;
        int preDownSample = _roomStencilVolume.preDownSample.value;
        downSampleRT = new int[iteration];
        upSampleRT = new int[iteration];

        //声明需要使用的RT的ID
        for (int i = 0; i < iteration; i++)
        {
            downSampleRT[i] = Shader.PropertyToID("DownSample" + i);
            upSampleRT[i] = Shader.PropertyToID("UpSample" + i);
        }

        width /= preDownSample;
        height /= preDownSample;
        //降采样
        for (int i = 0; i < iteration; i++)
        {
            width = Mathf.Max(width / 2, 1);
            height = Mathf.Max(height / 2, 1);
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
        cmd.ReleaseTemporaryRT(destination);
    }
    #endregion
}
