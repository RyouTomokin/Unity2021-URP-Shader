Shader "KIIF/Special/GlassBreak"
{
    Properties
    {
        [MainColor] [HDR] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [Toggle(_SCREENMAP_ON)] _ScreenMap_ON("使用ScreenMapRT", Float) = 0.0
        _ScreenMap("ScreenMap", 2D) = "white" {}
        
        _Break("破碎进程", Range(0, 1)) = 0.0
        _Stage01("阶段一", Range(0, 1)) = 0.4
        _Stage02("阶段二", Range(0, 1)) = 0.8
        _BreakIntensity("破碎强度", Float) = 0.0
        
//        [HideInInspector] _ZWrite("__zw", Float) = 0.0
        [Toggle] _ZWrite("深度写入", Float) = 0.0
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
            
            #pragma vertex vert_Unlit
            #pragma fragment frag_Unlit
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            struct AttributesUnlit
            {
                float4 positionOS               : POSITION;
                float2 uv0                      : TEXCOORD0;
                float2 uv1                      : TEXCOORD1;
                half4 color                     : COLOR;
                
                float3 normalOS                 : NORMAL;
                float4 tangentOS                : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct VaryingsUnlit
            {
                float4 positionCS               : SV_POSITION;
                float2 uv0                      : TEXCOORD0;
                float2 uv1                      : TEXCOORD1;
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

            float _Break;
            float _Stage01;
            float _Stage02;
            float _BreakIntensity;
            float _ScreenMap_ON;
            CBUFFER_END

            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_ScreenMap);          SAMPLER(sampler_ScreenMap);
            TEXTURE2D(_MaskMap);            SAMPLER(sampler_MaskMap);

            VaryingsUnlit vert_Unlit(AttributesUnlit input)
            {
                VaryingsUnlit output = (VaryingsUnlit)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                // Break Position Offset

                // 方向本应归一化，但不影响效果可以不处理
                const half2 uv_offset = input.uv1 - half2(0.5, 0.5);
                half uv_dis = distance(input.uv1, half2(0.5, 0.5));
                uv_dis += _Break - 1;
                uv_dis = saturate(uv_dis);
                const half2 uv_dir = uv_offset * uv_dis * _BreakIntensity;

                input.positionOS.xz += uv_dir;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                // VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.uv0 = input.uv0;
                output.uv1 = input.uv1;

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

                float2 baseUV = input.uv0;
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);

                // 破碎进程控制
                half uv_dis = distance(input.uv1, half2(0.5, 0.5));
                uv_dis += _Break - 1;
                uv_dis = step(HALF_MIN, uv_dis);

                // TODO:sceneColor应该是存储的的一个公共贴图，测试时临时使用OpaqueColor
                half3 sceneColor;
                UNITY_BRANCH
                if (_ScreenMap_ON > 0)
                {
                    sceneColor = SAMPLE_TEXTURE2D(_ScreenMap, sampler_ScreenMap, baseUV).rgb;
                }
                else
                {
                    sceneColor = SampleSceneColor(baseUV).rgb;
                }

                half3 color;
                color = sceneColor;

                // color += uv_dis * albedoAlpha.r * _BaseColor.rgb;
                half grassCrack = albedoAlpha.r * uv_dis;

                // 阶段一的破碎
                grassCrack += step(_Stage01, _Break) * albedoAlpha.g;
                // 阶段二的破碎
                grassCrack += step(_Stage02, _Break) * albedoAlpha.b;

                color += grassCrack * _BaseColor.rgb;
                
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}
