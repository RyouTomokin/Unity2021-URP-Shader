Shader "KIIF/Fresnel"
{
    Properties
    {
//        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
//        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        _MaskMap("遮罩图", 2D) = "white" {}
        
        [Space(20)]
        [Header(Fresnel)]
        [Space(10)]
        [HDR] _FresnelColor("FresnelColor", Color) = (0,0,0,0)
        [PowerSlider(4)] _FresnelPower("FresnelPower", Range(0, 10)) = 1
        _FresnelReversal("FresnelReversal", Range(0, 1)) = 0
        [Space(10)]
        [HDR] _FresnelColor2("FresnelColor2", Color) = (0,0,0,0)
        [PowerSlider(4)] _FresnelPower2("FresnelPower2", Range(0, 10)) = 1
        _FresnelReversal2("FresnelReversal2", Range(0, 1)) = 1
        
        
        [Enum(Add, 1, SrcAlpha, 5)] _SrcBlend("SrcBlend", Float) = 5.0
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("DstBlend", Float) = 10.0
        
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

                float3 normalWS                 : TEXCOORD3;
                float3 viewDirWS                : TEXCOORD4;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            // half4 _BaseColor;
            // float4 _BaseMap_ST;
            float4 _MaskMap_ST;
            half4 _FresnelColor;
            half _FresnelPower;
            half _FresnelReversal;
            half4 _FresnelColor2;
            half _FresnelPower2;
            half _FresnelReversal2;

            half _SrcBlend;
            CBUFFER_END

            // TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
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

                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
                output.viewDirWS = normalize(viewDirWS);

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

                // float2 baseUV = input.uv * _BaseMap_ST.xy + _BaseMap_ST.zw * _Time.y ;
                // half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);
                // half alpha = albedoAlpha.a * _BaseColor.a * MaskMap.r;
                // half3 albedo = albedoAlpha.rgb * _BaseColor.rgb;

                half4 fresnelColor;
                float NdotV = saturate(dot(input.normalWS, input.viewDirWS));
                float NdotV2 = 1-NdotV;
                NdotV = pow(NdotV, max(HALF_MIN, _FresnelPower));
                float fresnel = lerp(1-NdotV, NdotV, _FresnelReversal);
                fresnelColor = fresnel * _FresnelColor;
                
                NdotV2 = pow(NdotV2, max(HALF_MIN, _FresnelPower2));
                float fresnel2 = lerp(NdotV2, 1-NdotV2, _FresnelReversal2);
                fresnelColor += fresnel2 * _FresnelColor2;
                fresnelColor.a = saturate(fresnelColor.a);
                
                half4 color;
                //Add Mode MaskMap applied to masks
                color = _SrcBlend==1 ? fresnelColor*MaskMap.r : fresnelColor;
                
                color.a *= MaskMap.r;
                
                // color.a = alpha;

                // -------------------------------------
                
                // -------------------------------------
                
                // color.rgb = albedo;
                return color;
            }
            ENDHLSL
        }
    }
}
