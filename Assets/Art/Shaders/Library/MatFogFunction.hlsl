#ifndef KIIF_MatFogFunction_INCLUDED
#define KIIF_MatFogFunction_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

half _FogStart;
half _FogEnd;
half4 _FogColor;

half _ColorSize;
half _ColorHeight;

half4 _NoiseMap_ST;
half _NoiseScale;
half _NoiseSize;

half _SpeedX;
half _SpeedY;

TEXTURE2D(_NoiseMap);            SAMPLER(sampler_NoiseMap);

inline void MatFogFunction(half3 positionWS, half4 positionCS, inout half4 color)
{
    #if _MATFOG_ON
    // 读取深度图深度
    half3 worldPos = positionWS.xyz;
    half linearDepth = positionCS.w;

    // 像机射线（LinearEye空间下）
    half3 interpolatedRay = (worldPos - _WorldSpaceCameraPos) / linearDepth;

    // 噪波图Y轴高度（LinearEye空间下）= 噪波图Y轴高度 / 像机射线Y轴高度，由上一行代码推出
    half noiseDepth = (_FogEnd - max(_WorldSpaceCameraPos.y, _FogEnd)) / interpolatedRay.y;

    // 噪波图uv
    // noiseDepth * interpolatedRay.xz 是在noiseDepth高度下的uv绽放
    // _WorldSpaceCameraPos.xz 是摄像机的移动偏移
    half2 noise_uv = _WorldSpaceCameraPos.xz + noiseDepth * interpolatedRay.xz;

    // 进行缩放与偏移（单纯的绽放操作）
    noise_uv = noise_uv / _NoiseSize + _Time.y * half2(_SpeedX, _SpeedY);

    // 对高度雾添加噪声处理
    half4 NoiseColor = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, noise_uv);
    worldPos.y = max(worldPos.y, _FogStart);
    worldPos.y += NoiseColor.r * _NoiseScale;

    // 颜色强度
    half fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart);
    fogDensity = saturate(fogDensity);

    // 颜色图uv（原理同噪波图uv）
    half2 color_uv = _WorldSpaceCameraPos.xz + (noiseDepth - _ColorHeight) * interpolatedRay.xz;

    // 进行缩放与偏移
    color_uv = color_uv / _ColorSize + _Time.y * half2(_SpeedX, _SpeedY) * 0.2;

    half4 fogColor = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, color_uv) * _FogColor;
    color.rgb = lerp(color.rgb, fogColor.rgb, fogDensity);
    #endif
}

#endif
