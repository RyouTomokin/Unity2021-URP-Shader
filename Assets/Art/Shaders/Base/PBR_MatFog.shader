Shader "KIIF/PBR_MatFog"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
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
        //[Header(Fog)]
        [Toggle(_MATFOG_ON)] _UseFog("使用云海", float) = 0
        _FogStart("底部位置", Float) = 0.0
        _FogEnd("顶部位置", Float) = 1.0
        _FogColor("云海色调", Color) = (1,1,1,1)

        _ColorSize("颜色图大小", Float) = 1.0
        _ColorHeight("颜色图高度", Float) = 1.0

        _NoiseMap("噪波图", 2D) = "white" {}
        _NoiseScale("噪波图强度", Float) = 1.0
        _NoiseSize("噪波图大小", Float) = 1.0

        _SpeedX("流动速度X", Float) = 1.0
        _SpeedY("流动速度Y", Float) = 1.0
        
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
            #pragma shader_feature _SMAEMAP
            #pragma shader_feature _MATFOG_ON
            #pragma shader_feature _COLORRAMP_ON
            #pragma shader_feature _SNOW_ON
            #pragma shader_feature _SNOWMAP
            #pragma shader_feature _SNOWRANGE_ALBEDO_CHANNEL_A
            #pragma shader_feature _SNOWNORMALMAP

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
            #include "Assets/Art/Shaders/Library/MatFogFunction.hlsl"
            

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------
                //采样 初始化

                PBRData pbrData;    //KIIF自定义结构体
                PBRInitialize(input, pbrData);
                
                //PBR光照
                BRDFData brdfData = (BRDFData)0;
                InitializeBRDFData(pbrData.albedo, pbrData.metallic, half3(0.0h, 0.0h, 0.0h), pbrData.smoothness, pbrData.alpha, brdfData);


                half fogCoord = input.fogFactorAndVertexLight.x;
                half3 vertexLighting = input.fogFactorAndVertexLight.yzw;
                
                float4 shadowCoord = TransformWorldToShadowCoord(pbrData.positionWS); //主光计算阴影
                Light mainLight = GetMainLight(shadowCoord);
                
                half4 color = GetDirectLightColor(mainLight, brdfData, pbrData);
                half3 GIcolor = GetGIColor(input, mainLight, brdfData, pbrData);
                
                color.rgb += GIcolor;
                
                #ifdef _ADDITIONAL_LIGHTS
                GetAdditionalLightColor(brdfData, pbrData);
                #endif
                // -------------------------------------
                //材质云海
                
                MatFogFunction(input.positionWS, input.positionCS, color);
                
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
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMeta

            #pragma shader_feature _SPECULAR_SETUP
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICSPECGLOSSMAP
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma shader_feature _SPECGLOSSMAP

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"
            #include "Assets/Art/Shaders/Library/KIIFMetaPass.hlsl"

            ENDHLSL
        }
    }
    CustomEditor "PBR_Base_ShaderGUI"
}
