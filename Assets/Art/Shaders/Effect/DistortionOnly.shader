Shader "KIIF/Effect/DistortionOnly"
{
    Properties
    {
        [HideInInspector][MainColor][HDR] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Height(Custom1.xy:Offset,custom1.z:Strength)", 2D) = "white" {}
        _MainSpeed("主贴图流动速度", Vector) = (0,0,0,0)
        
        _DistortStrength("DistortStrength", float) = 1
//        [Toggle] _SOFTPARTICLES("开启软粒子", Float) = 0.0
//        _SoftParticle("软粒子", Range(0 , 10)) = 1
        _MoveToCamera("移向摄像机", Range(-20 , 20)) = 0
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
            
            Blend SrcAlpha OneMinusSrcAlpha
            ZTest LEqual
            Zwrite Off
            
            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            // #pragma shader_feature_local _NORMALMAP
            // #pragma shader_feature_local_fragment _EMISSION

            // -------------------------------------
            // Particle Keywords
            // #pragma shader_feature_local _SOFTPARTICLES_ON

            // -------------------------------------
            // Unity defined keywords
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            struct AttributesParticle
            {
                float4 positionOS               : POSITION;
                float3 normalOS                 : NORMAL;
                half4  color                    : COLOR;
                float2 texcoord                 : TEXCOORD0;
                float3 texcoord1                : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VaryingsParticle
            {
                float4 clipPos                  : SV_POSITION;
                half4  color                    : COLOR;
                float2 texcoord                 : TEXCOORD0;
                float3 texcoord1                : TEXCOORD1;
                float3 normalWS                 : TEXCOORD2;
                float3 positionWS               : TEXCOORD3;
                float4 screenPos                : TEXCOORD4;

                #if defined(_SOFTPARTICLES_ON) || defined(_FADING_ON) || defined(_DISTORTION_ON)
                    float4 projectedPosition: TEXCOORD6;
                #endif

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            half4 _MainSpeed;
            // half _Cutoff;
            half _DistortStrength;
            half _SoftParticle;
            half _MoveToCamera;
            CBUFFER_END

            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            
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
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.clipPos = vertexInput.positionCS;
                // output.color = GetParticleColor(input.color);
                #if defined(UNITY_PARTICLE_INSTANCING_ENABLED)
                #if !defined(UNITY_PARTICLE_INSTANCE_DATA_NO_COLOR)
                    UNITY_PARTICLE_INSTANCE_DATA data = unity_ParticleInstanceData[unity_InstanceID];
                    input.color = lerp(half4(1.0, 1.0, 1.0, 1.0), input.color, unity_ParticleUseMeshColors);
                    input.color *= half4(UnpackFromR8G8B8A8(data.color));
                #endif
                #endif
                output.color = input.color;

                // output.texcoord = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.texcoord = input.texcoord;
                output.texcoord1 = input.texcoord1;

                output.screenPos = vertexInput.positionNDC/output.clipPos.w;

                output.positionWS = vertexInput.positionWS;
                #if defined(_SOFTPARTICLES_ON) || defined(_FADING_ON) || defined(_DISTORTION_ON)
                output.projectedPosition = vertexInput.positionNDC;
                #endif
                
                return output;
            }

            half4 frag (VaryingsParticle input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // 初始化粒子参数
                float2 uv = input.texcoord.xy;
                float2 uvOffset = input.texcoord1.xy;
                float2 baseUV = uv * _BaseMap_ST.xy + uvOffset + _BaseMap_ST.zw + _MainSpeed.xy * _Time.y;
                float4 vertexColor = input.color;
                half   distortStrength = _DistortStrength * input.texcoord1.z;
                
                half4 color = _BaseColor * vertexColor;

                // 基础功能
                half H = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV).r;

                // 热扭曲
                float3 V = normalize(GetCameraPositionWS() - input.positionWS);
                float3 N = normalize(input.normalWS);
                float3 R = cross(N, V);
                float3 D = cross(R, V);
                float3 VR = cross(float3(0, 1, 0), V);
                float3 VU = normalize(cross(V, VR));
                VR = cross(VU, V);
                float2 offset = float2(dot(D, VR), -dot(D, VU)) * (_ScreenParams.zw - 1);
                offset *= (_ProjectionParams.z * input.screenPos.z) * distortStrength * H;

                // 屏幕边缘
                half2 screenSide = 1 - abs(input.screenPos.xy - 0.5) * 2;
                half sideTest = screenSide.x * screenSide.y;
                
                // 遮罩
                half2 uvArea = 1 - abs(uv * 2 - 1);
                half mask = smoothstep(0, 0.2, uvArea.x * uvArea.y);
                
                offset *= mask * sideTest;
                
                //用input.clipPos.xy / _ScaledScreenParams.xy代替input.screenPos.xy能得到更精确的屏幕UV
                float2 distortUV = input.clipPos.xy / _ScaledScreenParams.xy + offset;
                color.rgb *= SampleSceneColor(distortUV);
                
                // 软粒子
                // #ifdef _SOFTPARTICLES_ON
                // float fade = 1;
                // if (_SoftParticle > 0.0)
                // {
                //     float rawDepth = SampleSceneDepth(input.projectedPosition.xy / input.projectedPosition.w).r;
                //     float sceneZ = (unity_OrthoParams.w == 0) ? LinearEyeDepth(rawDepth, _ZBufferParams) : LinearDepthToEyeDepth(rawDepth);
                //     float thisZ = LinearEyeDepth(input.positionWS, GetWorldToViewMatrix());
                //     fade = saturate((sceneZ - thisZ) / _SoftParticle);
                // }
                // color.a *= fade;
                // #endif
                                
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
//    CustomEditor "Effect_ShaderGUI"
}
