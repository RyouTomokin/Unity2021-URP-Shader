#ifndef KIIF_Common_INCLUDED
#define KIIF_Common_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// 硬边带描边的溶解
inline half4 Dissipate(half dissipateSrc, half disspateIntensity, half disspateEdge, half3 disspateEdgeColor)
{
    half4 outColor;
    half dissipateFactor = step(disspateIntensity, dissipateSrc);
    half dissipateEdgeFactor = step(disspateIntensity - disspateEdge, dissipateSrc);
    outColor.a = dissipateEdgeFactor;

    #if defined(_ALPHATEST_ON)
    clip(dissipateEdgeFactor - 0.5h);
    #endif

    dissipateEdgeFactor -= dissipateFactor;
    outColor.rgb = dissipateEdgeFactor * disspateEdgeColor;
    return outColor;
}

// 不需要描边的硬边溶解
inline void Dissipate(half dissipateSrc, half disspateIntensity)
{
    Dissipate(dissipateSrc, disspateIntensity, 0, half3(0,0,0));
}

// 能完全溶解，溶解的开始和结束的边界做处理
inline half4 DissipateCompletely(half dissipateSrc, half disspateIntensity, half disspateEdge, half3 disspateEdgeColor)
{
    dissipateSrc = dissipateSrc * 0.98h + 0.01h;
    half fadeEdgeRange =  abs(disspateIntensity * 2 - 1);
    fadeEdgeRange = step(fadeEdgeRange, 0.98);      //当溶解强度小于0.01或大于0.99
    disspateEdge *= fadeEdgeRange;
    return Dissipate(dissipateSrc, disspateIntensity, disspateEdge, disspateEdgeColor);
}

// 不需要描边的硬边溶解
inline void DissipateCompletely(half dissipateSrc, half disspateIntensity)
{
    DissipateCompletely(dissipateSrc, disspateIntensity, 0, half3(0,0,0));
}

// 溶解混合(取消像素剔除)
inline half4 DissipateBlend(half dissipateSrc, half disspateIntensity, half disspateEdge, half3 disspateEdgeColor)
{
    half4 outColor;
    half dissipateFactor = step(disspateIntensity, dissipateSrc);
    half dissipateEdgeFactor = step(disspateIntensity - disspateEdge, dissipateSrc);
    outColor.a = dissipateEdgeFactor;

    dissipateEdgeFactor -= dissipateFactor;
    outColor.rgb = dissipateEdgeFactor * disspateEdgeColor;
    return outColor;
}

/**
 * \brief 软溶解
 * \param factor 溶解进度
 * \param dissolveSrc 采样的溶解图颜色
 * \param dissolveMask 溶解遮罩，黑色先溶解
 * \param sideWidth 溶解亮边宽度
 * \param sharpen 溶解的硬度
 * \return (溶解的范围，溶解亮边的范围)
 */
inline half2 Dissolve(half factor, half dissolveSrc, half dissolveMask = 0,
                      half sideWidth = 0, half sharpen = 1)
{
    half dissolve = dissolveSrc;
    // dissolve = (dissolve + dissolveMask - 1);            //溶解遮罩dissolve-(1-mask)
    dissolve = saturate(dissolve + dissolveMask - factor);  //溶解遮罩dissolve-(1-mask)
    dissolve = dissolve + 1 - (2 * factor);                 //溶解程度dissolve-2(factor-0.5)
    half dissolveSide = step(0, dissolve) - step(sideWidth, dissolve);
    dissolve = (dissolve - 0.5) * sharpen + 0.5;            //溶解边缘锐化
    dissolve = saturate(dissolve);

    return half2(dissolve, dissolveSide);
}

/**
 * \brief 用黑白贴图生成折射的效果，制作空气扰动等效果，返回扰动的UV
 * \param height 折射的强度，黑白贴图
 */
half2 RefractionOffset(half3 viewDirectionWS, half3 normalWS, half4 screenPosition, half height)
{
    half3 V = viewDirectionWS;
    half3 N = normalWS;
    half3 R = cross(N, V);
    half3 D = cross(R, V);
    half3 VR = cross(half3(0,1,0), V);
    half3 VU = normalize(cross(V, VR));
    VR = cross(VU, V);
    half2 offset = half2(dot(D, VR), -dot(D, VU)) * (screenPosition.xy);
    offset *= rcp(screenPosition.w) * height;
    return screenPosition.xy + offset;
}

