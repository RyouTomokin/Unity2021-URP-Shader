 Shader "KIIF/Effect/ParallaxMapping"
{
    Properties
    {
        [HideInInspector] _AlphaCutoff("Alpha Cutoff ", Range(0, 1)) = 0.5
		_BaseColor("BaseColor", Color) = (1,1,1,1)
		[HDR]_EmissionColor("EmissionColor", Color) = (0,0,0,1)
		_ColorIntensity("ColorIntensity", Range( 0 , 10)) = 1
		_BaseMap("BaseMap", 2D) = "white" {}
		_ParallaxScale("ParrallaxScale", Float) = 0
		_HeightMap("HeightMap", 2D) = "white" {}
		_Dissolve("Dissolve", Range(0, 1)) = 0
//		[Toggle]_UseCustom1X("UseCustom1X", Float) = 0
		_DissolveMap("DissolveMap", 2D) = "white" {}
//		_StreamMap("StreamMap", 2D) = "white" {}
//		[HDR]_StreamColor("StreamColor", Color) = (0,0,0,1)
//		_StreamTiling("StreamTiling", Vector) = (1,1,0,0)

        [Space(20)]
        [Header(Stencil)]
        [Space]
        _RefValue("Ref Value",Int) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8      //默认Always
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep

//        [HideInInspector] _Surface("__surface", Float) = 0.0
//        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 0.0
        [HideInInspector] _Cull("__cull", Float) = 2.0
    }
    SubShader
    {
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "Queue" = "Transparent+50"}
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
                float4 uv                       : TEXCOORD0;
                half4 color                     : COLOR;

                float3 normalOS                 : NORMAL;
                float4 tangentOS                : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VaryingsUnlit
            {
                float4 positionCS               : SV_POSITION;
                half4 color                     : COLOR;
                float4 uv                       : TEXCOORD0;
                float3 viewDirWS                : TEXCOORD2;
                float3 normalWS                 : TEXCOORD3;
                float3 tangentWS                : TEXCOORD4;
                float3 bitangentWS              : TEXCOORD5;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _EmissionColor;
			float4 _BaseMap_ST;
			float4 _HeightMap_ST;
			float4 _DissolveMap_ST;
			// float4 _StreamTiling;
			// float4 _StreamColor;
			float4 _BaseColor;
			float _ParallaxScale;
			float _ColorIntensity;
			float _Dissolve;
            CBUFFER_END

            TEXTURE2D(_BaseMap);                SAMPLER(sampler_BaseMap);
            TEXTURE2D(_HeightMap);              SAMPLER(sampler_HeightMap);
            // TEXTURE2D(_StreamMap);              SAMPLER(sampler_StreamMap);
            TEXTURE2D(_DissolveMap);            SAMPLER(sampler_DissolveMap);

            VaryingsUnlit vert_Unlit(AttributesUnlit input)
            {
                VaryingsUnlit output = (VaryingsUnlit)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);


                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.viewDirWS = normalize(GetCameraPositionWS() - vertexInput.positionWS);
                output.normalWS = normalInput.normalWS;
                output.tangentWS = normalInput.tangentWS;
                output.bitangentWS = normalInput.bitangentWS;

                output.uv = input.uv;
                output.color = input.color;

                output.positionCS = vertexInput.positionCS;

                // -------------------------------------

                return output;
            }


            half4 frag_Unlit(VaryingsUnlit input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------

                float2 uv = input.uv.xy;
                float2 heightUV = TRANSFORM_TEX(uv, _HeightMap);
                float2 baseUV = TRANSFORM_TEX(uv, _BaseMap);
                half height = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, heightUV);
                float3 viewDirWS = input.viewDirWS;

                half3x3 TangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
                float3 viewDirTS = TransformWorldToTangent(viewDirWS, TangentToWorld);
                float2 Offset = (height - 1) * viewDirTS.xy * _ParallaxScale + baseUV;

                // 计算Parallax UV
                // -------------------------------------
                half baseAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV).a;
                float2 parallaxUV = Offset;
                half3 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, parallaxUV).rgb;

                // -------------------------------------
                half2 dissolveUV = uv * _DissolveMap_ST.xy + _DissolveMap_ST.zw * _Time.y;
                half2 dissolve = SAMPLE_TEXTURE2D(_DissolveMap, sampler_DissolveMap, dissolveUV).rg;    //dissolve和dissolveMask
                half dissolveFactor = input.uv.z + _Dissolve;
                dissolve = dissolve.r + (1 - dissolveFactor) * dissolve.g;
                dissolve -= lerp(-1, 1, dissolveFactor);
                dissolve = saturate(dissolve);

                // -------------------------------------
                half3 color = (_EmissionColor.rgb * baseColor + _BaseColor.rgb) * input.color.rgb * _ColorIntensity;
                half alpha = _BaseColor.a * input.color.a * baseAlpha * dissolve;

                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
}
