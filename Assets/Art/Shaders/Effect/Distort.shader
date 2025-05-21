Shader "KIIF/Effect/Distort"
{
    Properties
    {
        [MainColor][HDR] _BaseColor("Color", Color) = (1,1,1,1)
        _Brighten("提亮", Range(0, 5)) = 1
        [Toggle] _SelfMask("自我遮罩", Float) = 0
        [Toggle] _BaseUVByCustomOn("启用自定义UV(UV1.xy)", Float) = 1.0
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        _MainSpeed("主贴图流动速度", Vector) = (0,0,0,0)
        [Toggle] _MainClampEnabled("__mainclamp", Float) = 0.0
        _MainClamp("主贴图Clamp", Vector) = (0,0,1,1)
        
        _DetailMap("细节纹理", 2D) = "white" {}
        
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0
        [Toggle] _SoftParticlesEnabled("__softparticlesenabled", Float) = 0.0
        _SoftParticle("软粒子", Range(0, 10)) = 1
        _MoveToCamera("移向摄像机", Range(-20 , 20)) = 0
        
        _TwistSpeed("扭曲流动速度", Float) = 0
        _TwistMap("扭曲贴图(offset为流动方向)", 2D) = "white" {}
        [Enum(Twist,0,Flow,1)] _TwistMode("__twistmode", Float) = 0.0
        [Toggle] _TwistByCustomOn("启用自定义扭曲(UV0.w)", Float) = 1.0
        _TwistStrength("扭曲强度", Float) = 0
        
        [Toggle] _FlowMapEnabled("__flowmapenabled", Float) = 0.0
        _FlowMap("FlowMap", 2D) = "white" {}
        _FlowStrength("Flow(RG:Strength B:Speed)", Vector) = (0.1,0.1,0,0)
        
        _MaskMap("遮罩图", 2D) = "white" {}
        _MaskTwistStrength("遮罩图被扭曲的强度", Range(0 , 1)) = 0
        _MaskSoft("遮罩图软硬", Range( 1 , 10)) = 1
        
        [Toggle] _DissolveEnabled("_dissolveenabled", Float) = 1.0
        _DissolveMode("轴向溶解模式", Range(0, 1)) = 0
        _DissolveMaskMap("溶解的遮罩贴图", 2D) = "black" {}
        _DissolveMaskSharpen("溶解遮罩渐变范围", Range(0.0, 0.5)) = 0
        _DissolveSpeed("溶解流动速度", Float) = 0
        [Toggle] _DissolveByCustomOn("启用自定义溶解(UV0.z)", Float) = 1.0
        _Dissolve("溶解进度", Range(0.0, 1.0)) = 0
        _DissolveMap("溶解贴图", 2D) = "white" {}
        _DissolveSharpen("溶解硬度(最小值为1)", Range(1, 20)) = 1
        [HDR] _DissolveSideColor("溶解边缘颜色", Color) = (0,0,0,1)
        _DissolveSideWidth("溶解边缘宽度", Float) = 0
        [HDR] _DissolveInsideColor("溶解内部颜色", Color) = (0,0,0,1)
        _DissolveInsideWidth("溶解内部范围", Float) = 0
        _DissolveInsideSoft("溶解内部硬度", Float) = 0
        
        [Toggle] _VertexAnimEnabled("__vertexanimenabled", Float) = 0.0
        _VertexMap("顶点动画贴图", 2D) = "white" {}
        [Toggle] _VertexByCustomOn("启用自定义顶点动画(UV1.z)", Float) = 0.0
        _VertexStrength("顶点位移强度", Float) = 0
        
        [Enum(Alpha,0,Add,1)] _Blend("__mode", Float) = 0.0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("__cull", Float) = 2.0
        [Enum(Close,0,Open,1)] _DepthTest("深度测试", Float) = 1.0

        [HideInInspector] _SrcBlend("__src", Float) = 5.0
        [HideInInspector] _DstBlend("__dst", Float) = 10.0
        [HideInInspector] _ZTest("_ZTest", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 0.0
    }
    SubShader
    {
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "Queue" = "Transparent+50"}
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
            #pragma multi_compile_instancing
            #pragma target 2.0

            #pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _FLOWMAP_ON
            #pragma shader_feature_local_fragment _DISSOLVE_ON
            #pragma shader_feature_local_vertex _VERTEXANIM_ON
            // #pragma shader_feature_local _NORMALMAP
            // #pragma shader_feature_local_fragment _EMISSION

            // -------------------------------------
            // Particle Keywords
            #pragma shader_feature_local _SOFTPARTICLES_ON
            // #pragma shader_feature_local_fragment _ _ALPHAPREMULTIPLY_ON _ALPHAMODULATE_ON
            #pragma shader_feature_local_fragment _ _COLOROVERLAY_ON _COLORCOLOR_ON _COLORADDSUBDIFF_ON

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog
            // #pragma multi_compile_instancing
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
            #include "Assets/Art/Shaders/Library/KIIFCommon.hlsl"

            struct AttributesParticle
            {
                float4 positionOS               : POSITION;
                float3 normalOS                 : NORMAL;
                half4 color                     : COLOR;
                float4 texcoord0                : TEXCOORD0;
                float4 texcoord1                : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VaryingsParticle
            {
                float4 clipPos                  : SV_POSITION;
                float4 texcoord0                : TEXCOORD0;
                float4 texcoord1                : TEXCOORD1;
                half4 color                     : COLOR;
                float3 positionWS               : TEXCOORD5;

                #if defined(_SOFTPARTICLES_ON) || defined(_FADING_ON) || defined(_DISTORTION_ON)
                    float4 projectedPosition: TEXCOORD6;
                #endif

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            half _BaseUVByCustomOn;
            float4 _BaseMap_ST;
            float4 _DetailMap_ST;
            float _Brighten;
            float _SelfMask;
            float2 _MainSpeed;
            half _MainClampEnabled;
            float4 _MainClamp;
            half4 _BaseColor;
            half _Cutoff;

            float4 _FlowMap_ST;
            float4 _FlowStrength;

            float4 _TwistMap_ST;
            half _TwistSpeed;
            half _TwistMode;
            half _TwistByCustomOn;
            half _TwistStrength;

            float4 _MaskMap_ST;
            half _MaskTwistStrength;
            half _MaskSoft;

            float _DissolveMode;
            float4 _DissolveMaskMap_ST;
            half _DissolveMaskSharpen;
            float4 _DissolveMap_ST;
            half _DissolveByCustomOn;
            half _Dissolve;
            half _DissolveSpeed;
            half _DissolveSideWidth;
            half _DissolveInsideWidth;
            half _DissolveSharpen;
            half4 _DissolveSideColor;
            half4 _DissolveInsideColor;
            half _DissolveInsideSoft;

            float4 _VertexMap_ST;
            half _VertexByCustomOn;
            float  _VertexStrength;
            
            half _SoftParticle;
            half _MoveToCamera;
            CBUFFER_END

            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_DetailMap);          SAMPLER(sampler_DetailMap);
            TEXTURE2D(_TwistMap);           SAMPLER(sampler_TwistMap);
            TEXTURE2D(_FlowMap);            SAMPLER(sampler_FlowMap);
            TEXTURE2D(_MaskMap);            SAMPLER(sampler_MaskMap);
            TEXTURE2D(_DissolveMaskMap);    SAMPLER(sampler_DissolveMaskMap);
            TEXTURE2D(_DissolveMap);        SAMPLER(sampler_DissolveMap);
            TEXTURE2D(_VertexMap);          SAMPLER(sampler_VertexMap);

            
            
            VaryingsParticle vert (AttributesParticle input)
            {
                VaryingsParticle output = (VaryingsParticle)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                output.texcoord0 = input.texcoord0;
                output.texcoord1 = input.texcoord1;

                //顶点向摄像机方向偏移，以实现显示到其他物体前的效果
                float3 cameraPositionOS = TransformWorldToObject(GetCameraPositionWS());
                float3 offsetPositionOS = input.positionOS.xyz + normalize(cameraPositionOS - input.positionOS.xyz) * _MoveToCamera;

                #ifdef _VERTEXANIM_ON
                float2 vertexUV = input.texcoord0.xy * _VertexMap_ST.xy + _VertexMap_ST.zw * _Time.y;
                float vertexMap = SAMPLE_TEXTURE2D_LOD(_VertexMap, sampler_VertexMap, vertexUV, 0).r;
                float3 vertexOffsetOS =  input.normalOS * vertexMap * ((_VertexByCustomOn>0.5) ? input.texcoord1.z : _VertexStrength);
                offsetPositionOS += vertexOffsetOS; 
                #endif
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(offsetPositionOS);

                output.clipPos = vertexInput.positionCS;
                #if defined(UNITY_PARTICLE_INSTANCING_ENABLED)
                #if !defined(UNITY_PARTICLE_INSTANCE_DATA_NO_COLOR)
                    UNITY_PARTICLE_INSTANCE_DATA data = unity_ParticleInstanceData[unity_InstanceID];
                    input.color = lerp(half4(1.0, 1.0, 1.0, 1.0), input.color, unity_ParticleUseMeshColors);
                    input.color *= half4(UnpackFromR8G8B8A8(data.color));
                #endif
                #endif
                output.color = input.color;

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
                float2 uv = input.texcoord0.xy;
                float4 vertexColor = input.color;
                
                // 扭曲
                half2 twistUV = uv * _TwistMap_ST.xy + _TwistSpeed * _TwistMap_ST.zw * _Time.y;
                half2 twist = SAMPLE_TEXTURE2D(_TwistMap, sampler_TwistMap, twistUV).rg;
                // twist = (twist - 0.5) * 2;
                // twist *= (_TwistByCustomOn>0.5f ? input.texcoord0.w : _TwistStrength);
                float twistFact = (_TwistByCustomOn>0.5f ? input.texcoord0.w : _TwistStrength);

                // FlowMap
                #ifdef _FLOWMAP_ON   
                float2 flowUV = uv * _FlowMap_ST.xy + _Time.y * _FlowMap_ST.zw;
                half2 flowDirection = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, flowUV).xy;
                #endif

                // 基础功能
                float2 baseUV = uv + (_BaseUVByCustomOn>0.5f ? input.texcoord1.xy : 0);
                // baseUV += twist;                                            //把扭曲提前
                // baseUV = _TwistMode ? lerp(baseUV, twist, twistFact) : baseUV + twist * twistFact;
                baseUV = lerp(baseUV, twist, twistFact) * _TwistMode +
                    (baseUV + twist * twistFact) * (1 - _TwistMode);            // _TwistMode为0或1
                
                const float2 baseUVTwisted = baseUV;
                // half2 clampAlpha = step(_MainClamp.xy, baseUV.xy);      //UV硬切
                // clampAlpha *= step(baseUV.xy, _MainClamp.zw);
                baseUV = max(baseUV, _MainClamp.xy);                        //UV限制
                baseUV = min(baseUV, _MainClamp.zw);
                baseUV = lerp(baseUVTwisted, baseUV, _MainClampEnabled);    //是否开启UV Clamp
                // clampAlpha = lerp(1, clampAlpha, _MainClampEnabled);    //是否开启UV Clamp
                baseUV = TRANSFORM_TEX(baseUV, _BaseMap);
                baseUV += _Time.y * _MainSpeed.xy;
                #ifdef _FLOWMAP_ON                
                half4 color = Flow(TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap), baseUV, flowDirection,
                    _FlowStrength.xy, _FlowStrength.z);
                #else
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);
                #endif
                color.a *= lerp(1, color.r, _SelfMask);
                color.rgb = pow(abs(color.rgb), _Brighten) * _Brighten * _Brighten;  //提亮贴图的颜色
                color.rgb *= SAMPLE_TEXTURE2D(_DetailMap, sampler_DetailMap, TRANSFORM_TEX(uv, _DetailMap)).rgb;
                color *= _BaseColor * vertexColor;

                // color.a *= clampAlpha.x * clampAlpha.y;
                clip(color.a - _Cutoff);

                // 溶解
                half2 dissolveMaskUV = TRANSFORM_TEX(uv, _DissolveMaskMap);
                // dissolveMaskUV = _TwistMode ? lerp(dissolveMaskUV, twist, twistFact) : dissolveMaskUV + twist * twistFact;
                dissolveMaskUV = lerp(dissolveMaskUV, twist, twistFact) * _TwistMode +
                    (dissolveMaskUV + twist * twistFact) * (1 - _TwistMode);        // _TwistMode为0或1
                half dissolveMask = SAMPLE_TEXTURE2D(_DissolveMaskMap, sampler_DissolveMaskMap, dissolveMaskUV).r;

                // dissolveMask = saturate((dissolveMask - 0.5) * dissolveMaskSoft + dissolveMaskRange);

                // half2 dissolveUV = uv * _DissolveMap_ST.xy + _DissolveSpeed * _DissolveMap_ST.zw * _Time.y + twist;  // 旧版扭曲
                half2 dissolveUV = uv * _DissolveMap_ST.xy;
                // dissolveUV = _TwistMode ? lerp(dissolveUV, twist, twistFact) : dissolveUV + twist * twistFact;
                dissolveUV = lerp(dissolveUV, twist, twistFact) * _TwistMode +
                    (dissolveUV + twist * twistFact) * (1 - _TwistMode);        // _TwistMode为0或1
                dissolveUV += _DissolveSpeed * _DissolveMap_ST.zw * _Time.y;    // 使流动作用于扭曲之后
                half dissolve = SAMPLE_TEXTURE2D(_DissolveMap, sampler_DissolveMap, dissolveUV).r;

                half dissolveFactor = (_DissolveByCustomOn>0.5f ? input.texcoord0.z : _Dissolve);

                //溶解方案1
                half dissolveMask_1 = lerp(0 - _DissolveMaskSharpen, 1 + _DissolveMaskSharpen, dissolveMask);
                dissolveMask_1 -= lerp(-1, 1, dissolveFactor);
                dissolveMask_1 = (dissolveMask_1 - _DissolveMaskSharpen) / (1 - 2 * _DissolveMaskSharpen);
                dissolveMask_1 = saturate(dissolveMask_1);

                half dissolve_1 = lerp(0, 1, dissolve);
                dissolve_1 += dissolveMask_1;
                dissolve_1 *= dissolveMask_1;

                //溶解方案2
                half dissolve_2 = saturate(dissolve + (1 - dissolveFactor) * dissolveMask);
                // float dissolve_2 = saturate(lerp(dissolve,dissolveMask,dissolve) + (1 - dissolveFactor) * dissolveMask);
                dissolve_2 -= lerp(-1, 1, dissolveFactor);

                // //溶解方案3
                // half dissolve_3 = dissolve;
                // // dissolve_3 -= lerp(0, 1, dissolveFactor);
                // half3 dissolveMask_3 = lerp(0, 1, dissolveMask);
                // dissolve_3 += dissolveMask_3;
                // dissolve_3 *= dissolveMask_3;
                //
                // //溶解方案Debug
                // dissolve = uv.y>0.333 ? dissolve_2:dissolve_1;
                // dissolve = uv.y>0.666 ? dissolve_3:dissolve;
                
                //溶解模式切换
                dissolve = lerp(dissolve_2, dissolve_1, _DissolveMode);
                
                half dissolveSide = step(0, dissolve) - step(_DissolveSideWidth, dissolve);
                // half dissolveSide = 1 - saturate(_DissolveSideWidth - dissolve)/_DissolveSideWidth - step(_DissolveSideWidth, dissolve);
                dissolve = (dissolve - 0.5) * _DissolveSharpen + 0.5;           //溶解边缘锐化
                dissolve = lerp(dissolve, step(0.5, dissolve), step(19.9, _DissolveSharpen));   //硬度过大直接硬溶解
                // dissolve = clamp(dissolve, 0, 2);

                // color.rgb = clamp(dissolve - _DissolveInsideWidth,0,100);
                // color.a = 1;
                // return color;
                half dissolveInside = smoothstep(dissolve - _DissolveInsideWidth, dissolve - _DissolveInsideWidth - 1 / _DissolveInsideSoft, 1);

                half3 dissolveSideColor = dissolveSide * _DissolveSideColor.rgb;
                color.a *= saturate(dissolve);
                color.rgb = lerp(color.rgb, _DissolveInsideColor.rgb * vertexColor.rgb, dissolveInside);
                color.rgb += dissolveSideColor;

                // 遮罩
                float2 maskuv = TRANSFORM_TEX(uv, _MaskMap) + twist * _MaskTwistStrength;
                half mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, maskuv).r;
                mask = saturate((mask - 0.5) * _MaskSoft + 0.5);
                color.a *= mask;
                
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
    CustomEditor "Effect_Distort_ShaderGUI"
    Fallback "Hidden/InternalErrorShader"
}

