Shader "KIIF/Special/TreeLeaves"
{
    Properties
    {
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [Toggle(_ALPHATEST_ON)] _AlphaTest("Alpha Clipping", Float) = 0.0
        _Cutoff("剔除阈值", Range(0.0, 1.0)) = 0.5

        [Toggle(_DITHER_ON)] _Dither("Dither Clipping", Float) = 0.0
//        _DitherMap("Dither", 2D) = "white" {}
        _NearDistance ("Near Distance", Float) = 13.0
        _FarDistance ("Far Distance", Float) = 30.0
        _DitherScale ("DitherScale", Float) = 1.5

        _VirtualSunColor ("VirtualSunColor", Color) = (0, 0, 0, 0)
        _VirtualSunDirection ("VirtualSunDirection", Vector) = (0, 0, 0, 0)

        [Space(20)]
        _ColorSaturate ("Color Saturate", Range(0.0, 1.0)) = 1
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        _ShadowColor("Shadow Color", Color) = (1,1,1,1)
        _CenterDistance ("Center Distance", Float) = 1
        _TreeHeight ("Tree Height", Float) = 1
        _MinDarkness ("Min Darkness", Range(0.0, 1.0)) = 0

        [Space(20)]
        _Strength ("Wind Strength", Float) = 0.05
        _Speed ("Wind Speed", Float) = 1.0
        _Frequency ("Wind Frequency", Float) = 75.0

        [Space(20)]
        [Header(Stencil)]
        [Space]
        _RefValue("Ref Value",Int) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8      //默认Always
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0

        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 0.0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline" "RenderType" = "TransparentCutout" "Queue" = "AlphaTest"
        }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        half _ColorSaturate;
        half4 _BaseColor;
        half4 _ShadowColor;
        half _Cutoff;

        half4 _VirtualSunDirection;
        half4 _VirtualSunColor;

        half _NearDistance;
        half _FarDistance;
        half _DitherScale;

        half _CenterDistance;
        half _TreeHeight;
        half _MinDarkness;

        float _Speed;
        float _Frequency;
        float _Strength;
        CBUFFER_END

        static const float4x4 threshold = float4x4(
            0.0, 0.5333, 0.1333, 0.6667,
            0.8, 0.2667, 0.9333, 0.4,
            0.2, 0.7333, 0.0667, 0.6,
            1.0, 0.4667, 0.8667, 0.3333
            );

        // 风效
        inline float3 Wind(half3 position)
        {
            float time = _Time.y * _Speed;
            // 基于世界坐标的波动
            float waveX = sin(position.x * _Frequency + time) * cos(position.y * _Frequency + time);
            float waveY = cos(position.z * _Frequency + time) * sin(position.x * _Frequency + time);
            float waveZ = sin(position.y * _Frequency + time) * cos(position.z * _Frequency + time);

            // 综合三轴运动
            float offsetX = waveX * _Strength;
            float offsetY = waveY * _Strength * 0.5; // Y轴位移幅度减小，模拟更自然的摆动
            float offsetZ = waveZ * _Strength;

            // 返回计算后的偏移位置
            return position + float3(offsetX, offsetY, offsetZ);
        }

        inline void Dither(float3 positionWS, float2 positionCS)
        {
            #if defined(_DITHER_ON)
            float distanceToCamera = length(positionWS - GetCameraPositionWS());
            float ditherStrength = saturate((distanceToCamera - _NearDistance) / (_FarDistance - _NearDistance));
            ditherStrength = pow(ditherStrength, _DitherScale);
            // ditherStrength = 1.0 - ditherStrength;

            float2 screenUV = positionCS / _ScaledScreenParams.x;
            // return half4(screenUV,0,1);
            // 生成抖动值
            // float ditherValue = random(screenUV);       //使用屏幕UV使抖动是相对静止的
            // ditherValue = SAMPLE_TEXTURE2D(_DitherMap, sampler_DitherMap, uv*100);      // 采样抖动纹理
            int2 pixelPos = int2(positionCS % 4);
            float ditherValue = threshold[pixelPos.y][pixelPos.x];

            float screenDis = distance(screenUV, float2(0.5, _ScaledScreenParams.y/_ScaledScreenParams.x*0.5));
            screenDis *= 2;                     // 控制剔除的大小
            // screenDis = Pow4(screenDis);        // 控制剔除的过渡
            screenDis = saturate(screenDis);

            clip(screenDis - ditherValue * (1 - screenDis) * (1 - ditherStrength));
            // clip((1 + ditherValue) * lerp(ditherStrength, 1, screenDis) - 1);   // 距离和屏幕中心共同控制
            // clip((out_data.alpha + ditherValue) * ditherStrength - 1);       // 基础的距离算法
            #endif
        }
        
        // 随机函数，用于生成抖动效果
        // float random(float2 uv)
        // {
        //     return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
        // }

        ENDHLSL

        Pass
        {
            Name "Forward"
            Tags{"LightMode" = "UniversalForward"}
            Stencil
            {
                Ref [_RefValue]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }
            ZWrite [_ZWrite]
            Cull [_Cull]

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment  _ALPHATEST_ON
            #pragma shader_feature_local_fragment  _DITHER_ON

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            // #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // #include "Assets/Art/Shaders/Library/KIIFPBR.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS               : SV_POSITION;
                float2 uv                       : TEXCOORD0;
                half4 color                     : COLOR;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
                half3 normalWS                  : TEXCOORD2;
                float3 viewDirWS                : TEXCOORD3;
                float3 positionWS               : TEXCOORD4;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            // TEXTURE2D(_DitherMap);          SAMPLER(sampler_DitherMap);

            float4 GetShadowCoord_Tree(float3 positionWS, float4 positionCS)
            {
            #if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_SURFACE_TYPE_TRANSPARENT)
                return ComputeScreenPos(positionCS);
            #else
                return TransformWorldToShadowCoord(positionWS);
            #endif
            }

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                // 在局部空间做顶点动画
                // float3 windPosition = Wind(input.positionOS.xyz);
                // VertexPositionInputs vertexInput = GetVertexPositionInputs(windPosition);

                // 在世界空间做顶点动画
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                positionWS = Wind(positionWS);
                float4 positionCS = TransformWorldToHClip(positionWS);

                output.uv = input.texcoord;
                // output.color = clamp(distance(input.positionOS.xyz, 0) / max(_CenterDistance, 0), _MinDarkness, 1);
                float3 positionOS = input.positionOS.xyz;
                positionOS.y *= _TreeHeight;
                output.color = min(distance(positionOS, 0) / max(_CenterDistance, 0) + _MinDarkness, 1);

                // 计算世界法线
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = normalInput.normalWS;
                // output.tangentWS = normalInput.tangentWS;
                // output.bitangentWS = normalInput.bitangentWS;
                OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

                output.viewDirWS = GetCameraPositionWS() - positionWS;

                // output.positionCS = vertexInput.positionCS;
                output.positionCS = positionCS;
                output.positionWS = positionWS;

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 uv = input.uv;
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                color.rgb = Desaturate(color.rgb, _ColorSaturate);
                color *= _BaseColor;

                #if defined(_ALPHATEST_ON)
                Dither(input.positionWS, input.positionCS.xy);
                clip(color.a - _Cutoff);
                #endif

                BRDFData brdfData = (BRDFData)0;
                InitializeBRDFData(color.xyz, 0, half3(0.0h, 0.0h, 0.0h), 0, color.a, brdfData);

                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS); //主光计算阴影
                Light mainLight = GetMainLight(shadowCoord);
                // 如果_VirtualSunDirection.xyz是0，普通Normalize会造成闪烁，且lerp结果会出错
                mainLight.direction = lerp(mainLight.direction, SafeNormalize(_VirtualSunDirection.xyz + HALF_MIN), _VirtualSunDirection.w);
                mainLight.color += _VirtualSunColor;
                float3 normalWS = input.normalWS;
                float3 viewDirectionWS = input.viewDirWS;
                // half3 directLightColor = LightingPhysicallyBased(brdfData, mainLight, normalWS, viewDirectionWS);
                // 修改为半兰伯特光照
                half NdotL = saturate(dot(normalWS, mainLight.direction) * 0.5 + 0.5);
                half3 radiance = mainLight.color * (mainLight.shadowAttenuation * NdotL);
                color.rgb *= radiance;

                half3 bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, normalWS);
                half3 GIcolor = GlobalIllumination(brdfData, bakedGI, 1, normalWS, viewDirectionWS);
                GIcolor = lerp(GIcolor, _ShadowColor.rgb, _ShadowColor.a);
                color.rgb += GIcolor;

                color *= input.color;

                return color;
            }
            ENDHLSL
        }

        // ShadowCaster
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            // #pragma multi_compile _ DOTS_INSTANCING_ON

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex_Tree
            #pragma fragment ShadowPassFragment_Tree

            // #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

            Varyings ShadowPassVertex_Tree(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);

                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionCS = GetShadowPositionHClip(input);
                return output;
            }

            half4 ShadowPassFragment_Tree(Varyings input) : SV_TARGET
            {
                Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                return 0;
            }
            ENDHLSL
        }

        // DepthOnly
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex_Tree
            #pragma fragment ShadowPassFragment_Tree

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment  _ALPHATEST_ON
            #pragma shader_feature_local_fragment  _DITHER_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"

            struct Varyings_Tree
            {
                float2 uv           : TEXCOORD0;
                float4 positionCS   : SV_POSITION;
                float3 positionWS   : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings_Tree DepthOnlyVertex_Tree(Attributes input)
            {
                Varyings_Tree output = (Varyings_Tree)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                // 在世界空间做顶点动画
                float3 positionWS = TransformObjectToWorld(input.position.xyz);
                positionWS = Wind(positionWS);
                output.positionCS = TransformWorldToHClip(positionWS);
                output.positionWS = positionWS;
                // output.positionCS = TransformObjectToHClip(input.position.xyz);
                return output;
            }

            half4 ShadowPassFragment_Tree(Varyings_Tree input) : SV_TARGET
            {
                Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                #if defined(_ALPHATEST_ON)
                Dither(input.positionWS, input.positionCS.xy);
                #endif
                return 0;
            }
            ENDHLSL
        }
    }
}
