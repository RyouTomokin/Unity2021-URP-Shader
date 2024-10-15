Shader "KIIF/PBR_PoolWater"
{
    Properties
    {
        [Toggle] _UseWorldPositionUV("使用世界坐标为纹理UV", Float) = 0
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("焦散", 2D) = "white" {}
        //基于原本缩放和速度的倍率
        _SecondTiling("焦散第二层UV", Vector) = (1.2,1.2,0.2,0.2)
        _CausticsHeight("CausticsHeight", Range(-1, 1)) = 0
        _FresnelPower("FresnelPower", Range(0.01, 8)) = 1
        
        [Space(20)]
        [Header(Twist)]
        [Space]
        _TwistMap("扭曲贴图(offset为流动方向)", 2D) = "black" {}
        _TwistStrength("TwistStrength", Range(0, 1)) = 0.5
        _TwistSpeed("TwistSpeed", Float) = 0
        
        [Space(20)]
        [Header(Noise)]
        [Space]
        _NoiseMap("Noise", 2D) = "black" {}
        _NoiseSize("NoiseSize", Float) = 1
        _NoiseTwist_UV("NoiseTwistUV", Vector) = (1,1,0,0)
        _NoiseTwistStrength("NoiseTwistStrength", Range(0, 1)) = 0.5
        [HDR] _NoiseColor("NoiseColor", Color) = (1,1,1,1)
        
        [Space(20)]
        [Header(Water)]
        [Space]
        _EdgeFade("EdgeFade", Range(0, 5)) = 1
        [PowerSlider(2)]_WaterDepthRange("WaterDepthRange", Range(0, 20)) = 2
        _FoamBase("FoamBase", Range(0, 1)) = 0
        
        _EdgeColor("EdgeColor", Color) = (1,1,1,1)
        _ColorBright("ColorBright", Color) = (0,0.5,0.6,0.2)
        _ColorDeep("ColorDeep", Color) = (0,0.2,0.3,1)
        
        _RefractionFade("RefractionFade", Float) = 100
        _RefractionIntensity("RefractionIntensity", Float) = 0.1
        [PowerSlider(3)] _FarDistanceFilling("FarDistanceFilling", Range(0,1)) = 0.1
        
        [Space(20)]
        [Header(Stencil)]
        [Space]
        _RefValue("Ref Value",Int) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8      //默认Always
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep
        
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
//        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
        LOD 300
        //ForwardLit
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
//            Blend SrcAlpha OneMinusSrcAlpha
            Stencil
            {
                Ref [_RefValue]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }
            ZWrite On
            Cull[_Cull]
            
            HLSLPROGRAM

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords

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
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            #include "Assets/Art/Shaders/Library/KIIFCommon.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 texcoord1    : TEXCOORD0;
                float2 texcoord2    : TEXCOORD1;
                float4 color        : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 uv                       : TEXCOORD0;
                float4 color                    : COLOR;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

                float3 positionWS               : TEXCOORD2;
                float3 positionVS               : TEXCOORD6;

                float4 normalWS                 : TEXCOORD3;    // xyz: normal
                float4 tangentWS                : TEXCOORD4;    // xyz: tangent
                float4 bitangentWS              : TEXCOORD5;    // xyz: bitangent                

                float4 positionCS               : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            CBUFFER_START(UnityPerMaterial)
            float _UseWorldPositionUV;
            float4 _BaseMap_ST;
            float4 _SecondTiling;
            half4 _BaseColor;
            half _CausticsHeight;
            
            float4 _TwistMap_ST;
            half _TwistSpeed;
            half _TwistStrength;

            float4 _NoiseMap_ST;
            float _NoiseSize;
            float4 _NoiseTwist_UV;
            float _NoiseTwistStrength;
            half4 _NoiseColor;

            half _RefractionFade;
            half _RefractionIntensity;
            float _FarDistanceFilling;
            float _EdgeFade;
            float _WaterDepthRange;
            float _FoamBase;
            
            half4 _EdgeColor;
            half4 _ColorBright;
            half4 _ColorDeep;                        
            CBUFFER_END
            
            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_TwistMap);           SAMPLER(sampler_TwistMap);
            TEXTURE2D(_NoiseMap);           SAMPLER(sampler_NoiseMap);
            TEXTURE2D(_BumpMap);            SAMPLER(sampler_BumpMap);

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;

                output.uv = float4(input.texcoord1, input.texcoord2);
                output.color = input.color;

                output.normalWS = half4(normalInput.normalWS, viewDirWS.x);
                output.tangentWS = half4(normalInput.tangentWS, viewDirWS.y);
                output.bitangentWS = half4(normalInput.bitangentWS, viewDirWS.z);

                output.positionWS = vertexInput.positionWS;
                output.positionVS = vertexInput.positionVS;

                output.positionCS = vertexInput.positionCS;
                
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------
                // 预处理
                half2 uv = lerp(input.uv.xy, input.positionWS.xz, _UseWorldPositionUV);
                half3x3 TangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
                half3 viewDirWS = half3(input.normalWS.w, input.tangentWS.w, input.bitangentWS.w);
                half3 viewDirectionWS = SafeNormalize(viewDirWS);

                // 扭曲
                half2 twistUV = uv * _TwistMap_ST.xy + _TwistSpeed * _TwistMap_ST.zw * _Time.y;
                half2 twist = SAMPLE_TEXTURE2D(_TwistMap, sampler_TwistMap, twistUV).rg;
                twist *= _TwistStrength;

                // -------------------------------------
                // 水体深度
                float2 screenUV = input.positionCS.xy / _ScaledScreenParams.xy;
                float sceneRawDepth = SampleSceneDepth(screenUV);
                float sceneEyeDepth = LinearEyeDepth(sceneRawDepth, _ZBufferParams);
                float depthDifference = sceneEyeDepth + input.positionVS.z;     //EyeDepth - (-1 * P_ViewSpace.Z)

                float edgeRange = depthDifference * rcp(_EdgeFade);             //edgeFade remap[0,_EdgeFade]->[0,1]
                float edgeFade = saturate(edgeRange);
                float waterDepth = pow(max(0, sceneEyeDepth - input.positionCS.w), 0.5);
                float waterDepthRemap = Remap01(waterDepth, rcp(_WaterDepthRange), 0);
                
                // 颜色采样，焦散纹理，双重采样
                float2 base_uv = (uv + twist.xy) * _BaseMap_ST.xy + _BaseMap_ST.zw * _Time.y;
                float2 foam_uv = base_uv * 10;
                
                base_uv = BumpOffset(TangentToWorld, viewDirectionWS, base_uv, _CausticsHeight, 1 - waterDepthRemap, 0);
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, base_uv);
                base_uv = base_uv*_SecondTiling.xy + _Time.y * _BaseMap_ST.zw*(_SecondTiling.zw-1);
                albedoAlpha += SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, base_uv);
                albedoAlpha *= _BaseColor;

                // -------------------------------------
                // 视野衰减
                float viewDis = distance(input.positionWS, GetCameraPositionWS());
                float viewFade = saturate(viewDis * rcp(_RefractionFade));
                viewFade = lerp(1, 0, viewFade);
                viewFade *= viewFade;
                
                //水体折射
                half2 refractionIntensity = twist * _RefractionIntensity * edgeFade;
                half2 refractionUV = screenUV + viewFade * refractionIntensity;
                
                half4 refractSceneColor = half4(SampleSceneColor(refractionUV), 1);
                half refractDepth = SampleSceneDepth(refractionUV);

                half4 waterColor = lerp(refractSceneColor * _ColorBright, _ColorDeep, waterDepthRemap);
                waterColor = lerp(waterColor, _ColorDeep, step(refractDepth, _FarDistanceFilling));
                
                waterColor = saturate(waterColor);
                waterColor.a = edgeFade;

                // 添加纹理颜色                
                albedoAlpha = albedoAlpha * viewFade;
                half4 color = waterColor + albedoAlpha;
                
                color.a = edgeFade;

                // -------------------------------------
                // 泡沫
                half foam = SAMPLE_TEXTURE2D(_TwistMap, sampler_TwistMap, foam_uv).r;
                half waterFoam = foam * saturate(_FoamBase + (1 - edgeFade));
                waterFoam = step(edgeFade, waterFoam);

                _EdgeColor.a *= edgeFade;
                color += waterFoam * _EdgeColor;
                
                // -------------------------------------
                // 噪波
                half2 noiseUV = uv * _NoiseMap_ST.xy * _NoiseSize + _NoiseMap_ST.zw * _Time.y;
                half2 noiseTwistUV = uv * _NoiseTwist_UV.xy * _NoiseSize + _NoiseTwist_UV.zw * _Time.y;
                half2 noiseTwist = SAMPLE_TEXTURE2D(_TwistMap, sampler_TwistMap, noiseTwistUV).rg;
                noiseUV += noiseTwist * _NoiseTwistStrength;
                half noise = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, noiseUV).r;
                color = lerp(color, noise * _NoiseColor, noise);

                half3 sceneColor = SampleSceneColor(screenUV);
                color.rgb = lerp(sceneColor, color.rgb, color.a);
                return color;
            }
            ENDHLSL
        }
        //Shadow
//        Pass
//        {
//            Name "ShadowCaster"
//            Tags{"LightMode" = "ShadowCaster"}
//
//            ZWrite On
//            ZTest LEqual
//            Cull[_Cull]
//
//            HLSLPROGRAM
//            // Required to compile gles 2.0 with standard srp library
//            #pragma prefer_hlslcc gles
//            #pragma exclude_renderers d3d11_9x
//            #pragma target 2.0
//
//            // -------------------------------------
//            // Material Keywords
//
//            //--------------------------------------
//            // GPU Instancing
//            #pragma multi_compile_instancing
//            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
//
//            #pragma vertex ShadowPassVertex
//            #pragma fragment ShadowPassFragment
//
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
//            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
//            ENDHLSL
//        }
        //DepthOnly
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
//    CustomEditor "PBR_Base_ShaderGUI"
}
