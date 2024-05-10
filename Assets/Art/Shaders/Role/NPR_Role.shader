Shader "KIIF/NPR_Role"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [Toggle(_DoubleSide)] _DoubleSide("双面", Float) = 0.0
        [Toggle(_ALPHATEST_ON)] _AlphaTest("Alpha Clipping", Float) = 0.0
        _Cutoff("剔除阈值", Range(0.0, 1.0)) = 0.5
        
        _BumpScale("法线强度", Float) = 1.0
        [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
//        [NoScaleOffset] _SMAEMap("R:光滑度 G:金属度 B:AO A:自发光", 2D) = "white" {}
        [NoScaleOffset] _ControlMap("G:自阴影 B:金属度", 2D) = "white" {}
        _Smoothness("光滑度", Range(0.0, 1.0)) = 0.5
        [Gamma] _Metallic("金属度", Range(0.0, 1.0)) = 0.7
        
        [Space(20)]
        _LayerStep("颜色分层", Range(-1.0, 1.0)) = 0.3
        _LayerSmooth("颜色分层过渡", Range(0.0, 1.0)) = 0.05
        _Shadow("自阴影", Range(0, 1)) = 0.5
        _MaxLight("亮部", Range(0, 4)) = 3.0
        
        [Space(20)]
        _SpecularIntensity("高光强度", Range(0.0, 2.0)) = 0.0
        _SpecularLerp("高光范围", Range(-1.0, 1.0)) = 0.6
        _SpecularSmooth("高光柔度", Range(0.0, 1.0)) = 0.2
        
        [Space(20)]
        [HDR] _RimColor("边缘光颜色", Color) = (1,1,1)
        _RimIntensity("边缘光强度", Range(0.0, 5.0)) = 1.0
        _RimLerp("边缘光纯度", Range(0.0, 1.0)) = 0.5
        _RimSmooth("边缘光柔度", Range(0.0, 10.0)) = 5.0
        
        [Space(20)]
        [HDR] _EmissionColor("自发光颜色", Color) = (0,0,0)
        [Toggle(_EMISSIONALBEDO_ON)] _EmissionAlbedo("基础色发光", Float) = 0.0
        _EmissionStrength("自发光强度", Range(0.0, 1.0)) = 0.0
        
        [Header(Outline)]
        [Space]
        _OutlineColor("描边颜色", Color) = (0,0,0,0)
        _OutlineWidth("描边粗细", Range(0, 5)) = 0.5
        
        [Space(20)]
        [Header(Stencil)]
        [Space]
        _RefValue("Ref Value",Int) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8    //默认Always
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0    //默认Keep
        
//        [HideInInspector] _Surface("__surface", Float) = 0.0
//        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
//        [Enum(UnityEngine.Rendering.CullMode)] _Cull("剔除模式", Float) = 2.0
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
            Stencil
            {
                Ref [_RefValue]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }
            ZWrite[_ZWrite]
            Cull[_Cull]
            
            HLSLPROGRAM

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _NORMALMAP
            // #pragma shader_feature _SMAEMAP
            #pragma shader_feature _CONTROLMAP

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
            #include "Assets/Art/Shaders/Library/KIIFPBR.hlsl"
            
            // CBUFFER_START(UnityPerMaterial)
            half _LayerStep;
            half _LayerSmooth;
            half _Shadow;
            half _MaxLight;
            half _SpecularIntensity;
            half _SpecularLerp;
            half _SpecularSmooth;
            half4 _RimColor;
            half _RimIntensity;
            half _RimLerp;
            half _RimSmooth;
            
            // CBUFFER_END
            TEXTURE2D(_ControlMap);            SAMPLER(sampler_ControlMap);

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------
                //采样 初始化

                PBRData pbrData;    //KIIF自定义结构体
                PBRInitialize(input, pbrData);

                half specularArea = 0;
                half selfShadow = 1;
                #ifdef _CONTROLMAP
                half4 Control = SAMPLE_TEXTURE2D(_ControlMap, sampler_ControlMap, input.uv);
                pbrData.smoothness = _Smoothness;
                specularArea = Control.r;
                pbrData.metallic = Control.b * _Metallic;
                pbrData.occlusion = 1;
                selfShadow = Control.g;
                #endif
                

                // -------------------------------------
                //PBR光照
                BRDFData brdfData = (BRDFData)0;
                InitializeBRDFData(pbrData.albedo, pbrData.metallic, half3(0.0h, 0.0h, 0.0h), pbrData.smoothness, pbrData.alpha, brdfData);

                half fogCoord = input.fogFactorAndVertexLight.x;
                half3 vertexLighting = input.fogFactorAndVertexLight.yzw;
                
                float4 shadowCoord = TransformWorldToShadowCoord(pbrData.positionWS); //主光计算阴影
                Light mainLight = GetMainLight(shadowCoord);
                float mainLightIntensity = Max3(mainLight.color.r, mainLight.color.g, mainLight.color.b);
                mainLightIntensity = min(mainLightIntensity, 1.2);
                float GIIntensity = Desaturate(_GlossyEnvironmentColor.rgb, 0.0).r;
                // float LightIntensity = max(mainLightIntensity, GIIntensity);
                float LightIntensity = (mainLightIntensity + GIIntensity) * 0.5;
                // half lightFact = mainLightIntensity/(mainLightIntensity + GIIntensity);
                // float LightIntensity = mainLightIntensity * lightFact + GIIntensity * (1-lightFact);
                
                half4 color = GetDirectLightColor(mainLight, brdfData, pbrData);
                half3 GIcolor = GetGIColor(input, mainLight, brdfData, pbrData);
                
                color.rgb += GIcolor;

                #ifdef _ADDITIONAL_LIGHTS
                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                {
                    Light light = GetAdditionalLight(lightIndex, pbrData.positionWS);
                    color.rgb += LightingPhysicallyBased(brdfData, light, pbrData.normalWS, pbrData.viewDirectionWS);
                }
                #endif

                // -------------------------------------
                //非金属部分NPR光照
                half3 NPRColor = pbrData.albedo;
                // NPRColor = lerp(NPRColor, NPRColor * NPRColor, 0.7);                                //固定调色
                //颜色分层
                half NdotL = saturate(dot(pbrData.normalWS, mainLight.direction));
                half colorLayering = smoothstep(_LayerStep , _LayerStep + _LayerSmooth, NdotL);
                colorLayering = saturate(colorLayering + 0.5);

                half shadowLayer = saturate(lerp(_Shadow, _MaxLight, selfShadow));
                half3 NPRColor2 = GIcolor * shadowLayer;
                
                NPRColor = NPRColor * colorLayering * LightIntensity + NPRColor2;
                
                half blendFactor = lerp(0.2, 1, saturate(GIIntensity));
                color.rgb = lerp(NPRColor, color.rgb, pbrData.metallic * blendFactor);
                
                //区域高光
                float3 halfVec = SafeNormalize(float3(mainLight.direction) + float3(pbrData.viewDirectionWS));
                half NdotH = saturate(dot(pbrData.normalWS, halfVec));
                half modifier = smoothstep(_SpecularLerp, _SpecularLerp+_SpecularSmooth ,NdotH);
                half3 specularAlbedo = NPRColor * modifier * _SpecularIntensity;
                
                color.rgb = lerp(color.rgb, color.rgb + specularAlbedo, specularArea);
                //边缘光
                half NdotV = 1 - saturate(abs(dot(pbrData.normalWS, pbrData.viewDirectionWS)));
                NdotV = pow(NdotV, _RimSmooth);
                half3 rimColor = lerp(NPRColor, _RimColor.rgb, _RimLerp);
                
                color.rgb += NdotV * rimColor * _RimIntensity;
                // -------------------------------------
                #ifdef _EMISSIONALBEDO_ON
                color.rgb += pbrData.albedo * pbrData.emissionColor;
                #else
                color.rgb += pbrData.emissionColor;
                #endif
                // color.rgb = MixFog(color.rgb, fogCoord);
                return color;
            }
            ENDHLSL
        }
        // Outline
        Pass
        {
            Name "OutLine"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            
            Stencil
            {
                Ref [_RefValue]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }
            Cull Front
            
            HLSLPROGRAM   
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _ALPHATEST_ON
            //#pragma shader_feature _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _OLWVWD_ON

            // -------------------------------------
            // Unity defined keywords

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"         
            #include "Packages/com.unity.shadergraph/ShaderGraphLibrary/ShaderVariablesFunctions.hlsl"

            half4 _BaseColor;
            half4 _OutlineColor;
            half _OutlineWidth;
            half _Cutoff;
            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            
            struct Attributes
            {
                float4 positionOS       : POSITION;
                float2 uv               : TEXCOORD0;
                half3 normalOS          : NORMAL;
            };

            struct Varyings
            {
                float2 uv               : TEXCOORD0;
                float4 vertex           : SV_POSITION;
                float3 normal           : TEXCOORD1;
            };

            Varyings vert(Attributes input)
            {
                float4 scaledScreenParams = GetScaledScreenParams();
                float ScaleX = abs(scaledScreenParams.x / scaledScreenParams.y);//求得X因屏幕比例缩放的倍数
		        Varyings output = (Varyings)0;
		        VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
                float3 normalCS = TransformWorldToHClipDir(normalInput.normalWS);//法线转换到裁剪空间
                float2 extendDis = normalize(normalCS.xy) *(_OutlineWidth*0.1);//根据法线和线宽计算偏移量
                extendDis.x /= ScaleX ;//由于屏幕比例可能不是1:1，所以偏移量会被拉伸显示，根据屏幕比例把x进行修正

                //计算FOV，平衡不同FOV视角下的描边粗细
                half t = unity_CameraProjection._m11;
                half fov = pow(abs(t), 0.8);     //真正的FOV=atan(1/t)*2 * (180/pi);
                
                extendDis *= fov;
                
                output.vertex = vertexInput.positionCS;
                #if _OLWVWD_ON
                    //屏幕下描边宽度会变
                    output.vertex.xy += extendDis;
                #else
                    //屏幕下描边宽度不变，则需要顶点偏移的距离在NDC坐标下为固定值
                    //因为后续会转换成NDC坐标，会除w进行缩放，所以先乘一个w，那么该偏移的距离就不会在NDC下有变换
                    float ctrl = clamp(1/output.vertex.w, 0, 0.1);
                    output.vertex.xy += extendDis * output.vertex.w * ctrl;
                #endif
                
                output.uv = input.uv;
		        return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                //return float4(_OutlineColor.rgb, 1);
                float2 uv = input.uv;
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                half alpha = albedoAlpha.a * _BaseColor.a;
                #if defined(_ALPHATEST_ON)
                clip(alpha - _Cutoff);
                #endif

                half3 color = _OutlineColor.rgb * albedoAlpha.rgb;
                return half4(color, 1);
            }
            ENDHLSL
        }
        //Shadow
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
//        //DepthOnly
//        Pass
//        {
//            Name "DepthOnly"
//            Tags{"LightMode" = "DepthOnly"}
//
//            ZWrite On
//            ColorMask 0
//            Cull[_Cull]
//
//            HLSLPROGRAM
//            // Required to compile gles 2.0 with standard srp library
//            #pragma prefer_hlslcc gles
//            #pragma exclude_renderers d3d11_9x
//            #pragma target 2.0
//
//            #pragma vertex DepthOnlyVertex
//            #pragma fragment DepthOnlyFragment
//
//            // -------------------------------------
//            // Material Keywords
//            #pragma shader_feature _ALPHATEST_ON
//            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//
//            //--------------------------------------
//            // GPU Instancing
//            #pragma multi_compile_instancing
//
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
//            ENDHLSL
//        }
//        // This pass it not used during regular rendering, only for lightmap baking.
//        Pass
//        {
//            Name "Meta"
//            Tags{"LightMode" = "Meta"}
//
//            Cull Off
//
//            HLSLPROGRAM
//            // Required to compile gles 2.0 with standard srp library
//            #pragma prefer_hlslcc gles
//            #pragma exclude_renderers d3d11_9x
//
//            #pragma vertex UniversalVertexMeta
//            #pragma fragment UniversalFragmentMeta
//
//            #pragma shader_feature _SPECULAR_SETUP
//            #pragma shader_feature _EMISSION
//            #pragma shader_feature _METALLICSPECGLOSSMAP
//            #pragma shader_feature _ALPHATEST_ON
//            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//
//            #pragma shader_feature _SPECGLOSSMAP
//
//            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
//            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"
//            #include "Assets/Art/Shaders/Library/KIIFMetaPass.hlsl"
//
//            ENDHLSL
//        }
    }
    CustomEditor "NPR_Role_ShaderGUI"
}
