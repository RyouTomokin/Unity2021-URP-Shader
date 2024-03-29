Shader "KIIF/Decal"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [Toggle(_ALPHATEST_ON)] _AlphaTest("Alpha Clipping", Float) = 0.0
        _Cutoff("剔除阈值", Range(0.0, 1.0)) = 0.5
//        _BumpScale("法线强度", Float) = 1.0
//        [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
//        [NoScaleOffset] _SMAEMap("R:光滑度 G:金属度 B:AO A:自发光", 2D) = "white" {}
//        _Smoothness("光滑度", Range(0.0, 1.0)) = 0.5
//        [Gamma] _Metallic("金属度", Range(0.0, 1.0)) = 0.0
//        _OcclusionStrength("AO", Range(0.0, 1.0)) = 1.0
        [HDR] _EmissionColor("自发光颜色", Color) = (0,0,0)
        _EmissionStrength("自发光强度", Range(0.0, 1.0)) = 0.0
        
        [Space(20)]
        [Header(Stencil)]
        [Space]
        _RefValue("Ref Value",Int) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 5      //默认Greater
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep
    }
    SubShader
    {
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "Queue" = "Transparent"}
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
            
            ZWrite Off
            ZTest Off
            Cull Front
            HLSLPROGRAM

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON

            // -------------------------------------
            // Universal Pipeline keywords
            // #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            // #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            // #pragma multi_compile _ LIGHTMAP_ON
            // #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:vertInstancingSetup
            
            #pragma vertex vert_decal
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/Art/Shaders/Library/KIIFDecal.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            
            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // 要计算用于采样深度缓冲区的 UV 坐标，
                // 请将像素位置除以渲染目标分辨率
                // _ScaledScreenParams。
                float2 UV = input.positionCS.xy / _ScaledScreenParams.xy;
                // 从摄像机深度纹理中采样深度。
                #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(UV);
                #else
                    //  调整 Z 以匹配 OpenGL 的 NDC ([-1, 1])
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif
                
                // 重建世界空间位置。
                float3 worldPos = ComputeWorldSpacePosition(UV, depth, UNITY_MATRIX_I_VP);
                // 剔除之外的像素
                float3 localPos = mul(unity_WorldToObject, float4(worldPos,1)).xyz;
                clip(0.5 - abs(localPos));
                // 贴花UV
                float2 decalUV = localPos.xz + 0.5;
                input.uv = decalUV * _BaseMap_ST.xy + _BaseMap_ST.zw;
                // 用重建的世界坐标计算阴影UV
                input.positionWS = worldPos;

                // -------------------------------------
                //采样 初始化
                PBRData pbrData;    //KIIFDecal自定义结构体
                PBRInitialize(input, pbrData);
                
                // -------------------------------------
                //PBR光照
                
                // half fogCoord = input.fogFactorAndVertexLight.x;

                float4 shadowCoord = TransformWorldToShadowCoord(pbrData.positionWS); //主光计算阴影
                Light mainLight = GetMainLight(shadowCoord);

                // 只有阴影起作用的光照
                half4 color = pbrData.albedoAlpha;
                color.rgb *=
                    mainLight.color * mainLight.distanceAttenuation * mainLight.shadowAttenuation;
                color.rgb += pbrData.albedo * _GlossyEnvironmentColor.rgb;

                // -------------------------------------
                color.rgb += pbrData.emissionColor;
                color.a *= smoothstep(0.5, 0.4, abs(localPos.y));
                // color.rgb = MixFog(color.rgb, fogCoord);
                return color;
            }
            ENDHLSL
        }
    }
}
