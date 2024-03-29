Shader "KIIF/Effect/Template"
{
    Properties
    {
        [MainColor][HDR] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0
        [Toggle] _SoftParticlesEnabled("__softparticlesenabled", Float) = 0.0
        _SoftParticle("软粒子", Range(0 , 10)) = 1
        _MoveToCamera("移向摄像机", Range(-20 , 20)) = 0
        
        [Enum(Alpha,0,Add,1)] _Blend("__mode", Float) = 0.0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("__cull", Float) = 2.0
        [Enum(Close,0,Open,1)] _DepthTest("深度测试", Float) = 1.0

        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZTest("_ZTest", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 0.0
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
            
            Blend [_SrcBlend][_DstBlend]
            Cull [_Cull]
            ZTest [_ZTest]
            Zwrite Off
            
            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            // #pragma shader_feature_local _NORMALMAP
            // #pragma shader_feature_local_fragment _EMISSION

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
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
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
                float4 clipPos                  : SV_POSITION;
                float2 texcoord                 : TEXCOORD0;
                half4 color                     : COLOR;
                float3 positionWS               : TEXCOORD5;

                #if defined(_SOFTPARTICLES_ON) || defined(_FADING_ON) || defined(_DISTORTION_ON)
                    float4 projectedPosition: TEXCOORD6;
                #endif

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            half _Cutoff;
            half _SoftParticle;
            half _MoveToCamera;
            CBUFFER_END

            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            // TEXTURE2D(_EmissionMap);        SAMPLER(sampler_EmissionMap);
            
            VaryingsParticle vert (AttributesParticle input)
            {
                VaryingsParticle output = (VaryingsParticle)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                //顶点向摄像机方向偏移，以实现显示到其他物体前的效果
                float3 cameraPositionOS = TransformWorldToObject(GetCameraPositionWS());
                float3 offsetPositionOS = input.positionOS.xyz + normalize(cameraPositionOS - input.positionOS.xyz) * _MoveToCamera;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(offsetPositionOS);
                // VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

            //     half fogFactor = 0.0;
            // #if !defined(_FOG_FRAGMENT)
            //     fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
            // #endif

                // position ws is used to compute eye depth in vertFading
                // output.positionWS.xyz = vertexInput.positionWS;
                // output.positionWS.w = fogFactor;
                output.clipPos = vertexInput.positionCS;
                // output.color = GetParticleColor(input.color);
                output.color = input.color;

                output.texcoord = TRANSFORM_TEX(input.texcoord, _BaseMap);

                output.positionWS = vertexInput.positionWS;
                #if defined(_SOFTPARTICLES_ON) || defined(_FADING_ON) || defined(_DISTORTION_ON)
                output.projectedPosition = vertexInput.positionNDC;
                #endif
                // #ifdef _SCREENPOSITION_ON
                // output.screenPos = vertexInput.positionNDC/output.clipPos.w;
                // #endif
                
                return output;
            }

            half4 frag (VaryingsParticle input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // 初始化粒子参数
                float2 uv = input.texcoord;
                float4 vertexColor = input.color;

                // 基础功能
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                color *= _BaseColor * vertexColor;
                clip(color.a - _Cutoff);
                
                // 软粒子
                #ifdef _SOFTPARTICLES_ON
                float fade = 1;
                if (_SoftParticle > 0.0)
                {
                    float rawDepth = SampleSceneDepth(input.projectedPosition.xy / input.projectedPosition.w).r;
                    float sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);
                    float thisZ = LinearEyeDepth(input.positionWS, GetWorldToViewMatrix());
                    fade = saturate((sceneZ - thisZ) / _SoftParticle);
                }
                color.a *= fade;
                #endif
                                
                return color;
            }
            ENDHLSL
        }
            
        // ------------------------------------------------------------------
        //  Depth Only pass.
//        Pass
//        {
//            Name "DepthOnly"
//            Tags{"LightMode" = "DepthOnly"}
//
//            ZWrite On
//            ColorMask 0
//            Cull[_Cull]
//
//            HLSLPROGRAM
//            #pragma target 2.0
//
//            // -------------------------------------
//            // Material Keywords
//            #pragma shader_feature_local _ _ALPHATEST_ON
//            #pragma shader_feature_local _ _FLIPBOOKBLENDING_ON
//            #pragma shader_feature_local_fragment _ _COLOROVERLAY_ON _COLORCOLOR_ON _COLORADDSUBDIFF_ON
//
//            // -------------------------------------
//            // Unity defined keywords
//            #pragma multi_compile_instancing
//            #pragma instancing_options procedural:ParticleInstancingSetup
//
//            #pragma vertex DepthOnlyVertex
//            #pragma fragment DepthOnlyFragment
//
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/Particles/ParticlesUnlitInput.hlsl"
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/Particles/ParticlesDepthOnlyPass.hlsl"
//            ENDHLSL
//        }
        
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
    CustomEditor "Effect_ShaderGUI"
}
