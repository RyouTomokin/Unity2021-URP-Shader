Shader "KIIF/Effect/PolarFlow"
{
    Properties
    {
        [MainColor][HDR] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        _MaskMap("MaskMap", 2D) = "white" {}
		_UVPower("UVPower", Range(0.1, 5)) = 1
		_DarkColor("DarkColor", Color) = (0.5,0.5,0.5,1)
        _DarkOffset("DarkOffset", Range(-1, 1)) = 0
        _DarkMul("DarkMul", Range(0, 5)) = 1

        [Space(20)]
        [Header(FlowMap)]
        [Space(10)]
        _FlowMap("FlowMap", 2D) = "white" {}
        _FlowStrength("Flow(RG:Strength B:Speed)", Vector) = (0.1,0.1,0,0)

        [Space(20)]
        [Header(Dust)]
        [Space(10)]
        _DustColor("DustColor", Color) = (1,1,1,1)
        _DustMap("DustMap", 2D) = "white" {}

        [Space(20)]
        [Header(Stencil)]
        [Space]
        _RefValue("Ref Value",Int) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8      //默认Always
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep

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

            Stencil
            {
                Ref [_RefValue]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }

            Blend SrcAlpha OneMinusSrcAlpha
            ZTest Always
            ZWrite [_ZWrite]
            Cull [_Cull]

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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ParticlesInstancing.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
            #include "Assets/Art/Shaders/Library/KIIFCommon.hlsl"

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

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _BaseColor;
            half4 _DarkColor;
            half4 _DustColor;
            float4 _BaseMap_ST;
            float4 _MaskMap_ST;
            float4 _FlowMap_ST;
            float4 _DustMap_ST;
            float _UVPower;
            float _DarkOffset;
            float _DarkMul;

            float4 _FlowStrength;
            CBUFFER_END

            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MaskMap);            SAMPLER(sampler_MaskMap);
            TEXTURE2D(_FlowMap);            SAMPLER(sampler_FlowMap);
            TEXTURE2D(_DustMap);            SAMPLER(sampler_DustMap);

            VaryingsUnlit vert_Unlit(AttributesUnlit input)
            {
                VaryingsUnlit output = (VaryingsUnlit)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.uv = input.uv;
                output.color = input.color;

                output.positionCS = vertexInput.positionCS;

                // -------------------------------------

                return output;
            }

            // half4 Flow(TEXTURE2D_PARAM(tex, samp), float2 UV, float2 FlowDirection, float2 FlowStrength = float2(1,1), float FlowSpeed = 0.2)
            // {
            //     float time = _Time.y * FlowSpeed;
            //     float2 flowDir = -(FlowDirection * 2 - 1) * FlowStrength;
            //     float2 UV1 = UV + flowDir * frac(time);
            //     float2 UV2 = UV + flowDir * frac(time+0.5);
            //     half4 map1 = SAMPLE_TEXTURE2D(tex, samp, UV1);
            //     half4 map2 = SAMPLE_TEXTURE2D(tex, samp, UV2);
            //
            //     return lerp(map1, map2, abs(frac(time) - 0.5) * 2);
            // }


            half4 frag_Unlit(VaryingsUnlit input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------

                float4 vertexColor = input.color;
                float2 polarUV = PolarCoordinates(input.uv);
                polarUV.x = pow(polarUV.x, _UVPower);
                float2 flowUV = polarUV * _FlowMap_ST.xy + _Time.y * _FlowMap_ST.zw;
                half2 flowDirection = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, flowUV).xy;

                float2 baseUV = polarUV * _BaseMap_ST.xy + _Time.y * _BaseMap_ST.zw;
                half4 color = Flow(TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap), baseUV, flowDirection,
                    _FlowStrength.xy, _FlowStrength.z);
                color *= _BaseColor;

                half lambert = dot(input.normalWS, _MainLightPosition.xyz);
                half halfLambert = lambert * 0.5 + 0.5;
                color *= halfLambert;

                // -------------------------------------

                float2 dustUV = polarUV * _DustMap_ST.xy + _Time.y * _DustMap_ST.zw;
                half4 dustColor = SAMPLE_TEXTURE2D(_DustMap, sampler_DustMap, dustUV).r * _DustColor;


                float dustMask = distance(input.uv, 0.5);
                color = lerp(color, dustColor, dustMask);       // 混合基础色和灰尘颜色

                float darkMask = saturate((dustMask + _DarkOffset) * _DarkMul);
                darkMask = (1 - darkMask) * _DarkColor.a;

                color = lerp(color, _DarkColor, darkMask);      // 混合颜色和暗底颜色

                // -------------------------------------

                const float2 maskUV = TRANSFORM_TEX(input.uv, _MaskMap);
                const float alpha = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, maskUV).r * _BaseColor.a;
                color.a = alpha;
                color *= vertexColor;

                return color;
            }
            ENDHLSL
        }
    }
}
