#ifndef KIIF_MetaPass_INCLUDED
#define KIIF_MetaPass_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _BaseColor;
half4 _EmissionColor;
half _Cutoff;
half _Smoothness;
half _Metallic;
half _BumpScale;
half _EmissionStrength;
CBUFFER_END
TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
TEXTURE2D(_SMAEMap);            SAMPLER(sampler_SMAEMap);

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 uv0          : TEXCOORD0;
    float2 uv1          : TEXCOORD1;
    float2 uv2          : TEXCOORD2;
    #ifdef _TANGENT_TO_WORLD
    float4 tangentOS     : TANGENT;
    #endif
};

struct Varyings
{
    float4 positionCS   : SV_POSITION;
    float2 uv           : TEXCOORD0;
};

Varyings UniversalVertexMeta(Attributes input)
{
    Varyings output;
    output.positionCS = MetaVertexPosition(input.positionOS, input.uv1, input.uv2,
        unity_LightmapST, unity_DynamicLightmapST);
    output.uv = TRANSFORM_TEX(input.uv0, _BaseMap);
    return output;
}

half4 UniversalFragmentMeta(Varyings input) : SV_Target
{
    // -------------------------------------
    //采样 初始化
    float2 uv = input.uv;
    half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
    half alpha = albedoAlpha.a * _BaseColor.a;
    #if defined(_ALPHATEST_ON)
    clip(alpha - _Cutoff);
    #endif
    half3 albedo = albedoAlpha.rgb * _BaseColor.rgb;

    #ifdef _SMAEMAP
    half4 SMAE = SAMPLE_TEXTURE2D(_SMAEMap, sampler_SMAEMap, uv);
    half smoothness = SMAE.r * _Smoothness;
    half metallic = SMAE.g * _Metallic;
    half occlusion = lerp(1.0h, SMAE.b, 1);
    half3 emissionColor = _EmissionColor.rgb * SMAE.a * _EmissionStrength;
    #else
    half smoothness = _Smoothness;
    half metallic = _Metallic;
    half occlusion = 1.0h;
    half3 emissionColor = _EmissionColor.rgb * _EmissionStrength;
    #endif

    //初始化SurfaceData
    half oneMinusReflectivity = OneMinusReflectivityMetallic(metallic);
    half reflectivity = 1.0 - oneMinusReflectivity;

    half3 diffuse = albedo * oneMinusReflectivity;
    half3 specular = lerp(kDieletricSpec.rgb, albedo, metallic);
    half3 roughness = max((1-smoothness)*(1-smoothness), HALF_MIN);
    
    MetaInput metaInput;
    metaInput.Albedo = diffuse + specular * roughness * 0.5;
    // metaInput.SpecularColor = specular;
    metaInput.Emission = emissionColor;

    return MetaFragment(metaInput);
}

#endif
