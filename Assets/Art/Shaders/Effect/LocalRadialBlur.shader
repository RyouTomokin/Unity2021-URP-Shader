Shader "KIIF/Effect/LocalRadialBlur"
{
    Properties
    {
        _RadialStrength("径向模糊强度", Float) = 1
        _DispersionStrength("色散强度", Float) = 1
        
        _SphereMaskRadius("遮罩半径", Range(0, 0.5)) = 0.25
        _SphereMaskHardness("遮罩硬度", Range(0.5, 1)) = 0.8
        
        [Space]
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("Depth Test",Int) = 8
    }
    SubShader
    {
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "Queue" = "Transparent"}
        LOD 100

        // ------------------------------------------------------------------
        //  Forward pass.
        Pass
        {
            Name "LocalRadial"
            
            Blend SrcAlpha OneMinusSrcAlpha
            ZTest [_ZTest]
            Zwrite Off
            
            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            // #define _SCREENPOSITION_ON

            // -------------------------------------
            // Particle Keywords
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            struct Attributes
            {
                float4 positionOS               : POSITION;
                half4 color                     : COLOR;
                float4 texcoord                 : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 clipPos                  : SV_POSITION;
                float4 texcoord                 : TEXCOORD0;

                float4 centerPos                : TEXCOORD1;
                float4 screenPos                : TEXCOORD8;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            half _RadialStrength;
            half _DispersionStrength;
            half _SphereMaskRadius;
            half _SphereMaskHardness;
            CBUFFER_END
            
            Varyings vert (Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                const float3 objectPosition = UNITY_MATRIX_M._14_24_34;
                
                float3 objectPos = input.positionOS.xyz *
                    float3( length(UNITY_MATRIX_M._11_21_31),
                            length(UNITY_MATRIX_M._12_22_32),
                            length(UNITY_MATRIX_M._13_23_33));
                float3 billboardWorldPos = mul(UNITY_MATRIX_I_V, float4(objectPos, 0.0)).xyz;
                billboardWorldPos += objectPosition;
                const float4 billboardClipPos = TransformWorldToHClip(billboardWorldPos);
                float4 ndc = billboardClipPos * 0.5f;
                float4 billboardNDC = billboardClipPos;
                billboardNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
                
                // VertexPositionInputs vertexInput = GetVertexPositionInputs(TransformWorldToObject(billboardWorldPos));

                const float4 centerClipPos = TransformWorldToHClip(objectPosition);
                float4 c_ndc = centerClipPos * 0.5f;
                float4 centerNDC = centerClipPos;
                centerNDC.xy = float2(c_ndc.x, c_ndc.y * _ProjectionParams.x) + c_ndc.w;
                
                // VertexPositionInputs originInput = GetVertexPositionInputs(float3(0,0,0));
                
                output.clipPos = billboardClipPos;
                // output.clipPos = vertexInput.positionCS;

                output.texcoord = input.texcoord;

                output.centerPos = centerNDC;
                // output.centerPos = originInput.positionNDC;
                output.screenPos = billboardNDC / output.clipPos.w;
                // output.screenPos = vertexInput.positionNDC / output.clipPos.w;
                
                return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // 初始化粒子参数
                float2 uv = input.screenPos.xy;
                
                half3 screenColor = half3(0,0,0);
                const half2 centerPos = input.centerPos.xy / input.centerPos.w;
                
                float2 dir = (centerPos - uv) * _RadialStrength * 0.01;
                dir *= 0.2;         //循环五次，总偏移量的五分之一（非必要）
                const float2 offset = dir * _DispersionStrength;
                UNITY_UNROLL
                for (int t = 0; t < 5; t++)
                {
                    // screenColor += SampleSceneColor(input.screenPos.xy + dir * t * 0.2) * 0.2;
                    screenColor += half3(
                        SampleSceneColor(uv + (dir + offset) * t).r,
                        SampleSceneColor(uv + dir * t).g,
                        SampleSceneColor(uv + (dir - offset) * t).b) * 0.2;
                }

                _SphereMaskHardness = max(_SphereMaskRadius * 2, _SphereMaskHardness);
                float alpha = 1 - saturate((distance(input.texcoord.xy, half2(0.5,0.5)) - _SphereMaskRadius) / (1 - _SphereMaskHardness));

                return half4(screenColor, alpha);
            }
            ENDHLSL
        }
    }
}
