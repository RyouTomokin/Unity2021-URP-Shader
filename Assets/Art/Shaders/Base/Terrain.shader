Shader "KIIF/Terrain"
{
    Properties
    {
//        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture][NoScaleOffset] _BaseMap("Albedo", 2DArray) = "white" {}
        _LayerCount("Texture Array Layers", Int) = 4

        _UVScale01("UVScale01", Float) = 1
        _UVScale02("UVScale02", Float) = 1
        _UVScale03("UVScale03", Float) = 1
        _UVScale04("UVScale04", Float) = 1
        _UVScale05("UVScale05", Float) = 1
        _UVScale06("UVScale06", Float) = 1
        _UVScale07("UVScale07", Float) = 1
        _UVScale08("UVScale08", Float) = 1
        _UVScale09("UVScale09", Float) = 1
        _UVScale10("UVScale10", Float) = 1
        _UVScale11("UVScale11", Float) = 1
        _UVScale12("UVScale12", Float) = 1
        _UVScale13("UVScale13", Float) = 1
        _UVScale14("UVScale14", Float) = 1
        _UVScale15("UVScale15", Float) = 1
        _UVScale16("UVScale16", Float) = 1
        _Height1("Height1", Float) = 1

//        [Toggle(_DoubleSide)] _DoubleSide("双面", Float) = 0.0
//        [Toggle(_ALPHATEST_ON)] _AlphaTest("Alpha Clipping", Float) = 0.0
//        _Cutoff("剔除阈值", Range(0.0, 1.0)) = 0.5
//        _BumpScale("法线强度", Float) = 1.0
        [NoScaleOffset] _BumpMap("Normal Map", 2DArray) = "" {}
        [NoScaleOffset] _SMAEMap("R:光滑度 G:金属度", 2DArray) = "" {}
//        _Smoothness("光滑度", Range(0.0, 1.0)) = 0.5
//        [Gamma] _Metallic("金属度", Range(0.0, 1.0)) = 0.0
//        _OcclusionStrength("AO", Range(0.0, 1.0)) = 1.0
        
//        _HeightTransition("HeightTransition", Range(0, 1.0)) = 0.5
//        _HeightPower("HeightPower", Range(0, 10)) = 1

        [NoScaleOffset] _ControlMap("ControlMap", 2DArray) = "" {}
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
            ZWrite On

            HLSLPROGRAM

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment  _ALPHATEST_ON
            #pragma shader_feature_local _NORMALMAP
            // #pragma shader_feature_local_fragment  _SMAEMAP
            #pragma shader_feature_local_fragment  _BAKEMODE

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
            // #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
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
                float2 uv                       : TEXCOORD0;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

                float3 positionWS               : TEXCOORD2;

                #if defined(_NORMALMAP) || defined(_PARALLAX_ON)
                float4 normalWS                 : TEXCOORD3;    // xyz: normal, w: viewDir.x
                float4 tangentWS                : TEXCOORD4;    // xyz: tangent, w: viewDir.y
                float4 bitangentWS              : TEXCOORD5;    // xyz: bitangent, w: viewDir.z
                #else
                float3 normalWS                 : TEXCOORD3;
                float3 viewDirWS                : TEXCOORD4;
                #endif

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                float4 shadowCoord              : TEXCOORD7;
                #endif

                float4 positionCS               : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            // half4 _BaseColor;

            uint _LayerCount;
            float _UVScale01;
            float _UVScale02;
            float _UVScale03;
            float _UVScale04;
            float _UVScale05;
            float _UVScale06;
            float _UVScale07;
            float _UVScale08;
            float _UVScale09;
            float _UVScale10;
            float _UVScale11;
            float _UVScale12;
            float _UVScale13;
            float _UVScale14;
            float _UVScale15;
            float _UVScale16;
            float _Height1;

            // half _Cutoff;
            half _BumpScale;
            // half _Smoothness;
            // half _Metallic;
            // half _OcclusionStrength;
            
            // half _HeightTransition;
            // half _HeightPower;
            CBUFFER_END

            TEXTURE2D_ARRAY(_BaseMap);         SAMPLER(sampler_BaseMap);
            TEXTURE2D_ARRAY(_BumpMap);         SAMPLER(sampler_BumpMap);
            TEXTURE2D_ARRAY(_SMAEMap);         SAMPLER(sampler_SMAEMap);
            TEXTURE2D_ARRAY(_ControlMap);      SAMPLER(sampler_ControlMap);

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;

                // output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.uv = input.texcoord;

                #if defined(_NORMALMAP) || defined(_PARALLAX_ON)
                output.normalWS = half4(normalInput.normalWS, viewDirWS.x);
                output.tangentWS = half4(normalInput.tangentWS, viewDirWS.y);
                output.bitangentWS = half4(normalInput.bitangentWS, viewDirWS.z);
                #else
                output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
                output.viewDirWS = viewDirWS;
                #endif

                OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
                OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

                output.positionWS = vertexInput.positionWS;

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                output.shadowCoord = GetShadowCoord(vertexInput);
                #endif

                output.positionCS = vertexInput.positionCS;

                #ifdef _SCREENPOSITION_ON
                // output.screenPos = ComputeScreenPos(output.positionCS)/output.positionCS.w;
                output.screenPos = vertexInput.positionNDC/output.positionCS.w;
                #endif

                return output;
            }

            void Float4ToFloatArray(float4 base, out float array[4])
            {
                array[0] = base.r; // R 分量
                array[1] = base.g; // G 分量
                array[2] = base.b; // B 分量
                array[3] = base.a; // A 分量
            }
            inline void SampleControl(float2 uv, out float weight[4][4])
            {
                uint countrolCount = ceil(_LayerCount / 4.0f);
                float4 tempColor;
                if(countrolCount > 0)
                {
                    tempColor = SAMPLE_TEXTURE2D_ARRAY(_ControlMap, sampler_ControlMap, uv, 0);
                    // control[0] = tempColor;
                    Float4ToFloatArray(tempColor, weight[0]);
                    if(countrolCount >= 1)
                    {
                        tempColor = SAMPLE_TEXTURE2D_ARRAY(_ControlMap, sampler_ControlMap, uv, 1);
                        // control[1] = tempColor;
                        Float4ToFloatArray(tempColor, weight[1]);
                        if(countrolCount >= 2)
                        {
                            tempColor = SAMPLE_TEXTURE2D_ARRAY(_ControlMap, sampler_ControlMap, uv, 2);
                            // control[2] = tempColor;
                            Float4ToFloatArray(tempColor, weight[2]);
                            if(countrolCount >= 3)
                            {
                                tempColor = SAMPLE_TEXTURE2D_ARRAY(_ControlMap, sampler_ControlMap, uv, 3);
                                // control[3] = tempColor;
                                Float4ToFloatArray(tempColor, weight[3]);
                            }
                        }
                    }
                }
            }

            float GetUVScale(uint layerIndex)
            {
                switch(layerIndex)
                {
                    case 0: return _UVScale01;
                    case 1: return _UVScale02;
                    case 2: return _UVScale03;
                    case 3: return _UVScale04;
                    case 4: return _UVScale05;
                    case 5: return _UVScale06;
                    case 6: return _UVScale07;
                    case 7: return _UVScale08;
                    case 8: return _UVScale09;
                    case 9: return _UVScale10;
                    case 10: return _UVScale11;
                    case 11: return _UVScale12;
                    case 12: return _UVScale13;
                    case 13: return _UVScale14;
                    case 14: return _UVScale15;
                    case 15: return _UVScale16;
                    default: return 1.0; // 默认值
                }
            }

            struct LayerSample
            {
                float4 albedo;  // 颜色贴图采样结果
                float3 normal;  // 法线贴图采样结果
                float3 sm;      // 法线贴图采样结果
            };

            LayerSample SampleLayer(float2 uv, uint layerIndex)
            {
                LayerSample result;

                uv *= GetUVScale(layerIndex);
                // 采样颜色贴图（Texture2DArray）
                result.albedo = SAMPLE_TEXTURE2D_ARRAY(_BaseMap, sampler_BaseMap, uv, layerIndex);

                #if defined(_NORMALMAP)
                // 采样法线贴图（Texture2DArray）
                // DXT5nm R->1 G->G B->G A->R
                result.normal = UnpackNormalAG(SAMPLE_TEXTURE2D_ARRAY(_BumpMap, sampler_BumpMap, uv, layerIndex));
                #endif

                // #if defined(_SMAEMAP)
                result.sm = SAMPLE_TEXTURE2D_ARRAY(_SMAEMap, sampler_SMAEMap, uv, layerIndex);
                // #endif
                
                return result;
            }

            // 高度混合的基础原理
            void HeightBasedSplatModify(inout half4 splatControl, in half4 masks[4])
            {
                // heights are in mask blue channel, we multiply by the splat Control weights to get combined height
                half4 splatHeight = half4(masks[0].b, masks[1].b, masks[2].b, masks[3].b) * splatControl.rgba;
                half maxHeight = max(splatHeight.r, max(splatHeight.g, max(splatHeight.b, splatHeight.a)));

                // Ensure that the transition height is not zero.
                // half transition = max(_HeightTransition, 1e-5);
                half transition = 0.5;

                // This sets the highest splat to "transition", and everything else to a lower value relative to that, clamping to zero
                // Then we clamp this to zero and normalize everything
                half4 weightedHeights = splatHeight + transition - maxHeight.xxxx;
                weightedHeights = max(0, weightedHeights);

                // We need to add an epsilon here for active layers (hence the blendMask again)
                // so that at least a layer shows up if everything's too low.
                weightedHeights = (weightedHeights + 1e-6) * splatControl;

                // Normalize (and clamp to epsilon to keep from dividing by zero)
                half sumHeight = max(dot(weightedHeights, half4(1, 1, 1, 1)), 1e-6);
                splatControl = weightedHeights / sumHeight.xxxx;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------
                //采样 初始化

                // PBRData pbrData = (PBRData)0;    //KIIF自定义结构体
                // TerrainInitialize(input, pbrData);

                // 采样 ControlMap（控制贴图，用于权重混合）
                // float4 control[4];
                LayerSample terrainLayer[16];
                float weights[4][4];

                // 初始化 control 和 weights 数组
                for (uint i = 0; i < 4; i++)
                {
                    // control[i] = float4(0, 0, 0, 0); // 初始化 control 数组
                    for (uint j = 0; j < 4; j++)
                    {
                        weights[i][j] = 0.0; // 初始化 weights 数组
                    }
                }

                float2 controlUV = input.uv;
                #ifdef _BAKEMODE
                controlUV = TRANSFORM_TEX(input.uv, _BaseMap);
                #endif

                // SampleControl(controlUV, control, weights);
                SampleControl(controlUV,  weights);

                // -------------------------------------
                //采样 初始化
                float4 mapColor = 0;
                float3 mapNormal = 0;
                float3 mapSM = 0;
                float2 baseUV = TRANSFORM_TEX(input.uv, _BaseMap);
                
                float maxHeight = 0;
                float blendHeight[16];
                float blendWeight[16];
                uint paintedLayerIndex = 0;

                for(uint i = 0; i < 16; i++)
                {
                    blendHeight[i] = 0;
                }

                // 采样地形的颜色纹理（法线、金属粗糙）  并计算权重高度
                for (uint layerIndex = 0; layerIndex < _LayerCount; layerIndex ++)
                {
                    uint controlLayer = ceil(layerIndex / 4);
                    uint index = layerIndex % 4;
                    float weight = weights[controlLayer][index];

                    if(weight > 0)
                    {
                        // 调用采样函数
                        LayerSample layer = SampleLayer(baseUV, layerIndex);

                        if(layerIndex == 0)
                        {
                            layer.albedo.a *= _Height1;
                        }

                        // 高度计算(重新映射高度，使得高度差更容易绘制出)
                        // half power = max(_HeightPower, 1e-5);
                        half power = 1;
                        weight = pow(weight, max(1 - pow(layer.albedo.a, power), 0.4));
                        float tempHeight = weight * layer.albedo.a;
                        maxHeight = max(maxHeight, tempHeight);         // 高度权重的最大值
                        blendHeight[paintedLayerIndex] = tempHeight;    // 高度权重
                        
                        terrainLayer[paintedLayerIndex] = layer;
                        blendWeight[paintedLayerIndex] = weight;

                        paintedLayerIndex++;
                        if(paintedLayerIndex > 16)break;

                        // // 颜色混合
                        // mapColor += layer.albedo * weight;
                        //
                        // #if defined(_NORMALMAP)
                        // // 法线混合（简单加权，可能需要规范化）
                        // mapNormal += layer.normal * weight;
                        // #endif
                    }                    
                }
                
                // 把有权重的地形，重新计算权重值
                float sumHeight = 0;
                // half transition = max(_HeightTransition, 1e-5);
                const half transition = 0.5;
                
                for(uint layerIndex = 0; layerIndex < paintedLayerIndex; layerIndex++)
                {
                    blendHeight[layerIndex] = max(blendHeight[layerIndex] - maxHeight + transition, 0)
                        * blendWeight[layerIndex];
                    sumHeight += blendHeight[layerIndex];
                }

                // 混合颜色
                for(uint layerIndex = 0; layerIndex < paintedLayerIndex; layerIndex++)
                {
                    // 权重归一化
                    half w = blendHeight[layerIndex] / sumHeight;
                    mapColor += terrainLayer[layerIndex].albedo * w;
                    #if defined(_NORMALMAP)
                    // 法线混合（简单加权，可能需要规范化）
                    mapNormal += terrainLayer[layerIndex].normal * w;
                    #endif
                    mapSM = terrainLayer[layerIndex].sm;
                }

                // 如果因为一些原因导致权重为0，则用第0层作为Base层渲染
                if(paintedLayerIndex == 0)
                {
                    LayerSample layer = SampleLayer(baseUV, 0);
                    mapColor = layer.albedo;
                    #if defined(_NORMALMAP)
                    mapNormal = layer.normal;
                    #endif
                    mapSM = layer.sm;
                }
                
                mapColor.a = 1;
                // return mapColor;
                // #if defined(_NORMALMAP)
                // return half4(mapNormal,1);
                // #endif

                #ifdef _BAKEMODE
                return mapColor;
                #endif

                

                #if defined(_NORMALMAP)
                // 法线转换到世界空间
                half3x3 tangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
                mapNormal = TransformTangentToWorld(mapNormal, tangentToWorld);
                // return half4(mapNormal,1);
                #else
                mapNormal = input.normalWS;
                #endif

                

                // -------------------------------------
                //PBR光照
                BRDFData brdfData = (BRDFData)0;
                InitializeBRDFData(mapColor.rgb, mapSM.g, half3(0.0h, 0.0h, 0.0h), mapSM.r, mapColor.a, brdfData);

                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);     //主光计算阴影
                Light mainLight = GetMainLight(shadowCoord);
                half3 viewDirection = SafeNormalize(GetCameraPositionWS() - input.positionWS);
                half3 color = LightingPhysicallyBased(brdfData, mainLight, mapNormal, viewDirection);
                half3 bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, mapNormal);
                half3 GIcolor = GlobalIllumination(brdfData, bakedGI, 1, mapNormal, viewDirection);

                color += GIcolor;

                return half4(color, 1);


                // // -------------------------------------
                // //PBR光照
                // BRDFData brdfData = (BRDFData)0;
                // InitializeBRDFData(pbrData.albedo, pbrData.metallic, half3(0.0h, 0.0h, 0.0h), pbrData.smoothness, pbrData.alpha, brdfData);
                //
                // half fogCoord = input.fogFactorAndVertexLight.x;
                // half3 vertexLighting = input.fogFactorAndVertexLight.yzw;
                //
                // float4 shadowCoord = TransformWorldToShadowCoord(pbrData.positionWS); //主光计算阴影
                // Light mainLight = GetMainLight(shadowCoord);
                //
                // half4 color = GetDirectLightColor(mainLight, brdfData, pbrData);
                // half3 GIcolor = GetGIColor(input, mainLight, brdfData, pbrData);
                //
                // color.rgb += GIcolor;
                //
                // #ifdef _ADDITIONAL_LIGHTS
                // color.rgb += GetAdditionalLightColor(brdfData, pbrData);
                // #endif

                // -------------------------------------

                // return color;
            }
            ENDHLSL
        }
        //Shadow
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

            // #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            #include "Assets/Art/Shaders/Library/KIIFPBR.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                Light mainLight = GetMainLight();

            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 lightDirectionWS = normalize(_LightPosition - positionWS);
            #else
                float3 lightDirectionWS = _LightDirection;
            #endif

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

            #if UNITY_REVERSED_Z
                positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #else
                positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #endif

                return positionCS;
            }

            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);

                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionCS = GetShadowPositionHClip(input);
                return output;
            }

            half4 ShadowPassFragment(Varyings input) : SV_TARGET
            {
                Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                return 0;
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
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            // #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            #include "Assets/Art/Shaders/Library/KIIFPBR.hlsl"

            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }


            half4 DepthOnlyFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                return 0;
            }
            ENDHLSL
        }
        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMeta

            #pragma shader_feature _SPECULAR_SETUP
            #pragma shader_feature _EMISSION
            // #pragma shader_feature _SMAEMAP
            #pragma shader_feature _METALLICSPECGLOSSMAP
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma shader_feature _SPECGLOSSMAP

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"
            #include "Assets/Art/Shaders/Library/KIIFMetaPass.hlsl"

            ENDHLSL
        }
    }
//    CustomEditor "PBR_Base_ShaderGUI"
}
