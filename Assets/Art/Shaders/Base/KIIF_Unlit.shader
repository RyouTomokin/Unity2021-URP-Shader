Shader "KIIF/Unlit"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        _MaskMap("遮罩图", 2D) = "white" {}
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("SrcBlend", Float) = 1.0
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("DstBlend", Float) = 0.0
        
//        [Space(20)]
//        [Header(Stencil)]
//        [Space]
//        _RefValue("Ref Value",Int) = 0
//        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8      //默认Always
//        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep
        
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0
    }
    SubShader
    {
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "Queue" = "Transparent"}
        LOD 300
        //ForwardLit
        Pass
        {
//            Name "ForwardLit"
//            Tags{"LightMode" = "UniversalForward"}
            
//            Stencil
//            {
//                Ref [_RefValue]
//                Comp [_StencilComp]
//                Pass [_StencilPass]
//            }
            
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_Cull]
            
            HLSLPROGRAM

            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _SOFTPARTICLES_ON

            // -------------------------------------
            // Universal Pipeline keywords
            // #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            // #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            // #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            // #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            // #pragma multi_compile _ _SHADOWS_SOFT
            // #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // -------------------------------------
            // Unity defined keywords
            // #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            // #pragma multi_compile _ LIGHTMAP_ON
            // #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            
            #pragma vertex vert_Unlit
            #pragma fragment frag_Unlit
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct AttributesUnlit
            {
                float4 positionOS               : POSITION;
                float2 uv                       : TEXCOORD0;
                half4 color                     : COLOR;
                
                float3 normalOS                 : NORMAL;
                float4 tangentOS                : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct VaryingsUnlit
            {
                float4 positionCS               : SV_POSITION;
                float2 uv                       : TEXCOORD0;
                half4 color                     : COLOR;
                
                // float3 positionWS               : TEXCOORD2;
                // float4 normalWS                 : TEXCOORD3;    // xyz: normal
                // float4 tangentWS                : TEXCOORD4;    // xyz: tangent
                // float4 bitangentWS              : TEXCOORD5;    // xyz: bitangent

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _BaseColor;
            float4 _BaseMap_ST;
            float4 _MaskMap_ST;
            CBUFFER_END

            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MaskMap);            SAMPLER(sampler_MaskMap);

            VaryingsUnlit vert_Unlit(AttributesUnlit input)
            {
                VaryingsUnlit output = (VaryingsUnlit)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                // VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.uv = input.uv;

                output.positionCS = vertexInput.positionCS;

                // -------------------------------------
                
                return output;
            }
            half4 frag_Unlit(VaryingsUnlit input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------
                //采样 初始化
                float2 maskUV = TRANSFORM_TEX(input.uv, _MaskMap);
                half4 MaskMap = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, maskUV);

                float2 baseUV = input.uv * _BaseMap_ST.xy + _BaseMap_ST.zw * _Time.y ;
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);
                half alpha = albedoAlpha.a * _BaseColor.a * MaskMap.r;
                half3 albedo = albedoAlpha.rgb * _BaseColor.rgb;
                
                half4 color;
                
                color.a = alpha;

                // -------------------------------------
                // 软粒子
                // #ifdef _SOFTPARTICLES_ON
                // float fade = 1;
                //     float rawDepth = SampleSceneDepth(input.projectedPosition.xy / input.projectedPosition.w).r;
                //     float sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);
                //     float thisZ = LinearEyeDepth(input.positionWS, GetWorldToViewMatrix());
                //     fade = saturate((sceneZ - thisZ) / _SoftParticle);
                // color.a *= fade;
                // #endif

                // -------------------------------------
                
                color.rgb = albedo;
                return color;
            }
            ENDHLSL
        }
    }
}