// 折射 i:入射光线方向 n:表面法线 eta:折射相对系数(入射物质ior/折射物质ior)
// I和N之间的角度太大则返回(0, 0, 0)
// https://developer.download.nvidia.cn/cg/refract.html
float3 refract(float3 i, float3 n, float eta)
{
    float cosi = dot(-i, n);
    float cost2 = 1 - eta * eta * (1 - cosi * cosi);
    float3 t = eta * i + n * (eta * cosi - sqrt(abs(cost2)));
    return t * step(0, cost2);  // t * (float3)(cost2 > 0)
}

/**
 * \brief 数学推算的折射方法，更正确些也更耗
 * \param eta 折射相对系数(入射物质ior/折射物质ior)
 */
half2 RefractionEta(half3 viewDirWS, half3 normalWS, half eta)
{
    half3 refraction = refract(-viewDirWS, normalWS, eta);
    //  折射后的像素位置
    half3 refractionPositionWS = _WorldSpaceCameraPos.xyz + refraction;
    half4 refractionPositionCS = TransformWorldToHClip(refractionPositionWS);
    half4 refractionUV = ComputeScreenPos(refractionPositionCS) / refractionPositionCS.w;
    return refractionUV.xy;
}

/**
 * \brief
 * \param In 输入值
 * \param Contrast 对比度,0为原本效果
 * \return 输出值
 */
half CheapContrast(half In, half Contrast)
{
    half temp = lerp(0 - Contrast, 1 + Contrast, In);
    return clamp(temp, 0.0f, 1.0f);
}

//BumpOffset配套参数的计算
// half3x3 TangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
// // half3 cameraDirection =  -1 * mul((float3x3)UNITY_MATRIX_M, transpose(mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V)) [2].xyz);
// half3 cameraVector = normalize(_WorldSpaceCameraPos - input.positionWS);
/**
 * \brief UV随着视角偏移，模拟深度
 * \param tangentToWorld 切线空间转世界空间的矩阵
 * \param cameraDir 摄像机的方向(也可以是摄像机到像素的方向)
 * \param uv 原UV
 * \param height 偏移高度，默认0.5(参考平面)不偏移
 * \param heightRatio 偏移高度的系数
 * \param plane 参考平面
 * \return 偏移后的UV
 */
float2 BumpOffset(float3x3 tangentToWorld, float3 cameraDir, float2 uv, float height, float heightRatio = 0.05, float plane = 0.5)
{
    float _H = heightRatio * (height - plane);
    float3 viewTS = mul(tangentToWorld, cameraDir);
    float2 bumpUV = uv + viewTS.rg * _H;

    return bumpUV;
}

/**
 * \brief ASE的Flow节点
 * \param tex 被Flow的纹理
 * \param sampler Base采样器
 * \param UV BaseUV
 * \param FlowDirection Flow的方向 FlowMap
 * \param FlowStrength Flow强度
 * \param FlowSpeed Flow的时间速度
 * \return
 */
half4 Flow(TEXTURE2D_PARAM(tex, samp), float2 UV, float2 FlowDirection, float2 FlowStrength = float2(1,1), float FlowSpeed = 0.2)
{
    float time = _Time.y * FlowSpeed;
    float2 flowDir = -(FlowDirection * 2 - 1) * FlowStrength;
    float2 UV1 = UV + flowDir * frac(time);
    float2 UV2 = UV + flowDir * frac(time+0.5);
    half4 map1 = SAMPLE_TEXTURE2D(tex, samp, UV1);
    half4 map2 = SAMPLE_TEXTURE2D(tex, samp, UV2);

    return lerp(map1, map2, abs(frac(time) - 0.5) * 2);
}

/**
 * \brief ASE的PolarCoordinates节点
 * \param UV 原始UV
 * \param Center 转为极坐标的中心
 * \param RadialScale 半径的缩放
 * \param LengthScale -1~1，顺时针从6点钟方向开始
 * \return 输出极坐标UV
 */
float2 PolarCoordinates(float2 UV, float2 Center = float2(0.5, 0.5), float RadialScale = 1, float LengthScale = 1)
{
    UV -= Center;
    // scale of distance value    radius = length(delta) * 2 * RadialScale
    float radius = length(UV) * 2 * RadialScale;
    // angle = atan2(delta.x, delta.y) * 1.0 / 6.28 * LengthScale
    float angle = atan2(UV.x, UV.y) * INV_TWO_PI * LengthScale;

    return float2(radius, angle);
}

#endif
