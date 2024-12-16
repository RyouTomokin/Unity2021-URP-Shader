#ifndef KIIF_SecondaryFunction_INCLUDED
#define KIIF_SecondaryFunction_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Assets/Art/Shaders/Library/KIIFPBR.hlsl"

half4 _SecondaryColor;
float4 _SecondaryMap_ST;
half _SecondaryBumpScale;
float4 _NoiseMap_ST;
half _NoiseStrength;
half _NoiseContrast;

TEXTURE2D(_SecondaryMap);        SAMPLER(sampler_SecondaryMap);
TEXTURE2D(_SecondaryBumpMap);    SAMPLER(sampler_SecondaryBumpMap);
TEXTURE2D(_SecondarySMAEMap);    SAMPLER(sampler_SecondarySMAEMap);
TEXTURE2D(_NoiseMap);            SAMPLER(sampler_NoiseMap);

inline void PBR_Secondary_Initialize(Varyings input, out PBRData out_data, float2 suv)
{
    out_data = (PBRData)0;
    float2 uv = input.uv;

    // 噪波范围
    half Factor = 1;
    #ifdef _SECONDARY_ON
    #ifdef _NOISEMAP
    float2 noiseUV = TRANSFORM_TEX(suv, _NoiseMap);
    Factor = 1 - SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, noiseUV).r;
    #endif
    Factor = saturate(Factor + _NoiseStrength);
    Factor = smoothstep(_NoiseContrast, 1-_NoiseContrast, Factor);
    #endif
    
    out_data.albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
    out_data.albedo = out_data.albedoAlpha.rgb * _BaseColor.rgb;
    out_data.alpha = out_data.albedoAlpha.a * _BaseColor.a;

    // 细节颜色
    #ifdef _SECONDARY_ON
    suv = TRANSFORM_TEX(suv, _SecondaryMap);
    half4 sColor = half4(1,1,1,1);
    #ifdef _SECONDARY_COLORMAP
    sColor = SAMPLE_TEXTURE2D(_SecondaryMap, sampler_SecondaryMap, suv);
    #endif
    
    out_data.albedoAlpha = lerp(out_data.albedoAlpha, sColor, Factor);
    sColor *= _SecondaryColor;
    out_data.albedo = lerp(out_data.albedo.rgb, sColor.rgb, Factor);
    out_data.alpha = lerp(out_data.albedoAlpha.a, sColor.a, Factor);
    #endif
    
    #if defined(_ALPHATEST_ON)
    clip(out_data.alpha - _Cutoff);
    #endif

    #ifdef _SMAEMAP
    half4 SMAE = SAMPLE_TEXTURE2D(_SMAEMap, sampler_SMAEMap, uv);
    out_data.smoothness = SMAE.r * _Smoothness;
    out_data.metallic = SMAE.g * _Metallic;
    out_data.occlusion = lerp(1.0h, SMAE.b, _OcclusionStrength);
    out_data.emissionColor = _EmissionColor.rgb * SMAE.a * _EmissionStrength;
    // 细节金属度粗糙度
    #if defined(_SECONDARY_ON) && defined(_SECONDARY_SMAEMAP)
    half4 sSMA = SAMPLE_TEXTURE2D(_SecondarySMAEMap, sampler_SecondarySMAEMap, suv);
    out_data.smoothness = lerp(out_data.smoothness, sSMA.r, Factor);
    out_data.metallic = lerp(out_data.metallic, sSMA.g, Factor);
    out_data.occlusion = lerp(out_data.occlusion, lerp(1.0h, sSMA.b, _OcclusionStrength), Factor);
    #endif
    out_data.emissionColor = lerp(out_data.emissionColor, 0, Factor);
    
    #else
    out_data.smoothness = _Smoothness;
    out_data.metallic = _Metallic;
    out_data.occlusion = 1.0h;
    out_data.emissionColor = lerp(_EmissionColor.rgb, 0, Factor);
    out_data.emissionColor *= _EmissionStrength;
    #endif
    
    out_data.positionWS = input.positionWS;

    #ifdef _NORMALMAP
    half4 normal = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv);
    half3 normalTS = UnpackNormalScale(normal, _BumpScale);
    half3 viewDirWS = half3(input.normalWS.w, input.tangentWS.w, input.bitangentWS.w);
    out_data.TangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
    // 细节法线
    #if defined(_SECONDARY_ON) && defined(_SECONDARY_NORMALMAP)
    half4 sNormal = SAMPLE_TEXTURE2D(_SecondaryBumpMap, sampler_SecondaryBumpMap, suv);
    half3 sNormalTS = UnpackNormalScale(sNormal, _SecondaryBumpScale);
    normalTS = lerp(normalTS, sNormalTS, Factor);
    #endif
    
    out_data.normalWS = TransformTangentToWorld(normalTS, out_data.TangentToWorld);
    #else
    // half3 normalTS = half3(0.0h, 0.0h, 1.0h);
    half3 viewDirWS = input.viewDirWS;
    out_data.TangentToWorld = half3x3(half3(1,0,0),half3(0,1,0),half3(0,0,1));//不会被使用
    out_data.normalWS = input.normalWS;
    #endif

    out_data.normalWS.rgb = NormalizeNormalPerPixel(out_data.normalWS.rgb);
    out_data.viewDirectionWS = SafeNormalize(viewDirWS);
}

//因为在初始化后再采样第二套贴图，法线不是在切线空间下混合，效果不太正确，且两次空间的转换也很耗
//所以重写了初始化函数，直接在初始化时去采样第二套贴图
inline void SecondaryFunction(half2 uv, half3x3 tangentToWorld,
    inout half3 albedo, inout half smoothness, inout half metallic, inout half3 normalWS)
{
    #ifdef _SECONDARY_ON
    float2 UV = TRANSFORM_TEX(uv, _SecondaryMap);
    // 噪波范围
    half Factor = 1;
    #ifdef _NOISEMAP
    float2 noiseUV = TRANSFORM_TEX(uv, _NoiseMap);
    Factor = 1 - SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, noiseUV).r;
    #endif
    Factor = saturate(Factor + _NoiseStrength);
    Factor = smoothstep(_NoiseContrast, 1-_NoiseContrast, Factor);
    // 颜色
    half4 Color = half4(1,1,1,1);
    #ifdef _SECONDARY_COLORMAP
    Color = SAMPLE_TEXTURE2D(_SecondaryMap, sampler_SecondaryMap, UV);
    #endif
    Color *= _SecondaryColor;
    albedo = lerp(albedo, Color.rgb, Factor);
    // 法线
    #ifdef _SECONDARY_NORMALMAP
    half4 NormalMap = SAMPLE_TEXTURE2D(_SecondaryBumpMap, sampler_SecondaryBumpMap, UV);
    half3 NormalTS = UnpackNormalScale(NormalMap, _SecondaryBumpScale);
    half3 NormalWS = TransformTangentToWorld(NormalTS, tangentToWorld);
    normalWS = lerp(normalWS, NormalWS, Factor);
    #endif
    // 粗糙度金属度
    #ifdef _SECONDARY_SMAEMAP
    half4 SMAEMap = SAMPLE_TEXTURE2D(_SecondarySMAEMap, sampler_SecondarySMAEMap, UV);
    smoothness = lerp(smoothness, SMAEMap.r, Factor);
    metallic = lerp(metallic, SMAEMap.g, Factor);
    #endif
    
    #endif
}

#endif
