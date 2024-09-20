Shader "KIIF/MatCap"
{
    Properties
    {
        [MainColor][HDR] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        
        [Toggle] _NORMALMAP("Use NormalMap", float) = 0
        _BumpScale("NormalScale", Float) = 1.0
        [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
        
        [Space(20)]
        [Header(MatCapMap)]
        [Space]
        [NoScaleOffset] _MatCapMap("MatCap", 2D) = "black" {}
        _MatCapAdjust("MatCapAdjust", Range(0, 0.5)) = 0.5
        _MatCapSaturation("MatCapSaturation", Range(0, 1)) = 1
        _MatCapIntensity("MatCapIntensity", Range(0, 1)) = 1
        _MatCapSpecular("MatCapSpecular", Range(0, 1)) = 0
        
        [Space(20)]
        [Header(Refraction)]
        [Space]
        _RefractionFade("RefractionFade", Float) = 100
        _RefractionIntensity("RefractionIntensity", Range(0, 1)) = 0
        [PowerSlider(2)] _RefractionRange("RefractionRange", Range(0, 5)) = 1
        _Vitreous("Vitreous", Range(0, 1)) = 0
        
//        [Space(20)]
//        [Header(Stencil)]
//        [Space]
//        _RefValue("Ref Value",Int) = 0
//        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8      //默认Always
//        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep
        
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
//            Name "ForwardLit"
//            Tags{"LightMode" = "UniversalForward"}
            
//            Stencil
//            {
//                Ref [_RefValue]
//                Comp [_StencilComp]
//                Pass [_StencilPass]
//            }
            
            ZWrite [_ZWrite]
            Cull [_Cull]
            
            HLSLPROGRAM

            // #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _NORMALMAP_ON

            // -------------------------------------
            // Universal Pipeline keywords

            // -------------------------------------
            // Unity defined keywords

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            
            #pragma vertex vert_Unlit
            #pragma fragment frag_Unlit
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            
            struct AttributesUnlit
            {
                float4 positionOS               : POSITION;
                float2 uv                       : TEXCOORD0;
                half4 color                     : COLOR;
                
                float3 normalOS                 : NORMAL;
                float4 tangentOS                : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct VaryingsUnlit
            {
                float4 positionCS               : SV_POSITION;
                float2 uv                       : TEXCOORD0;
                half4 color                     : COLOR;
                
                #ifdef _NORMALMAP_ON
                float3 normalWS                 : TEXCOORD3;
                float3 tangentWS                : TEXCOORD4;
                float3 bitangentWS              : TEXCOORD5;
                #else
                float3 normalWS                 : TEXCOORD3;
                #endif
                float3 positionVS               : TEXCOORD7;
                float3 positionWS               : TEXCOORD6;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            half4 _BaseColor;
            float4 _BaseMap_ST;
            half _BumpScale;
            half _MatCapAdjust;
            half _MatCapSaturation;
            half _MatCapIntensity;
            half _MatCapSpecular;

            half _RefractionFade;
            half _RefractionIntensity;
            half _RefractionRange;
            half _Vitreous;
            CBUFFER_END

            TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_MatCapMap);          SAMPLER(sampler_MatCapMap);

            VaryingsUnlit vert_Unlit(AttributesUnlit input)
            {
                VaryingsUnlit output = (VaryingsUnlit)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.uv = input.uv;

                output.positionCS = vertexInput.positionCS;

                #ifdef _NORMALMAP_ON
                output.normalWS = normalInput.normalWS;
                output.tangentWS = normalInput.tangentWS;
                output.bitangentWS = normalInput.bitangentWS;
                #else
                output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
                #endif
                
                output.positionWS = vertexInput.positionWS;
                output.positionVS = vertexInput.positionVS;

                // -------------------------------------
                
                return output;
            }
            half4 frag_Unlit(VaryingsUnlit input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------
                //颜色采样

                float2 baseUV = input.uv * _BaseMap_ST.xy + _BaseMap_ST.zw * _Time.y ;
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);
                
                half alpha = albedoAlpha.a * _BaseColor.a;
                half3 albedo = albedoAlpha.rgb * _BaseColor.rgb;
                
                half4 color;

                // -------------------------------------
                //MatCap
                #ifdef _NORMALMAP_ON
                half4 normal = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, baseUV);
                half3 normalTS = UnpackNormalScale(normal, _BumpScale);
                float3x3 TangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
                half3 normalWS = TransformTangentToWorld(normalTS, TangentToWorld);
                normalWS = NormalizeNormalPerPixel(normalWS);
                #else
                half3 normalWS = input.normalWS;
                #endif
                
                half3 normalVS = mul(UNITY_MATRIX_V, float4(normalWS, 0.0)).xyz;        //这里输入的世界法线必须是xyz0,作为方向
                half3 positionVS = normalize(input.positionVS);
                half2 matcapUV = cross(positionVS, normalVS).xy;
                matcapUV = matcapUV.yx * half2(-1, 1) * _MatCapAdjust + 0.5;
                // half2 matcapUV = normalVS.xy * 0.5 + 0.5;    //只使用视角空间法线会在透视摄像机边缘产生畸变

                half4 matcapColor = SAMPLE_TEXTURE2D(_MatCapMap, sampler_MatCapMap, matcapUV);
                matcapColor.rgb = Desaturate(matcapColor.rgb, _MatCapSaturation);
                matcapColor *= _MatCapIntensity;
                
                // -------------------------------------
                //颜色混合
                color.rgb = matcapColor.rgb * albedo + albedo;       //保留albedo颜色
                // color.rgb = matcapColor * (albedo + 1);       //保留MatCap颜色
                // color.rgb = 1 - (1 - matcapColor) * (1 - albedo);       //滤色
                // color.rgb = lerp(albedo, matcapColor, matcapColor);     //MatCap高光
                

                // -------------------------------------
                //折射
                half3 viewDirWS = GetCameraPositionWS() - input.positionWS;
                viewDirWS = SafeNormalize(viewDirWS);
                float2 screenUV = input.positionCS.xy / _ScaledScreenParams.xy;
                
                float NdotV = saturate(dot(normalWS, viewDirWS));
                float fresnel = 1 - NdotV;
                fresnel = Pow4(fresnel) * fresnel;
                fresnel = fresnel * 0.99 + 0.01;    
                float refractionFade = smoothstep(0, _RefractionRange, NdotV);
                refractionFade = lerp(refractionFade, 1 - refractionFade, _Vitreous);
                
                fresnel += refractionFade;
                
                half vitreousRefractionFade = lerp(refractionFade, 1-refractionFade, _Vitreous);    //玻璃片为中间透的凸透镜，玻璃越透的地方扭曲越大
                half2 refractionIntensity = normalVS.xy * _RefractionIntensity;
                
                //随视野深度（EyeDepth）改变折射强度
                float sceneRawDepth = SampleSceneDepth(screenUV);
                float sceneEyeDepth = LinearEyeDepth(sceneRawDepth, _ZBufferParams);
                float refractionEyeDepthFade = saturate(1 - sceneEyeDepth * rcp(_RefractionFade));      //sceneEyeDepth remap[0,_RefractionFade]->[1,0]
                
                half2 refractionUV = screenUV - vitreousRefractionFade * refractionIntensity * refractionEyeDepthFade;

                half4 sceneColor = half4(SampleSceneColor(refractionUV), 1);
                // sceneColor.rgb = 1 - (1 - sceneColor.rgb) * (1 - color.rgb); //滤色会让材质变更白
                fresnel *= alpha;

                // -------------------------------------
                //颜色混合
                sceneColor = lerp(sceneColor, color * sceneColor, lerp(alpha, min(alpha, matcapColor), _Vitreous));
                // half4 vitreousSceneColor = lerp(color * sceneColor, 1-(1-matcapColor)*(1-sceneColor), _Vitreous);
                // sceneColor = lerp(sceneColor, vitreousSceneColor, alpha);
                
                color.rgb *= max(1, fresnel * _MatCapSpecular); //边缘光强度
                
                color.rgb = lerp(sceneColor.rgb, color.rgb, saturate(fresnel));

                // -------------------------------------
                //高光

                half lightness = dot(matcapColor.rgb, half3(0.299, 0.587, 0.114));
                half specularRange = lerp(1, 0.5, _MatCapSpecular);
                lightness = saturate(lightness - specularRange) * (rcp(max(HALF_MIN, 1 - specularRange)) + _MatCapSpecular);
                half3 specularColor = lightness * lightness * _MainLightColor.rgb * _MatCapSpecular;
                
                color.rgb += specularColor;
                color.a = alpha;
               
                return color;
            }
            ENDHLSL
        }
    }
}
