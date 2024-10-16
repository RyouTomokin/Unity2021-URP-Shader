#ifndef KIIF_PBR_INCLUDED
#define KIIF_PBR_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float4 tangentOS    : TANGENT;
    float2 texcoord     : TEXCOORD0;
    float2 lightmapUV   : TEXCOORD1;
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
half _BumpScale;
half _Smoothness;
half _Metallic;
half _OcclusionStrength;
half4 _EmissionColor;
half _EmissionStrength;            
CBUFFER_END

TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
TEXTURE2D(_BumpMap);            SAMPLER(sampler_BumpMap);
TEXTURE2D(_SMAEMap);            SAMPLER(sampler_SMAEMap);

Varyings vert(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

    output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

    #ifdef _NORMALMAP
    output.normalWS = half4(normalInput.normalWS, viewDirWS.x);
    output.tangentWS = half4(normalInput.tangentWS, viewDirWS.y);
    output.bitangentWS = half4(normalInput.bitangentWS, viewDirWS.z);
    #else
    output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
    output.viewDirWS = viewDirWS;
    #endif

    OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

    output.positionWS = vertexInput.positionWS;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.positionCS = vertexInput.positionCS;

    #ifdef _SCREENPOSITION_ON
    // output.screenPos = ComputeScreenPos(output.positionCS)/output.positionCS.w; 
    output.screenPos = vertexInput.positionNDC/output.positionCS.w; 
    #endif
    
    return output;
}

struct PBRData
{
    half  alpha;
    half4  albedoAlpha;
    half3 albedo;
    half  smoothness;
    half  metallic;
    half  occlusion;
    half3 emissionColor;
    float3 positionWS;
    half3 normalWS;
    half3 viewDirectionWS;
    half3x3 TangentToWorld;
};

inline void PBRInitialize(Varyings input, out PBRData out_data)
{
    out_data = (PBRData)0;
    float2 uv = input.uv;
    out_data.albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
    out_data.alpha = out_data.albedoAlpha.a * _BaseColor.a;
    #if defined(_ALPHATEST_ON)
    clip(out_data.alpha - _Cutoff);
    #endif
    out_data.albedo = out_data.albedoAlpha.rgb * _BaseColor.rgb;

    #ifdef _SMAEMAP
    half4 SMAE = SAMPLE_TEXTURE2D(_SMAEMap, sampler_SMAEMap, uv);
    out_data.smoothness = SMAE.r * _Smoothness;
    out_data.metallic = SMAE.g * _Metallic;
    out_data.occlusion = lerp(1.0h, SMAE.b, _OcclusionStrength);
    out_data.emissionColor = _EmissionColor.rgb * SMAE.a * _EmissionStrength;
    #else
    out_data.smoothness = _Smoothness;
    out_data.metallic = _Metallic;
    out_data.occlusion = 1.0h;
    out_data.emissionColor = _EmissionColor.rgb * _EmissionStrength;
    #endif
    
    out_data.positionWS = input.positionWS;

    #ifdef _NORMALMAP
    half4 normal = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv);
    half3 normalTS = UnpackNormalScale(normal, _BumpScale);
    half3 viewDirWS = half3(input.normalWS.w, input.tangentWS.w, input.bitangentWS.w);
    out_data.TangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
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

// 因为整个项目的光照是统一的，不需要有差异的，所以封装方便统一修改
inline half4 GetDirectLightColor(Light mainLight, BRDFData brdfData, PBRData pbrData)
{
    half3 directLightColor = LightingPhysicallyBased(brdfData, mainLight, pbrData.normalWS, pbrData.viewDirectionWS);
    half3 maxIntensity = max(half3(1,1,1) * 8.0h, mainLight.color);
    half4 color = half4(clamp(directLightColor, 0, maxIntensity), pbrData.alpha);
                
    return color;
}

