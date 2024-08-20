Shader "KIIF/PBR_Water"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        _TwistStrength("TwistStrenght", Range(0, 1)) = 0.5
        _CausticsHeight("CausticsHeight", Range(-1, 1)) = 0
        _BumpScale("法线强度", Float) = 1.0
        [NoScaleOffset]_BumpMap("Normal Map", 2D) = "bump" {}
        _NormalScale("法线纹理尺寸", Float) = 1.0
        _NormalTiling1("NormalTiling01", Vector) = (1,1,0,0)
        _NormalTiling2("NormalTiling02", Vector) = (1,1,0,0)
        
        _Smoothness("光滑度", Range(0.0, 1.0)) = 0.5
        [Gamma] _Metallic("金属度", Range(0.0, 1.0)) = 0.0
        _OcclusionStrength("AO", Range(0.0, 1.0)) = 1.0
        
        [Space(20)]
        [Header(Water)]
        _EdgeFade("EdgeFade", Range(0, 5)) = 1
        [PowerSlider(2)]_WaterDepthRange("WaterDepthRange", Range(0, 20)) = 2
        _EdgeColor("EdgeColor", Color) = (1,1,1,1)
        _ColorBright("ColorBright", Color) = (0,0.5,0.6,0.2)
        _ColorDeep("ColorDeep", Color) = (0,0.2,0.3,1)
        
        _RefractionFade("RefractionFade", Float) = 100
        _RefractionIntensity("RefractionIntensity", Float) = 0.1
        
        [Space(20)]
        [Header(Stencil)]
        [Space]
        _RefValue("Ref Value",Int) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8      //默认Always
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep
        
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
//        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
        LOD 300
        //ForwardLit
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            Blend SrcAlpha OneMinusSrcAlpha
            Stencil
            {
                Ref [_RefValue]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }
            ZWrite On
            Cull[_Cull]
            
            HLSLPROGRAM

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            #include "Assets/Art/Shaders/Library/KIIFCommon.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 texcoord1    : TEXCOORD0;
                float2 texcoord2    : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 uv                       : TEXCOORD0;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

                float3 positionWS               : TEXCOORD2;
                float3 positionVS               : TEXCOORD6;

                float4 normalWS                 : TEXCOORD3;    // xyz: normal
                float4 tangentWS                : TEXCOORD4;    // xyz: tangent
                float4 bitangentWS              : TEXCOORD5;    // xyz: bitangent                

                float4 positionCS               : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            half _TwistStrength;
            half _CausticsHeight;
            
            half _BumpScale;
            half _NormalScale;
            float4 _NormalTiling1;
            float4 _NormalTiling2;


            half _RefractionFade;
            half _RefractionIntensity;
            float _EdgeFade;
            float _WaterDepthRange;
            half4 _EdgeColor;
            half4 _ColorBright;
            half4 _ColorDeep;

            half _Smoothness;
            half _Metallic;
            half _OcclusionStrength;
                        
            CBUFFER_END
            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);            SAMPLER(sampler_BumpMap);

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;

                output.uv = float4(input.texcoord1, input.texcoord2);

                output.normalWS = half4(normalInput.normalWS, viewDirWS.x);
                output.tangentWS = half4(normalInput.tangentWS, viewDirWS.y);
                output.bitangentWS = half4(normalInput.bitangentWS, viewDirWS.z);

                output.positionWS = vertexInput.positionWS;
                output.positionVS = vertexInput.positionVS;

                output.positionCS = vertexInput.positionCS;
                
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                // -------------------------------------
                //采样 初始化
                float2 uv2 = input.uv.zw;
                
                // float3 positionWS = input.positionWS;
                float3 normalWS = input.normalWS.xyz;
                //不公开的参数
                half sideFoamRange = 0.5;

                //法线混合
                _NormalTiling1 *= 0.001 * _NormalScale;
                _NormalTiling2 *= 0.001 * _NormalScale;
                float2 normalUV1 = input.uv.xy * _NormalTiling1.xy + _NormalTiling1.zw * _Time.y;
                float2 normalUV2 = input.uv.xy * _NormalTiling2.xy + _NormalTiling2.zw * _Time.y;
                half4 normal1 = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, normalUV1);
                half4 normal2 = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, normalUV2);
                half4 normal = lerp(normal1, normal2, 0.5);
                half3 normalTS = UnpackNormalScale(normal, _BumpScale);

                
                half3 viewDirWS = half3(input.normalWS.w, input.tangentWS.w, input.bitangentWS.w);
                half3x3 TangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
                normalWS = TransformTangentToWorld(normalTS, TangentToWorld);
                normalWS.rgb = NormalizeNormalPerPixel(normalWS.rgb);
                half3 viewDirectionWS = SafeNormalize(viewDirWS);
                

                // -------------------------------------
                float2 screenUV = input.positionCS.xy / _ScaledScreenParams.xy;
                float sceneRawDepth = SampleSceneDepth(screenUV);
                float sceneEyeDepth = LinearEyeDepth(sceneRawDepth, _ZBufferParams);
                
                //水体折射
                float refractionFade = saturate(sceneEyeDepth * rcp(_RefractionFade));    //sceneEyeDepth remap[0,_RefractionFade]->[0,1]
                refractionFade = 1 - refractionFade;
                half2 refractionIntensity = normalTS.xy * _RefractionIntensity;
                half2 refractionUV = screenUV + refractionFade * refractionIntensity;
                
                half4 sceneColor = half4(SampleSceneColor(refractionUV), 1);
                
                //水体深度
                // sceneRawDepth = SampleSceneDepth(refractionUV);                 //带折射的深度
                // sceneEyeDepth = LinearEyeDepth(sceneRawDepth, _ZBufferParams);

                float depthDifference = sceneEyeDepth + input.positionVS.z;     //EyeDepth - (-1 * P_ViewSpace.Z)

                // float edgeFade = saturate(Remap01(depthDifference, rcp(_EdgeFade), 0));
                float edgeRange = depthDifference * rcp(_EdgeFade);             //edgeFade remap[0,_EdgeFade]->[0,1]
                float edgeFade = saturate(edgeRange);    

                float waterDepth = pow(max(0, sceneEyeDepth - input.positionCS.w), 0.5);
                float waterDepthRemap = Remap01(waterDepth, rcp(_WaterDepthRange), 0);
                
                //水体颜色

                half4 waterColor = lerp(_ColorBright, _ColorDeep, waterDepthRemap);
                waterColor = lerp(waterColor * sceneColor, waterColor, waterColor.a);
                waterColor += saturate(lerp(half4(1,1,1,0), _EdgeColor, waterDepth)) * sceneColor;
                waterColor = saturate(waterColor);
                waterColor.a = edgeFade;

                //水体反射
                float NdotV = saturate(dot(normalWS, viewDirectionWS));
                float fresnel = 1 - NdotV;
                fresnel = Pow4(fresnel) * fresnel;
                fresnel = fresnel * 0.99 + 0.01;            //fresnel remap[0,1]->[0.01,1]

                
                //水体泡沫               
                float foam = (abs(normalTS.r) + abs(normalTS.g)) * 10;
                //水边泡沫颜色
                half sideFoam = foam * saturate(abs(uv2.y - 0.5) + (1 - edgeFade) * 0.2 - 0.1)*2;
                sideFoam = 1 - sideFoam;
                sideFoam = step(sideFoam, sideFoamRange);

                //瀑布拐角泡沫，用切线计算瀑布拐角的范围
                float TdotU = abs(dot(input.tangentWS, float3(0,0.6,0)));
                float fallCorner = 1 - saturate(abs(TdotU-0.25)*4);
                fallCorner *= fallCorner + foam;
                fallCorner = step(1, fallCorner);

                float fallFoam = step(0.8, foam) * (1 - saturate(input.normalWS.y));
                fallFoam = smoothstep(0,0.5,fallFoam);

                foam = max(sideFoam, max(fallCorner, fallFoam)*1.2);

                // -------------------------------------
                //PBR光照
                BRDFData brdfData = (BRDFData)0;
                InitializeBRDFData(half3(0,0,0), _Metallic, half3(0.0h, 0.0h, 0.0h), _Smoothness, waterColor.a, brdfData);

                half3 reflectVector = reflect(-viewDirWS, input.normalWS.xyz);
                half3 GlossyColor = GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, _OcclusionStrength);

                // Light mainLight = GetMainLight();
                // float3 specularNormalWS = normalize(normalWS * float3(1,0.1,1));
                // float NdotL = saturate(dot(specularNormalWS, mainLight.direction));

                
                //颜色采样，焦散纹理
                float2 base_uv = (input.uv.xy + normalTS.xy * _TwistStrength) * _BaseMap_ST.xy + _BaseMap_ST.zw * _Time.y;
                base_uv = BumpOffset(TangentToWorld, viewDirectionWS, base_uv, _CausticsHeight, 1 - waterDepthRemap, 0);
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, base_uv);
                albedoAlpha *= _BaseColor;

                //颜色混合
                half sideColorRange = 1.5;
                half4 color = albedoAlpha * NdotV * (saturate(input.normalWS.y-0.9) * 10) * saturate((sideColorRange - edgeRange) * sideColorRange); 
                color.rgb += lerp(waterColor.rgb, GlossyColor, fresnel);
                color.a = waterColor.a;

                color = lerp(color, foam * saturate(_EdgeColor * 1.5), foam * _EdgeColor.a);
                
                return color;
            }
            ENDHLSL
        }
        //Shadow
//        Pass
//        {
//            Name "ShadowCaster"
//            Tags{"LightMode" = "ShadowCaster"}
//
//            ZWrite On
//            ZTest LEqual
//            Cull[_Cull]
//
//            HLSLPROGRAM
//            // Required to compile gles 2.0 with standard srp library
//            #pragma prefer_hlslcc gles
//            #pragma exclude_renderers d3d11_9x
//            #pragma target 2.0
//
//            // -------------------------------------
//            // Material Keywords
//
//            //--------------------------------------
//            // GPU Instancing
//            #pragma multi_compile_instancing
//            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//
//            #pragma vertex ShadowPassVertex
//            #pragma fragment ShadowPassFragment
//
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
//            ENDHLSL
//        }
        //DepthOnly
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
//    CustomEditor "PBR_Base_ShaderGUI"
}
