Shader "KIIF/Special/BossPlatform"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
//        [Toggle(_DoubleSide)] _DoubleSide("双面", Float) = 0.0
//        [Toggle(_ALPHATEST_ON)] _AlphaTest("Alpha Clipping", Float) = 0.0
//        _Cutoff("剔除阈值", Range(0.0, 1.0)) = 0.5
        _BumpScale("法线强度", Float) = 1.0
        [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
        [NoScaleOffset] _SMAEMap("R:光滑度 G:金属度 B:AO A:自发光", 2D) = "white" {}
        _Smoothness("光滑度", Range(0.0, 1.0)) = 0.5
        [Gamma] _Metallic("金属度", Range(0.0, 1.0)) = 0.0
        _OcclusionStrength("AO", Range(0.0, 1.0)) = 1.0
        [HDR] _EmissionColor("自发光颜色", Color) = (0,0,0)
        _EmissionStrength("自发光强度", Range(0.0, 1.0)) = 0.0
        
        [Space(20)]
        [Header(Magic)]
        [Space]
        _MagicBlend("MagicBlend", Range(0, 1)) = 0.0
        [Toggle(_SCREENPOSITION_ON)] _UseBumpOffset("BumpOffset", float) = 1.0
        //强制开启切线的计算
        [HideInInspector] [Toggle(_NORMALMAP)] _UseTangent("UseTangent", float) = 1.0
        
        _NoiseMap("Noise", 2D) = "black" {}
        
        [Space(10)]
        [Header(Mask)]
        [Space]
        [NoScaleOffset] _MaskMap("Mask", 2D) = "black" {}
        _StreamOffset("StreamOffset", Range(0, 1)) = 0.0
        _StreamIntensity("StreamIntensity", Float) = 1.0
        [HDR] _MaskColor01("MaskColor01", Color) = (1,1,1,1)
        [HDR] _MaskColor02("MaskColor02", Color) = (1,1,1,1)
        
        [Space(10)]
        [Header(Starry Sky)]
        [Space]
        _StarryMap("Starry", 2D) = "black" {}
        _StarryHeight("StarryHeight", Float) = 1.0
        _StarryNoiseStrength("StarryNoiseStrength", Float) = 1.0
        
        _StarsMap("Stars", 2D) = "black" {}
        
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
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _SCREENPOSITION_ON
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

            float _MagicBlend;
            float4 _NoiseMap_ST;
            float _StreamOffset;
            float _StreamIntensity;
            float4 _MaskColor01;
            float4 _MaskColor02;
            float4 _StarryMap_ST;
            float _StarryHeight;
            float _StarryNoiseStrength;
            float4 _StarsMap_ST;

            TEXTURE2D(_NoiseMap);           SAMPLER(sampler_NoiseMap);
            TEXTURE2D(_MaskMap);            SAMPLER(sampler_MaskMap);
            TEXTURE2D(_StarryMap);          SAMPLER(sampler_StarryMap);
            TEXTURE2D(_StarsMap);           SAMPLER(sampler_StarsMap);

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------
                //采样 初始化

                PBRData pbrData;    //KIIF自定义结构体
                PBRInitialize(input, pbrData);

                // -------------------------------------
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
                color.rgb += GetAdditionalLightColor(brdfData, pbrData);
                #endif

                //暂存基础颜色
                half4 baseColor = color;

                // -------------------------------------
                //噪波，星空的扭曲和流光

                float2 noiseUV = input.uv * _NoiseMap_ST.xy + _NoiseMap_ST.zw * _Time.y;
                half noise = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, noiseUV).r;
                
                // -------------------------------------
                //星空颜色

                float2 starryUV = input.uv * _StarryMap_ST.xy + _StarryMap_ST.zw * _Time.y;
                #ifdef _SCREENPOSITION_ON
                half3x3 TangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
            	half3 cameraVector = normalize(_WorldSpaceCameraPos - input.positionWS);
                // 使用Noise扰乱深度，实现波动的效果
                half starryHeight = _StarryHeight + noise * _StarryNoiseStrength;
                starryUV = BumpOffset(TangentToWorld, cameraVector, starryUV, starryHeight);
                #endif
                half4 StarryColor = SAMPLE_TEXTURE2D(_StarryMap, sampler_StarryMap, starryUV);

                // color = StarryColor;
                // color = color*(1+StarryColor);
                // color *= StarryColor;
                // color += StarryColor;
                //Screen Blend
                color = 1 - ((1-color) * (1-StarryColor));

                //星星采样，使用星空一半的深度
                float2 starsUV = input.uv * _StarsMap_ST.xy + _StarsMap_ST.zw * _Time.y;
                #ifdef _SCREENPOSITION_ON
                starsUV = BumpOffset(TangentToWorld, cameraVector, starsUV, _StarryHeight*0.5);
                #endif
                half4 starsColor = SAMPLE_TEXTURE2D(_StarsMap, sampler_StarsMap, starsUV);

                color += starsColor * CheapContrast(noise, 0.2);
                
                // -------------------------------------
                //符文颜色
                // TODO:现在的Mask是特定的镜像采样的贴图
                float2 maskUV = input.uv * 2;
                half4 maskColor = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, maskUV);

                // TODO:符文呼吸灯效果
                // float breathingIntensity = _StreamIntensity * (abs(sin(_Time.y)) + _StreamOffset);
                float streamIntensity = (noise + _StreamOffset) * _StreamIntensity;
                color += maskColor.r * _MaskColor01 * streamIntensity;
                color += maskColor.g * _MaskColor02 * streamIntensity;
                
                // -------------------------------------

                //混合
                color = lerp(baseColor, color, _MagicBlend);
                
                // -------------------------------------
                color.rgb += pbrData.emissionColor;

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
            #pragma shader_feature _SMAEMAP
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
//    CustomEditor "PBR_Base_ShaderGUI"
}
