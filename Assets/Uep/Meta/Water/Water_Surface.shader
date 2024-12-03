Shader "Lilith/Water_Surface"
{
    Properties
    {
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        _SpecularColor2("Specular Color2", Color) = (1,1,1,1)
        _HighLightColor("HighLight Color", Color) = (1,1,1,1)
        _WaterSideColor("Water Side Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        [NoScaleOffset] _ReflectionMap("Reflection Map", 2D) = "white" {}
        [NoScaleOffset] _SpecularMap("Specular Map", 2D) = "white" {}
        
        _TwistStrength("Twist Strength", Float) = 1
        
        _BumpTiling1("Bump Tiling 1", Vector) = (1,1,0,0)
        _BumpTiling2("Bump Tiling 2", Vector) = (1,1,0,0)
        [NoScaleOffset]_BumpMap("Normal Map", 2D) = "bump" {}
        
//        _SunDirection("Sun Direction", Vector) = (0,1,0)
//        _Roughness("Roughness", Range(0, 1)) = 0.5
        _SpecularStep("Specular Step", Range(0, 1)) = 0.5 
        _SpecularSide("Specular Side", Range(0, 1)) = 0.1
        _HighLightStep("HighLight Step", Range(0, 1)) = 0.5 
        _HighLightSide("HighLight Side", Range(0, 1)) = 0.1
        
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float2 uv                       : TEXCOORD0;
                half4 color                     : COLOR;
                float4 positionOS               : POSITION;
                // float3 normalOS                 : NORMAL;
            };

            struct Varyings
            {
                float2 uv                       : TEXCOORD0;
                half4 color                     : COLOR;
                float4 positionCS               : SV_POSITION;
                // float3 normalWS                 : TEXCOORD1;
                // float3 tangentWS                : TEXCOORD2;
                // float3 bitangentWS              : TEXCOORD3;
                // float3 positionWS               : TEXCOORD4;
            };

            CBUFFER_START(UnityPerMaterial)

            half4 _SpecularColor;
            half4 _SpecularColor2;
            half4 _HighLightColor;
            half4 _WaterSideColor;
            
            float4 _BaseMap_ST;
            // float4 _ReflectionMap_ST;
            // float4 _SpecularMap_ST;
            // float4 _BumpMap_ST;
            float4 _BumpTiling1;
            float4 _BumpTiling2;
            half _TwistStrength;

            // half3 _SunDirection;
            // half _Roughness;
            // half _SpecularStrength;
            half _SpecularStep;
            half _SpecularSide;
            half _HighLightStep;
            half _HighLightSide;

            half _Cutoff;
            
            CBUFFER_END
            
            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_ReflectionMap);      SAMPLER(sampler_ReflectionMap);
            TEXTURE2D(_SpecularMap);        SAMPLER(sampler_SpecularMap);
            TEXTURE2D(_BumpMap);            SAMPLER(sampler_BumpMap);

            Varyings vert (Attributes input)
            {
                Varyings output = (Varyings)0;;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                // VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, float4(1,0,0,0));

                output.positionCS = vertexInput.positionCS;
                // output.positionWS = vertexInput.positionWS;
                // output.normalWS = normalInput.normalWS;
                // output.tangentWS = normalInput.tangentWS;
                // output.bitangentWS = normalInput.bitangentWS;
                
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.color = input.color;
                return output;
            }

            half CustomDirectBRDFSpecular(half roughness, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS)
            {
                float3 lightDirectionWSFloat3 = float3(lightDirectionWS);
                float3 halfDir = SafeNormalize(lightDirectionWSFloat3 + float3(viewDirectionWS));

                float NoH = saturate(dot(float3(normalWS), halfDir));
                half LoH = half(saturate(dot(lightDirectionWSFloat3, halfDir)));

                half roughness2             = max(roughness * roughness, HALF_MIN);
                half roughness2MinusOne     = roughness2 - half(1.0);
                half normalizationTerm      = roughness * half(4.0) + half(2.0);

                // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
                // BRDFspec = (D * V * F) / 4.0
                // D = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2
                // V * F = 1.0 / ( LoH^2 * (roughness + 0.5) )
                // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
                // https://community.arm.com/events/1155

                // Final BRDFspec = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2 * (LoH^2 * (roughness + 0.5) * 4.0)
                // We further optimize a few light invariant terms
                // brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
                float d = NoH * NoH * roughness2MinusOne + 1.00001f;

                half LoH2 = LoH * LoH;
                half specularTerm = roughness2 / ((d * d) * max(0.1h, LoH2) * normalizationTerm);

                return specularTerm;
            }

            half3 BlendOverlay(half3 base, half3 blend)
            {
                return base>0.5 ?
                    1 - 2 * (1 - base) * (1 - blend) : 2 * base * blend;
            }

            half3 BlendScreen(half3 base, half3 blend)
            {
                return 1 - (1 - base) * (1 - blend);
            }

            half4 frag (Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                
                // 采样颜色贴图
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                half4 specularMap = SAMPLE_TEXTURE2D(_SpecularMap, sampler_SpecularMap, uv);
                clip(specularMap.b - _Cutoff);

                // 采样并计算世界法线
                float2 bumpUV1 = input.uv * _BumpTiling1.xy + _BumpTiling1.zw * _Time.y;
                float2 bumpUV2 = input.uv * _BumpTiling2.xy + _BumpTiling2.zw * _Time.y;
                half4 bump1 = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, bumpUV1);
                half4 bump2 = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, bumpUV2);
                half4 bump = lerp(bump1, bump2, 0.5);
                half3 normalTS = UnpackNormalScale(bump, 1);
                // half3x3 TangentToWorld = half3x3(input.tangentWS, input.bitangentWS, input.normalWS);
                // half3 normalWS = TransformTangentToWorld(normalTS, TangentToWorld);
                
                // 带扭曲的采样
                float2 twistUV = uv + normalTS.rg * _TwistStrength * input.color.b;
                half4 reflection = SAMPLE_TEXTURE2D(_ReflectionMap, sampler_ReflectionMap, twistUV);

                // // 计算高光
                // half3 viewDirWS = GetCameraPositionWS() - input.positionWS;
                // viewDirWS = normalize(viewDirWS);
                // half BRDFSpecular =
                //     CustomDirectBRDFSpecular(_Roughness, normalWS, _SunDirection, viewDirWS);
                
                // 颜色混合
                // half specularMask = BRDFSpecular * specular.r;
                half4 color = baseColor;
                
                color = lerp(color, reflection, reflection.a);
                
                half sideArea = saturate((1 - input.color.b) * (1 - input.color.b));
                color = lerp(color, _WaterSideColor, sideArea);

                // 添加高光
                half specularArea = smoothstep(_SpecularStep, _SpecularStep + _SpecularSide, saturate(normalTS.r));
                half highLightArea = smoothstep(_HighLightStep, _HighLightStep + _HighLightSide, saturate(normalTS.r));
                
                specularArea = specularArea * specularMap.r * specularMap.r;
                highLightArea = highLightArea * specularMap.g * specularMap.g;
                
                color = lerp(color, lerp(_SpecularColor, _SpecularColor2, reflection.a), specularArea);
                color += _HighLightColor * highLightArea;
                color.a = 1;
                
                return color;
            }
            ENDHLSL
        }
    }
}
