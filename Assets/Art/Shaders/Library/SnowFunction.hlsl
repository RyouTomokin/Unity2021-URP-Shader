#ifndef KIIF_SnowFunction_INCLUDED
#define KIIF_SnowFunction_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

float4 _SnowMap_ST;
half4 _SnowColor;
half _SnowIntensity;
half _SnowRange_Alpha;
half _SnowRange;
half _SnowPower;
half _SnowSmoothness;
half _SnowMetallic;

TEXTURE2D(_SnowMap);            SAMPLER(sampler_SnowMap);
TEXTURE2D(_SnowNormalMap);      SAMPLER(sampler_SnowNormalMap);

inline void SnowFunction(half alpha, float2 uv, half3x3 tangentToWorld,
    inout half3 albedo, inout half smoothness, inout half metallic, inout half3 normalWS)
{
    #if _SNOW_ON
                
    #if _SNOWRANGE_ALBEDO_CHANNEL_A
    half snowFactor = saturate((alpha + _SnowRange) * _SnowIntensity);
    #else
    // half NdotUP = saturate(dot(lerp(input.normalWS , normalWS, _SnowRange), half3(0, 1, 0)));    //法线细节
    half NdotUP = saturate(_SnowRange + dot(normalWS, half3(0, 1, 0)));
    half snowFactor = saturate(NdotUP * _SnowIntensity);
    #endif
                
    snowFactor = pow(snowFactor, _SnowPower);
                
    float2 snowUV = TRANSFORM_TEX(uv, _SnowMap);
                
    #ifdef _SNOWMAP
    half4 snowColorMap = SAMPLE_TEXTURE2D(_SnowMap, sampler_SnowMap, snowUV) * _SnowColor;
    #else
    half4 snowColorMap = _SnowColor;
    #endif

    #ifdef _SNOWNORMALMAP
    half4 snowNormalMap = SAMPLE_TEXTURE2D(_SnowNormalMap, sampler_SnowNormalMap, snowUV);
    half3 snowNormalTS = UnpackNormalScale(snowNormalMap, 1);
    half3 snowNormalWS = TransformTangentToWorld(snowNormalTS, tangentToWorld);
    normalWS = lerp(normalWS, snowNormalWS, snowFactor);
    #endif
                
    albedo = lerp(albedo, snowColorMap.rgb, snowFactor);
    smoothness = lerp(smoothness, _SnowSmoothness, snowFactor);
    metallic = lerp(metallic, _SnowMetallic, snowFactor);
    #endif
}

#endif
