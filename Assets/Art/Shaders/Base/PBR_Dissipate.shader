﻿Shader "KIIF/PBR_Dissipate"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
//        [Toggle(_DOUBLESIDE_ON)] _DoubleSide("双面", Float) = 0.0
//        [Toggle(_DEPTHWRITE_ON)] _DepthWrite("深度写入", Float) = 0.0
        [Toggle(_ALPHATEST_ON)] _AlphaTest("Alpha Clipping", Float) = 0.0
        _Cutoff("剔除阈值", Range(0.0, 1.0)) = 0.5
        _BumpScale("法线强度", Float) = 1.0
        [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
        [NoScaleOffset] _SMAEMap("R:光滑度 G:金属度 B:AO A:自发光", 2D) = "white" {}
        _Smoothness("光滑度", Range(0.0, 1.0)) = 0.5
        [Gamma] _Metallic("金属度", Range(0.0, 1.0)) = 0.0
        _OcclusionStrength("AO", Range(0.0, 1.0)) = 1.0
        [HDR] _EmissionColor("自发光颜色", Color) = (0,0,0)
        _EmissionStrength("自发光强度", Range(0.0, 1.0)) = 0.0
        
        [Space(20)]
        [Header(Dissipate)]
        [Space]
        _WorldPositionAdjust("世界方向高度调节", Float) = 1
        _WorldPositionOffset("世界方向偏移调节", Float) = 0
        _DissolveMap("溶解贴图", 2D) = "white" {}
        _Dissipate ("融解进度", Range(0, 1)) = 0
        [PowerSlider(2)] _DissipateEdgeSize("融解边缘宽度", Range(0, 1)) = 0
        [HDR] _DissipateEdgeColor("融解边缘颜色", Color) = (1,1,1,1)
        
        [Space(20)]
        [Header(BlendMode)]
        [Space]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Value",Int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Value",Int) = 0
        
        [Space(20)]
        [Header(Stencil)]
        [Space]        
        _RefValue("Ref Value",Int) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8      //默认Always
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep
        
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
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
            Blend [_SrcBlend] [_DstBlend]
            Stencil
            {
                Ref [_RefValue]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }
            
//            ZWrite[_ZWrite]
//            Cull[_Cull]
            
            HLSLPROGRAM

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _SMAEMAP

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
            #include "Assets/Art/Shaders/Library/KIIFCommon.hlsl"

            // CBUFFER_START(UnityPerMaterial)
            float _WorldPositionAdjust;
            float _WorldPositionOffset;
            float4 _DissolveMap_ST;
            half _Dissipate;
            half _DissipateEdgeSize;
            half4 _DissipateEdgeColor;
            // CBUFFER_END

            TEXTURE2D(_DissolveMap);            SAMPLER(sampler_DissolveMap);

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------
                //采样 初始化
                PBRData pbrData;    //KIIF自定义结构体
                PBRInitialize(input, pbrData);

                // -------------------------------------
                // 溶解

                float3 worldPosition = input.positionWS;
                float4 objectPosition = UNITY_MATRIX_M._14_24_34_44;
                half dissolveMask = (worldPosition.y - objectPosition.y + _WorldPositionOffset) * _WorldPositionAdjust;
                dissolveMask *= rcp(length(UNITY_MATRIX_M._12_22_32));
				// return dissolveMask;

                half2 dissipateUV = TRANSFORM_TEX(input.uv, _DissolveMap);
                half dissipateSrc = SAMPLE_TEXTURE2D(_DissolveMap, sampler_DissolveMap, dissipateUV).r;
                dissipateSrc = saturate(dissipateSrc + dissolveMask - _Dissipate);
                half4 dissipateColor = DissipateCompletely(dissipateSrc, _Dissipate, _DissipateEdgeSize, _DissipateEdgeColor.rgb);
                pbrData.emissionColor += dissipateColor.rgb;
                
                // -------------------------------------
                //PBR光照
                BRDFData brdfData = (BRDFData)0;
                InitializeBRDFData(pbrData.albedo, pbrData.metallic, half3(0.0h, 0.0h, 0.0h), pbrData.smoothness, pbrData.alpha, brdfData);
                
                // half fogCoord = input.fogFactorAndVertexLight.x;
                // half3 vertexLighting = input.fogFactorAndVertexLight.yzw;
                
                float4 shadowCoord = TransformWorldToShadowCoord(pbrData.positionWS); //主光计算阴影
                Light mainLight = GetMainLight(shadowCoord);
                
                half4 color = GetDirectLightColor(mainLight, brdfData, pbrData);
                half3 GIcolor = GetGIColor(input, mainLight, brdfData, pbrData);
                
                color.rgb += GIcolor;
                
                #ifdef _ADDITIONAL_LIGHTS
                color.rgb += GetAdditionalLightColor(brdfData, pbrData);
                #endif
                
                // -------------------------------------
                color.rgb += pbrData.emissionColor;
                // color.rgb = MixFog(color.rgb, fogCoord);
                return color;
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
            #pragma shader_feature _DISSOLVE_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma vertex DissipateShadowPassVertex                //自定义的ShadowPass，添加了溶解效果
            #pragma fragment DissipateShadowPassFragment            //自定义的ShadowPass，添加了溶解效果

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            // #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            #include "Assets/Art/Shaders/Library/KIIFShadowPassDissipate.hlsl"
            
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
    }
//    CustomEditor "PBR_Transparent_ShaderGUI"
}