inline half3 GetAdditionalLightColor(BRDFData brdfData, PBRData pbrData)
{
    half3 additionColor = half3(0,0,0);
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint i = 0u; i < pixelLightCount; ++i)
    {
        // Light light = GetAdditionalLight(lightIndex, pbrData.positionWS, 1);
        #if USE_CLUSTERED_LIGHTING
        int lightIndex = i;
        #else
        int lightIndex = GetPerObjectLightIndex(i);
        Light light = GetAdditionalPerObjectLight(lightIndex, pbrData.positionWS);
        #endif
        //只获取实时点光源阴影
        light.shadowAttenuation = AdditionalLightRealtimeShadow(lightIndex, pbrData.positionWS, light.direction);
        additionColor += LightingPhysicallyBased(brdfData, light, pbrData.normalWS, pbrData.viewDirectionWS);
    }           
    return additionColor;
}

inline half3 GetAdditionalLightColorNPR(BRDFData brdfData, PBRData pbrData)
{
    half3 additionColor = half3(0,0,0);
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint i = 0u; i < pixelLightCount; ++i)
    {
        // Light light = GetAdditionalLight(lightIndex, pbrData.positionWS, 1);
        #if USE_CLUSTERED_LIGHTING
        int lightIndex = i;
        #else
        int lightIndex = GetPerObjectLightIndex(i);
        Light light = GetAdditionalPerObjectLight(lightIndex, pbrData.positionWS);
        //防止过曝对灯光强度进行限制
        //现在使用颜色为lerp的value，若使用颜色强度更能保留灯光的饱和度
        half3 lightColor = light.color;
        half3 additionNPRColor = lerp(lightColor, lightColor*0.5, smoothstep(2,10,lightColor));
        additionNPRColor = min(4.6, additionNPRColor);
        light.color = additionNPRColor;
        #endif
        //只获取实时点光源阴影
        light.shadowAttenuation = AdditionalLightRealtimeShadow(lightIndex, pbrData.positionWS, light.direction);
        additionColor += LightingPhysicallyBased(brdfData, light, pbrData.normalWS, pbrData.viewDirectionWS);
    }           
    return additionColor;
}

inline half3 GetGIColor(Varyings input, Light mainLight, BRDFData brdfData, PBRData pbrData)
{
    #if defined(LIGHTMAP_ON)
    half3 bakedGI = SAMPLE_GI(input.lightmapUV, input.lightmapUV, pbrData.normalWS);
    #else
    half3 bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, pbrData.normalWS);
    #endif
    // #if defined(LIGHTMAP_ON) && defined(_MIXED_LIGHTING_SUBTRACTIVE)
    // bakedGI = SubtractDirectMainLightFromLightmap(mainLight, pbrData.normalWS, bakedGI);    //MixRealtimeAndBakedGI

    half3 GIcolor = GlobalIllumination(brdfData, bakedGI, pbrData.occlusion, pbrData.normalWS, pbrData.viewDirectionWS);

    return GIcolor;
}

inline half3 GetGIColorNPR(Varyings input, Light mainLight, BRDFData brdfData, PBRData pbrData)
{
    #if defined(LIGHTMAP_ON)
    half3 bakedGI = SAMPLE_GI(input.lightmapUV, input.lightmapUV, pbrData.normalWS);
    #else
    half3 bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, pbrData.normalWS);
    #endif
    // #if defined(LIGHTMAP_ON) && defined(_MIXED_LIGHTING_SUBTRACTIVE)
    // bakedGI = SubtractDirectMainLightFromLightmap(mainLight, pbrData.normalWS, bakedGI);    //MixRealtimeAndBakedGI

    half3 GIcolor = GlobalIllumination(brdfData, bakedGI, pbrData.occlusion, pbrData.normalWS, pbrData.viewDirectionWS);
    //控制角色受环境光色相影响的程度
    GIcolor = lerp(brdfData.diffuse * Desaturate(bakedGI,0.0), GIcolor, 0.3);

    return GIcolor;
}

#endif
