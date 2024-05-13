Shader "KIIF/Effect/EffectDecal"
{
    Properties
    {
        [MainColor][HDR] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0
        
        [Enum(Alpha,10,Add,1)] _Blend("Blend Mode", Int) = 0
//        [Enum(UnityEngine.Rendering.CullMode)] _Cull("__cull", Float) = 2.0
//        [Enum(Close,0,Open,1)] _DepthTest("深度测试", Float) = 1.0
        
        [HDR] _EmissionColor("自发光颜色", Color) = (0,0,0)
        _EmissionStrength("自发光强度", Range(0.0, 1.0)) = 0.0

        [Space(20)]
        [Header(Stencil)]
        [Space]
        _RefValue("Ref Value",Int) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 5      //默认Greater
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep
//        [HideInInspector] _SrcBlend("__src", Float) = 1.0
//        [HideInInspector] _DstBlend("__dst", Float) = 0.0
//        [HideInInspector] _ZTest("_ZTest", Float) = 0.0
//        [HideInInspector] _ZWrite("__zw", Float) = 0.0
    }
    SubShader
    {
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "Queue" = "Transparent"}
        LOD 100

        // ------------------------------------------------------------------
        //  Forward pass.
        Pass
        {
            Name "ForwardLit"
            
            Blend SrcAlpha [_Blend]
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
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords

            // -------------------------------------
            // Particle Keywords
            #pragma shader_feature_local _SOFTPARTICLES_ON
            #pragma shader_feature_local_fragment _ _ALPHAPREMULTIPLY_ON _ALPHAMODULATE_ON
            #pragma shader_feature_local_fragment _ _COLOROVERLAY_ON _COLORCOLOR_ON _COLORADDSUBDIFF_ON

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            #pragma instancing_options procedural:ParticleInstancingSetup       //粒子Shader必备
            
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ParticlesInstancing.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct AttributesParticle
            {
                float4 positionOS               : POSITION;
                half4 color                     : COLOR;
                float2 texcoord                 : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VaryingsParticle
            {
                float2 texcoord                 : TEXCOORD0;
                half4 color                     : COLOR;        
                
                // DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

                float3 positionWS               : TEXCOORD2;

                // #ifdef _NORMALMAP
                // float4 normalWS                 : TEXCOORD3;    // xyz: normal, w: viewDir.x
                // float4 tangentWS                : TEXCOORD4;    // xyz: tangent, w: viewDir.y
                // float4 bitangentWS              : TEXCOORD5;    // xyz: bitangent, w: viewDir.z
                // #else
                // float3 normalWS                 : TEXCOORD3;
                // float3 viewDirWS                : TEXCOORD4;
                // #endif

                #if defined(_SOFTPARTICLES_ON) || defined(_FADING_ON) || defined(_DISTORTION_ON)
                    float4 projectedPosition: TEXCOORD6;
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                float4 shadowCoord              : TEXCOORD7;
                #endif
                #ifdef _SCREENPOSITION_ON
                float4 screenPos                : TEXCOORD8;
                #endif

                float4 positionCS               : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            half _Cutoff;
            float3 _EmissionColor;
            half _EmissionStrength;
            CBUFFER_END

            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            
            VaryingsParticle vert (AttributesParticle input)
            {
                VaryingsParticle output = (VaryingsParticle)0;
            
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
            
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                
                // position ws is used to compute eye depth in vertFading
                output.positionWS = vertexInput.positionWS;
                output.positionCS = vertexInput.positionCS;
                // output.color = GetParticleColor(input.color);
                #if defined(UNITY_PARTICLE_INSTANCING_ENABLED)
                #if !defined(UNITY_PARTICLE_INSTANCE_DATA_NO_COLOR)
                    UNITY_PARTICLE_INSTANCE_DATA data = unity_ParticleInstanceData[unity_InstanceID];
                    input.color = lerp(half4(1.0, 1.0, 1.0, 1.0), input.color, unity_ParticleUseMeshColors);
                    input.color *= half4(UnpackFromR8G8B8A8(data.color));
                #endif
                #endif
                output.color = input.color;
            
                output.texcoord = TRANSFORM_TEX(input.texcoord, _BaseMap);
            
                #if defined(_SOFTPARTICLES_ON) || defined(_FADING_ON) || defined(_DISTORTION_ON)
                output.projectedPosition = vertexInput.positionNDC;
                #endif
                
                return output;
            }

            half4 frag (VaryingsParticle input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------
                // 初始化粒子参数
                
                // 要计算用于采样深度缓冲区的 UV 坐标，
                // 请将像素位置除以渲染目标分辨率
                // _ScaledScreenParams。
                float2 screenUV = input.positionCS.xy / _ScaledScreenParams.xy;
                // 从摄像机深度纹理中采样深度。
                #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(screenUV);
                #else
                    //  调整 Z 以匹配 OpenGL 的 NDC ([-1, 1])
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif
                float4 vertexColor = input.color;

                // -------------------------------------
                // 重建世界空间位置。
                float3 worldPos = ComputeWorldSpacePosition(screenUV, depth, UNITY_MATRIX_I_VP);
                // 剔除之外的像素
                float3 localPos = mul(unity_WorldToObject, float4(worldPos,1)).xyz;
                clip(0.5 - abs(localPos));
                // 贴花UV
                float2 decalUV = localPos.xz + 0.5;
                decalUV = decalUV * _BaseMap_ST.xy + _BaseMap_ST.zw;
                // 用重建的世界坐标计算阴影UV
                // input.positionWS = worldPos;

                // -------------------------------------
                // 基础功能
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, decalUV);
                color *= _BaseColor * vertexColor;
                clip(color.a - _Cutoff);

                // -------------------------------------
                color.rgb += _EmissionColor * _EmissionStrength;
                color.a *= smoothstep(0.5, 0.4, abs(localPos.y));
                                
                return color;
            }
            ENDHLSL
        }
            
        
        // ------------------------------------------------------------------
        //  Scene view outline pass.
        Pass
        {
            Name "SceneSelectionPass"
            Tags { "LightMode" = "SceneSelectionPass" }

            BlendOp Add
            Blend One Zero
            ZWrite On
            Cull Off

            HLSLPROGRAM
            #define PARTICLES_EDITOR_META_PASS
            #pragma target 2.0

            // -------------------------------------
            // Particle Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local _FLIPBOOKBLENDING_ON

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:ParticleInstancingSetup

            #pragma vertex vertParticleEditor
            #pragma fragment fragParticleSceneHighlight

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Particles/ParticlesUnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Particles/ParticlesEditorPass.hlsl"

            ENDHLSL
        }
        
        // ------------------------------------------------------------------
        //  Scene picking buffer pass.
        Pass
        {
            Name "ScenePickingPass"
            Tags{ "LightMode" = "Picking" }

            BlendOp Add
            Blend One Zero
            ZWrite On
            Cull Off

            HLSLPROGRAM
            #define PARTICLES_EDITOR_META_PASS
            #pragma target 2.0

            // -------------------------------------
            // Particle Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local _FLIPBOOKBLENDING_ON

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:ParticleInstancingSetup

            #pragma vertex vertParticleEditor
            #pragma fragment fragParticleScenePicking

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Particles/ParticlesUnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Particles/ParticlesEditorPass.hlsl"

            ENDHLSL
        }
    }
//    CustomEditor "Effect_ShaderGUI"
}
