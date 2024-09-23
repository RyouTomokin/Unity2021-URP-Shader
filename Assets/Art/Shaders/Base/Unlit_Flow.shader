Shader "KIIF/Unlit_Flow"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [Toggle(_ALPHATEST_ON)] _AlphaTest("Alpha Clipping", Float) = 0.0
        _Cutoff("剔除阈值", Range(0.0, 1.0)) = 0.5
        _Speed("Speed", Float) = 0
        
        [Space(20)]
        [Header(FlowMap)]
        [Space(10)]
        [Toggle] _FLOWMAP("Use FlowMap", Float) = 0
        _FlowMap("FlowMap", 2D) = "white" {}        
        _FlowDistance("FlowDistance", Float) = 1
        
        [Space(20)]
        [Header(Emission)]
        [Space(10)]
        _Brighten("提亮", Range(0, 5)) = 1
        
        
        [Space(20)]
        [Header(BlendMode)]
        [Space(10)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("SrcBlend", Float) = 1.0
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("DstBlend", Float) = 0.0
        
//        [Space(20)]
//        [Header(Stencil)]
//        [Space]
//        _RefValue("Ref Value",Int) = 0
//        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8      //默认Always
//        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep
        
//        [HideInInspector] _Surface("__surface", Float) = 0.0
//        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
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

            // #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _FLOWMAP_ON

            // -------------------------------------
            // Universal Pipeline keywords

            // -------------------------------------
            // Unity defined keywords

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

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _BaseColor;
            float4 _BaseMap_ST;
            float4 _FlowMap_ST;
            float _Cutoff;
            float _Speed;

            float _UseFlowMap;
            float _FlowDistance;
            float _Brighten;
            CBUFFER_END

            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_FlowMap);            SAMPLER(sampler_FlowMap);

            VaryingsUnlit vert_Unlit(AttributesUnlit input)
            {
                VaryingsUnlit output = (VaryingsUnlit)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.uv = input.uv;

                output.positionCS = vertexInput.positionCS;

                // -------------------------------------
                
                return output;
            }

            float3 FlowUVW (float2 uv, float2 flowVector, float time, float phaseOffset ) {
	            float progress = frac(time + phaseOffset);
	            float3 uvw;
	            uvw.xy = uv + flowVector * progress;
	            uvw.z = 1 - abs(1 - 2 * progress);
	            return uvw;
            }
            
            half4 frag_Unlit(VaryingsUnlit input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------
                //采样 初始化
                
                float time = _Time.y * _Speed;

                #ifdef _FLOWMAP_ON
                float2 flowUV = TRANSFORM_TEX(input.uv, _FlowMap);
                half4 FlowMap = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, flowUV);
                #ifdef _ALPHATEST_ON
                clip(FlowMap.a - _Cutoff);
                #endif

                float2 flowVector = FlowMap.rg * 2 - 1;
                flowVector *= _FlowDistance;
                
                float2 baseUV = input.uv * _BaseMap_ST.xy + _BaseMap_ST.zw * time;
                float3 uvwA = FlowUVW(baseUV, flowVector, time, 0);
                float3 uvwB = FlowUVW(baseUV, flowVector, time, 0.5);

                half4 albedoA = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uvwA.xy) * uvwA.z;
                half4 albedoB = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uvwB.xy) * uvwB.z;

                half4 albedoAlpha = albedoA + albedoB;
                albedoAlpha.a *= FlowMap.a;
                
                #else
                float2 baseUV = input.uv * _BaseMap_ST.xy + _BaseMap_ST.zw * time;
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);
                #ifdef _ALPHATEST_ON
                clip(albedoAlpha.a - _Cutoff);
                #endif
                
                #endif

                half4 color = albedoAlpha;
                color.rgb = pow(abs(color.rgb), _Brighten) * _Brighten * _Brighten;  //提亮贴图的颜色
                color *= _BaseColor;

                return color;
            }
            ENDHLSL
        }
    }
}
