Shader "KIIF/Unlit_Lattice"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        _UVScale("UV Scale", Float) = 1
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        _MaskMap("遮罩图", 2D) = "white" {}
        
        _SideDistance("SideDistance", Float) = 1
        [HDR] _FadeColor("FadeColor", Color) = (1,1,1,1)
        _DepthFade("DepthFade", Float) = 1
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
            Cull off
            
            HLSLPROGRAM

            // #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords

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
                // half4 color                     : COLOR;
                
                float3 normalOS                 : NORMAL;
                float4 tangentOS                : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct VaryingsUnlit
            {
                float4 positionCS               : SV_POSITION;
                float2 uv                       : TEXCOORD0;
                // half4 color                     : COLOR;
                
                float3 positionWS               : TEXCOORD1;
                float4 projectedPosition        : TEXCOORD2;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _BaseColor;
            half _UVScale;
            half _SideDistance;
            half4 _FadeColor;
            half _DepthFade;
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
                                
                output.uv = input.uv;

                output.positionWS = vertexInput.positionWS;
                output.positionCS = vertexInput.positionCS;

                output.projectedPosition = vertexInput.positionNDC;
                
                return output;
            }
            half4 frag_Unlit(VaryingsUnlit input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------
                // 边缘半透
                float3 scaleXYZ = float3(   length(UNITY_MATRIX_M._11_21_31),
                                            length(UNITY_MATRIX_M._12_22_32),
                                            length(UNITY_MATRIX_M._13_23_33));
                float2 worldUV = float2(scaleXYZ.x * input.uv.x, input.positionWS.y);
                worldUV *= _UVScale;
                half sideFade = 1 - abs(2 * (input.uv.x - 0.5));
                sideFade = smoothstep(0, _SideDistance / scaleXYZ.x, sideFade);
                sideFade *= smoothstep(0, 0.5 * _SideDistance / scaleXYZ.y, 1 - input.uv.y);

                // -------------------------------------
                // 贴图采样
                float2 baseUV = worldUV * _BaseMap_ST.xy + _BaseMap_ST.zw * _Time.y ;
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);
                
                float2 maskUV = worldUV * _MaskMap_ST.xy + _MaskMap_ST.zw * _Time.y ;
                half4 MaskMap = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, maskUV);
                
                half4 color = albedoAlpha * MaskMap * _BaseColor;

                // -------------------------------------
                // 底边半透和衔接高亮
                float rawDepth = SampleSceneDepth(input.projectedPosition.xy / input.projectedPosition.w).r;
                float sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);
                float thisZ = LinearEyeDepth(input.positionWS, GetWorldToViewMatrix());
                float fade = saturate((sceneZ - thisZ) / _DepthFade);
                
                // -------------------------------------
                
                color = lerp(_FadeColor, color, max(0, fade-0.5) * 2);
                color.a *= min(1, fade * 2);
                
                color.a *= sideFade;

                
                return color;
            }
            ENDHLSL
        }
    }
}
