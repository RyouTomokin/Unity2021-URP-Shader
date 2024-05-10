#ifndef KIIF_ShadowPass_INCLUDED
#define KIIF_ShadowPass_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
// #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
#include "Assets/Art/Shaders/Library/KIIFCommon.hlsl"

float3 _LightDirection;
float3 _LightPosition;

float _WorldPositionAdjust;
float _WorldPositionOffset;
float4 _DissolveMap_ST;
half _Dissipate;
half _DissipateEdgeSize;
half4 _DissipateEdgeColor;
TEXTURE2D(_DissolveMap);           SAMPLER(sampler_DissolveMap);

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 texcoord     : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv           : TEXCOORD0;
    float4 positionCS   : SV_POSITION;
    float3 positionWS   : TEXCOORD2;
};

float4 GetShadowPositionHClip(Attributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
    #else
    float3 lightDirectionWS = _LightDirection;
    #endif

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

    #if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif

    return positionCS;
}

Varyings DissipateShadowPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
    output.positionCS = GetShadowPositionHClip(input);
    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    return output;
}
half4 DissipateShadowPassFragment(Varyings input) : SV_TARGET
{
    float3 worldPosition = input.positionWS;
    float4 objectPosition = UNITY_MATRIX_M._14_24_34_44;
    half dissolveMask = (worldPosition.y - objectPosition.y + _WorldPositionOffset) * _WorldPositionAdjust;
    dissolveMask *= rcp(length(UNITY_MATRIX_M._12_22_32));

    half2 dissipateUV = TRANSFORM_TEX(input.uv, _DissolveMap);
    half dissipateSrc = SAMPLE_TEXTURE2D(_DissolveMap, sampler_DissolveMap, dissipateUV).r;
    dissipateSrc = saturate(dissipateSrc + dissolveMask - _Dissipate);
    DissipateCompletely(dissipateSrc, _Dissipate, _DissipateEdgeSize, _DissipateEdgeColor.rgb);
    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    
    return 0;
}

#endif
