Shader "KIIF/Skill_Indicator"
{
    Properties
    {
        [Header(Base)]
        [HDR][MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [PowerSlider(2)] _HideAlpha("HideAlpha", Range(0, 1)) = 0.2
        _CircleFade("CircleFade", Range(0.01, 1)) = 0
        _FadeOffset("FadeOffset", Range(0, 1)) = 0
        [MainTexture] _BaseMap("遮罩:R扇形 G流动 B指示器 A Alpha", 2D) = "white" {}
        _Intensity("Intensity", float) = 1
        
        [Header(Sector)]
        [MaterialToggle] _Sector("Sector", Float) = 1
        _Angle ("Angle", Range(0, 360)) = 60
        _Outline ("Outline", Range(0, 5)) = 0.35
        _OutlineAlpha("Outline Alpha",Range(0,1))=0.5
        [MaterialToggle] _Indicator("Indicator", Float) = 1
        
        [Header(Flow)]
        _FlowColor("Flow Color",color) = (1,1,1,1)
        _FlowFade("Fade",range(0,1)) = 1
        _Duration("Duration",range(0,1)) = 0

        [Header(Blend)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("SrcBlend", Int) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("DstBlend", Int) = 10
        
        
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
            
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            ZTest Off
            Cull [_Cull]
            
            HLSLPROGRAM

            // #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma multi_compile __ _INDICATOR_ON
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
                
                // float3 normalOS                 : NORMAL;
                // float4 tangentOS                : TANGENT;
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
                float3 positionWS               : TEXCOORD5;
                float4 projectedPosition        : TEXCOORD6;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _BaseColor;
            float4 _BaseMap_ST;
            float _HideAlpha;
            float _CircleFade;
            float _FadeOffset;
            half _Intensity;
            
            float _Angle;
            half _Sector;
            half _Outline;
            half _OutlineAlpha;
            
            half4 _FlowColor;
            half _FlowFade;
            half _Duration;
            CBUFFER_END

            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);

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
                output.positionWS = vertexInput.positionWS;
                output.projectedPosition = vertexInput.positionNDC;

                // -------------------------------------
                
                return output;
            }
            half4 frag_Unlit(VaryingsUnlit input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------
                // 采样

                float2 baseUV = input.uv * _BaseMap_ST.xy + _BaseMap_ST.zw * _Time.y ;
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);

                half4 color;
                // half4 color = albedoAlpha * _BaseColor * _Intensity;

                // -------------------------------------
                // 指示器
                #if _INDICATOR_ON
                    return baseMap.b * 0.6 * _BaseColor;
                #endif

                float2 centerUV = input.uv * 2 - 1;
                float atan2UV = 1-abs(atan2(centerUV.g, centerUV.r)/3.14);

                half centerFade = distance(input.uv, half2(0.5, 0.5)) * 2;
                centerFade -= _FadeOffset;
                centerFade *= rcp(max(0.01 ,_CircleFade));
                centerFade = saturate(centerFade);

                half sector = lerp(1.0, 1.0 - ceil(atan2UV - _Angle*0.002777778), _Sector);
                half sectorBig = lerp(1.0, 1.0 - ceil(atan2UV - (_Angle+ _Outline) * 0.002777778), _Sector);
                half outline = (sectorBig - sector) * baseMap.g * _OutlineAlpha;

                half needOutline = 1 - step(359, _Angle);
                outline *= needOutline;
                color = baseMap.r * _BaseColor * sector + outline * _BaseColor;

                half flowCircleInner = smoothstep(_Duration - _FlowFade, _Duration, length(centerUV));
                half flowCircleMask = step(length(centerUV), _Duration);
                half4 flow = flowCircleInner * flowCircleMask * _FlowColor * baseMap.g * sector;

                color += flow;

                color *= centerFade;

                // -------------------------------------
                // 软粒子
                float2 screenUV = input.positionCS.xy / _ScaledScreenParams.xy;
                float rawDepth = SampleSceneDepth(screenUV).r;
                float sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);
                float thisZ = LinearEyeDepth(input.positionWS, GetWorldToViewMatrix());
                // color.a = sceneZ > thisZ ? color.a : color.a * _HideAlpha;
                color.rgb *= lerp(1, _HideAlpha, step(sceneZ - thisZ, 0)); 

                // -------------------------------------
                color.a *= baseMap.a;
                return color;
            }
            ENDHLSL
        }
    }
}
