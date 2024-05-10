#ifndef KIIF_Decal_INCLUDED
#define KIIF_Decal_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    // float3 normalOS     : NORMAL;
    // float4 tangentOS    : TANGENT;
    // float2 texcoord     : TEXCOORD0;
    // float2 lightmapUV   : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv                       : TEXCOORD0;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

    float3 positionWS               : TEXCOORD2;

    #ifdef _NORMALMAP
    float4 normalWS                 : TEXCOORD3;    // xyz: normal, w: viewDir.x
    float4 tangentWS                : TEXCOORD4;    // xyz: tangent, w: viewDir.y
    float4 bitangentWS              : TEXCOORD5;    // xyz: bitangent, w: viewDir.z
    #else
    float3 normalWS                 : TEXCOORD3;
    float3 viewDirWS                : TEXCOORD4;
    #endif

    half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord              : TEXCOORD7;
    #endif
    #ifdef _SCREENPOSITION_ON
    float4 screenPos                : TEXCOORD8;
    #endif
    

    float4 positionCS               : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _BaseColor;
half _Cutoff;
half4 _EmissionColor;
half _EmissionStrength;
CBUFFER_END

TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);

Varyings vert_decal(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    output.positionWS = vertexInput.positionWS;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionCS = vertexInput.positionCS;

    #ifdef _SCREENPOSITION_ON
    output.screenPos = ComputeScreenPos(output.positionCS)/output.positionCS.w; 
    #endif
    
    return output;
}

struct PBRData
{
    half  alpha;
    half4  albedoAlpha;
    half3 albedo;
    half3 emissionColor;
    float3 positionWS;
};

inline void PBRInitialize(Varyings input, out PBRData out_data)
{
    out_data = (PBRData)0;
    float2 uv = input.uv;
    out_data.albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
    out_data.albedoAlpha *= _BaseColor;
    out_data.alpha = out_data.albedoAlpha.a;
    #if defined(_ALPHATEST_ON)
    clip(out_data.alpha - _Cutoff);
    #endif
    out_data.albedo = out_data.albedoAlpha.rgb;

    out_data.emissionColor = _EmissionColor.rgb * _EmissionStrength;
    out_data.positionWS = input.positionWS;
}

#endif
