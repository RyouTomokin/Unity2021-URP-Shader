Shader "KIIF/Special/Grass"
{
    Properties
    {
        [Header(Common)]
        [Space(5)]
        [MainTexture]_BaseTex ("BaseTex", 2D) = "white" {}
        [MainColor]_ColorTint("Color Tint", Color) = (1,1,1,1)
        _Emission("EmissionColor",Color) = (0,0,0,0)
        [Toggle(_ALPHATEST_ON)] _AlphaTest("Alpha Clipping", Float) = 1.0
        _Cutoff("Alpha Clip", Range(0, 1)) = .5
        _ColorTexture("Use BaseTexture",Range(0, 1)) = 0
        
        [Space(20)]
        [Header(Grass Color)]
        [Space(5)]
        _TopTint("Top Tint", Color) = (1,1,1,1)
        _BottomTint("Bottom Tint", Color) = (1,1,1,1)
        _BottomMax("Bottom Max", Range(-1, 1)) = 0
        
        [Space(20)]
        [Header(Grass StaticColor)]
        //控制静止的色块噪点图
        _NoiseColorTex("NoiseColorTex", 2D) = "black" {}
        _NoiseColorStreng("NoiseColorStreng", Range(0, 1)) = 0
        _NoiseColor("NoiseColor", Color) = (1,1,1,1)
        
        [Space(20)]
        [Header(Grass DynamicColor)]
        [Space(5)]
        //控制流动的色块 和 风的噪点图
        _WindNoiseTex("WindNoiseTex", 2D) = "black" {}
        [HDR]_WaveColor("Wave Color", Color) = (1,1,1,1)
        _WaveColorStreng("Wave ColorStreng",Range(0,1)) = 0.5
         //前面几个分量表示在各个轴向上自身摆动的速度, w表示摆动的强度
        _WindControl("WindControl(x:XSpeed y:YSpeed z:ZSpeed w:windMagnitude)",vector) = (1,0,1,0.5)
         //前面几个分量表示在各个轴向上风浪的速度, w用来模拟地图的大小,值越小草摆动的越凌乱，越大摆动的越整体
        _WaveControl("WaveControl(x:XSpeed y:YSpeed z:ZSpeed w:worldSize)",vector) = (1,0,1,1)
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "TransparentCutout" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "Queue" = "AlphaTest"
        }
        LOD 300

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        
        // CBUFFER_START(UnityPerMaterial) //缓冲区
        //Common
        half4 _BaseTex_ST;
        half4 _ColorTint;
        half4 _Emission;
        half _Cutoff;
        half _ColorTexture;

        //Grass Color
        half4 _TopTint, _BottomTint;
        half _BottomMax;

        //Grass StaticColor
        float4 _NoiseColorTex_ST;
        float _NoiseColorStreng;
        half4 _NoiseColor;

        //Grass DynamicColor
        float4 _WindNoiseTex_ST;
        half4 _WaveColor;
        half _WaveColorStreng;
        half4 _WindControl,_WaveControl;
        // CBUFFER_END

        TEXTURE2D(_BaseTex);            SAMPLER(sampler_BaseTex);
        TEXTURE2D(_NoiseColorTex);      SAMPLER(sampler_NoiseColorTex);
        TEXTURE2D(_WindNoiseTex);       SAMPLER(sampler_WindNoiseTex);
        
        struct VertexInput
        {
            float4 position             : POSITION;
            half3 normal                : NORMAL;
            float4 vertexColor          : COLOR;            
            half2 texcoord              : TEXCOORD0;
            half2 lightmapUV            : TEXCOORD1;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct VertexOutput
        {
            half4 positionCS            : SV_POSITION;
            half4 uv                    : TEXCOORD0;    //Z:tempCol  W:tempNoise
            DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
            half3 positionWS            : TEXCOORD2;
            float4 vertexColor          : COLOR;
            UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO
        };
        
        ENDHLSL

        Pass
        {
            Name "Forward"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            ZWrite On
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment

            #pragma shader_feature _ALPHATEST_ON
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            // #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            // #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            
            VertexOutput Vertex(VertexInput input)
            {
                VertexOutput output = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float4 positionWS = mul(GetObjectToWorldMatrix(), input.position);
                float2 worldUV = positionWS.xz / _WaveControl.w;
                float2 noiseUV = positionWS.xz * _NoiseColorTex_ST.xy + _NoiseColorTex_ST.zw;
                float waveNoise = SAMPLE_TEXTURE2D_LOD(_NoiseColorTex, sampler_NoiseColorTex, noiseUV, 0).r;
                worldUV += _Time.x * -_WaveControl.xz;
                float waveSample = SAMPLE_TEXTURE2D_LOD(_WindNoiseTex, sampler_WindNoiseTex, worldUV, 0).r;
                
                positionWS.x += sin(waveSample * _WindControl.x) * _WaveControl.x * _WindControl.w * input.texcoord.y;
                positionWS.z += sin(waveSample * _WindControl.z) * _WaveControl.z * _WindControl.w * input.texcoord.y;
                
                output.positionCS = mul(GetWorldToHClipMatrix(), positionWS);
                output.positionWS = positionWS.xyz;
                output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseTex);

                OUTPUT_SH(TransformObjectToWorldNormal(input.normal), output.vertexSH);
                
                output.uv.z = waveSample;
                output.uv.w = waveNoise;
                output.vertexColor = input.vertexColor;
                
                return output;
            }
            
            half4 Fragment(VertexOutput input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, input.uv.xy);
                #if defined(_ALPHATEST_ON)
                clip(baseMap.a - _Cutoff);
                #endif
                
                half4 noiseControl = _WaveColor * _WaveColorStreng  ;
                half4 tempNoise = input.uv.z *  noiseControl;
                half4 Noisecolor = input.uv.w * _NoiseColorStreng;

                half PositionUV = saturate(input.vertexColor.r + _BottomMax);
                half4 Tint = lerp(_BottomTint, _TopTint, PositionUV);
                
                half4 grassColor = lerp(lerp(saturate(Tint + tempNoise), _NoiseColor, lerp(_BottomTint, Noisecolor, PositionUV)), baseMap, _ColorTexture);
                grassColor *= _ColorTint;
                half3 normalWS = half3(0, 1, 0);
                half3 diffuse = grassColor.rgb * 0.96f;

                // 光照计算
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS); //主光计算阴影
                Light mainLight = GetMainLight(shadowCoord);
                // half3 directLightColor = LightingPhysicallyBased(brdfData, mainLight, normalWS, viewDirectionWS);
                half NdotL = saturate(dot(normalWS, mainLight.direction));
                half3 radiance = mainLight.color * (mainLight.distanceAttenuation * mainLight.shadowAttenuation * NdotL);
                half3 directLightColor = diffuse * radiance;
                half4 color = half4(directLightColor, baseMap.a);
                half3 bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, normalWS);
                half3 GIcolor = bakedGI * diffuse;
                
                color.rgb += GIcolor;
                #ifdef _ADDITIONAL_LIGHTS
                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                {
                    Light light = GetAdditionalLight(lightIndex, input.positionWS);
                    half NdotL = saturate(dot(normalWS, light.direction));
                    half3 radiance = light.color * (light.distanceAttenuation * light.shadowAttenuation * NdotL);
                    half3 brdf = diffuse;
                    color.rgb += brdf * radiance;
                }
                #endif

                return color;
            }
            ENDHLSL
        }
        
        //DepthOnly
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            // #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"

            VertexOutput DepthOnlyVertex(VertexInput input)
            {
                VertexOutput output = (VertexOutput)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float4 positionWS = mul(GetObjectToWorldMatrix(), input.position);
                float2 worldUV = positionWS.xz / _WaveControl.w;
                worldUV += _Time.x * -_WaveControl.xz;
                float waveSample = SAMPLE_TEXTURE2D_LOD(_WindNoiseTex, sampler_WindNoiseTex, worldUV, 0).r;
                
                positionWS.x += sin(waveSample * _WindControl.x) * _WaveControl.x * _WindControl.w * input.texcoord.y;
                positionWS.z += sin(waveSample * _WindControl.z) * _WaveControl.z * _WindControl.w * input.texcoord.y;

                output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseTex);
                output.positionCS = mul(GetWorldToHClipMatrix(), positionWS);
                return output;
            }

            half4 DepthOnlyFragment(VertexOutput input) : SV_TARGET
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                half4 color = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, input.uv.xy);
                #if defined(_ALPHATEST_ON)
                clip(color.a - _Cutoff);
                #endif
                return 0;
            }
            ENDHLSL
        }
    }
}