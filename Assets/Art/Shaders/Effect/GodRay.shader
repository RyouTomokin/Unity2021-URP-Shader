Shader "KIIF/GodRay"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        _MaskMap("遮罩图", 2D) = "white" {}
        _Width("宽度", Float) = 1.0
        _SpotMode("聚光灯模式", Range(0, 1)) = 0.0
        
        [Space(20)]
        [Toggle(_SOFTPARTICLES_ON)] _SoftParticlesEnabled("开启软粒子", Float) = 0.0
        _SoftParticle("软粒子", Range(0, 10)) = 1
        
        [Space(20)]
        [Header(Stencil)]
        [Space]
        _RefValue("Ref Value",Int) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8      //默认Always
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep
        
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
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
//            Blend SrcAlpha OneMinusSrcAlpha
            Blend SrcAlpha One
            Stencil
            {
                Ref [_RefValue]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }
            
            ZWrite[_ZWrite]
            Cull Back
            
            HLSLPROGRAM

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

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
            
            #pragma vertex vert_GodRay
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct AttributesGadRay
            {
                float4 positionOS               : POSITION;
                float2 uv                       : TEXCOORD0;
                half4 color                     : COLOR;
                
                float3 normalOS                 : NORMAL;
                float4 tangentOS                : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct VaryingsGodRay
            {
                float4 positionCS               : SV_POSITION;
                float2 uv                       : TEXCOORD0;
                half4 color                     : COLOR;
                
                float3 positionWS               : TEXCOORD2;
                float4 normalWS                 : TEXCOORD3;    // xyz: normal
                float4 tangentWS                : TEXCOORD4;    // xyz: tangent
                float4 bitangentWS              : TEXCOORD5;    // xyz: bitangent

                #if defined(_SOFTPARTICLES_ON) || defined(_FADING_ON) || defined(_DISTORTION_ON)
                    float4 projectedPosition: TEXCOORD6;
                #endif

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _BaseColor;
            float4 _BaseMap_ST;
            float4 _MaskMap_ST;
            half _Width;
            half _SpotMode;
            half _SoftParticle;
            CBUFFER_END

            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MaskMap);            SAMPLER(sampler_MaskMap);

            // 为了避免冗余计算，修改GetVertexPositionInputs
            VertexPositionInputs GetVertexPositionInputsFromWP(float3 worldPosition)
            {
                VertexPositionInputs input;
                input.positionWS = worldPosition;
                input.positionVS = TransformWorldToView(input.positionWS);
                input.positionCS = TransformWorldToHClip(input.positionWS);

                float4 ndc = input.positionCS * 0.5f;
                input.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
                input.positionNDC.zw = input.positionCS.zw;

                return input;
            }

            VaryingsGodRay vert_GodRay(AttributesGadRay input)
            {
                VaryingsGodRay output = (VaryingsGodRay)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.uv = input.uv;

                // -------------------------------------
                // GodRay顶点偏移
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 cameraPos = _WorldSpaceCameraPos;
                float3 cameraDir = normalize(cameraPos - positionWS);

                half3x3 TangentToWorld = half3x3(normalInput.tangentWS, normalInput.bitangentWS, normalInput.normalWS);
            	half3 TangentV = mul(half3(0,1,0), TangentToWorld);
                float3 offsetWP = cross(cameraDir, TangentV);
                output.color = half4(abs(offsetWP), 1);
                offsetWP = normalize(offsetWP);

                float3 scale = float3(  length(UNITY_MATRIX_M._11_21_31),
                                        length(UNITY_MATRIX_M._12_22_32),
                                        length(UNITY_MATRIX_M._13_23_33));

                float width = 0.5 - input.uv.x;
                width *= _Width;
                offsetWP *= width;
                //根据UV的V方向缩放位移宽度
                offsetWP *= lerp(1, input.uv.y, _SpotMode) ;

                offsetWP += input.uv.y * -scale.z * TangentV;
                //局部空间偏移到世界空间
                positionWS = offsetWP + UNITY_MATRIX_M._14_24_34;
                // positionWS += offsetWP;

                VertexPositionInputs vertexInput = GetVertexPositionInputsFromWP(positionWS);

                // -------------------------------------

                output.positionWS = vertexInput.positionWS;

                output.positionCS = vertexInput.positionCS;

                #if defined(_SOFTPARTICLES_ON) || defined(_FADING_ON) || defined(_DISTORTION_ON)
                output.projectedPosition = vertexInput.positionNDC;
                #endif
                
                return output;
            }
            half4 frag(VaryingsGodRay input) : SV_Target
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
                half3 albedo = albedoAlpha.r * _BaseColor.rgb;
                
                half4 color;
                
                color.a = alpha;

                // -------------------------------------
                // 软粒子
                #ifdef _SOFTPARTICLES_ON
                float fade = 1;
                    float rawDepth = SampleSceneDepth(input.projectedPosition.xy / input.projectedPosition.w).r;
                    float sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);
                    float thisZ = LinearEyeDepth(input.positionWS, GetWorldToViewMatrix());
                    fade = saturate((sceneZ - thisZ) / _SoftParticle);
                color.a *= fade;
                #endif

                // -------------------------------------
                
                color.rgb = albedo;
                return color;
            }
            ENDHLSL
        }
    }
}
