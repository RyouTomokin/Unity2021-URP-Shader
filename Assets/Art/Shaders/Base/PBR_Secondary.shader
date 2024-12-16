Shader "KIIF/PBR_Secondary"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
    	[Toggle(_PARALLAX_ON)] _Parallax("开启视差", Float) = 0.0
        _HeightMap("Height", 2D) = "white" {}
    	_HeightScale("HeightScale", Float) = 0.0
        [Toggle(_ALPHATEST_ON)] _AlphaTest("Alpha Clipping", Float) = 0.0
        _Cutoff("剔除阈值", Range(0.0, 1.0)) = 0.5
        _BumpScale("法线强度", Float) = 1.0
        [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
        [NoScaleOffset] _SMAEMap("R:光滑度 G:金属度 B:AO A:自发光", 2D) = "white" {}
        _Smoothness("光滑度", Range(0.0, 1.0)) = 0.5
        [Gamma] _Metallic("金属度", Range(0.0, 1.0)) = 0.0
        _OcclusionStrength("AO", Range(0.0, 1.0)) = 1.0
        [HDR] _EmissionColor("自发光颜色", Color) = (0,0,0)
        _EmissionStrength("自发光强度", Range(0.0, 1.0)) = 0.0
        
        [Space(20)]
        [Toggle(_SECONDARY_ON)] _Secondary("细节贴图", float) = 0
        [Toggle(_SECONDARY_PARALLAX_ON)] _Secondary_Parallax("细节贴图使用视差", float) = 0
        _SecondaryColor("细节颜色色调", Color) = (1,1,1,1)
        _SecondaryMap("细节颜色贴图", 2D) = "white" {}
        [NoScaleOffset] _SecondaryBumpMap("细节法线贴图", 2D) = "bump" {}
        _SecondaryBumpScale("细节法线强度", Float) = 1
        [NoScaleOffset] _SecondarySMAEMap("R:光滑度 G:金属度 B:AO", 2D) = "white" {}
        _NoiseMap("噪波图(控制细节贴图范围)", 2D) = "white" {}
        _NoiseStrength("噪波强度", Range(-1, 1)) = 0
        _NoiseContrast("噪波图的过渡", Range(0, 0.499)) = 0
        
        [Space(20)]
        [Header(Stencil)]
        [Space]
        _RefValue("Ref Value",Int) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8      //默认Always
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep
        
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
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
            Stencil
            {
                Ref [_RefValue]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }
            ZWrite[_ZWrite]
            Cull[_Cull]
            
            HLSLPROGRAM

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _PARALLAX_ON
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _SMAEMAP
            #pragma shader_feature _SECONDARY_ON
            #pragma shader_feature _SECONDARY_COLORMAP
            #pragma shader_feature _SECONDARY_NORMALMAP
            #pragma shader_feature _SECONDARY_SMAEMAP
            #pragma shader_feature _SECONDARY_PARALLAX_ON
            #pragma shader_feature _NOISEMAP

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
            #include "Assets/Art/Shaders/Library/KIIFPBR.hlsl"
            #include "Assets/Art/Shaders/Library/SecondaryFunction.hlsl"

            float _HeightScale;
            float4 _HeightMap_ST;
            TEXTURE2D(_HeightMap);			SAMPLER(sampler_HeightMap);

            // //浮雕贴图
            // float2 ReliefMapping(float2 uv, real3 viewDirTS)
            // {
            //     float2 offlayerUV = viewDirTS.xy / viewDirTS.z * _HeightScale;
            //     float RayNumber = 20;
            //     float layerHeight = 1.0 / RayNumber;
            //     float2 SteppingUV = offlayerUV / RayNumber;
            //     float offlayerUVL = length(offlayerUV);
            //     float currentLayerHeight = 0;
            //     
            //     float2 offuv= float2(0,0);
            //     for (int i = 0; i < RayNumber; i++)
            //     {
            //         offuv += SteppingUV;
            //
            //         float currentHeight = tex2D(_HeightMap, uv + offuv).r;
            //         currentLayerHeight += layerHeight;
            //         if (currentHeight < currentLayerHeight)
            //         {
            //             break;
            //         }
            //     }
            //
            //     float2 T0 = uv-SteppingUV, T1 = uv + offuv;
            //
            //     for (int j = 0;j<20;j++)
            //     {
            //         float2 P0 = (T0 + T1) / 2;
            //
            //         float P0Height = tex2D(_HeightMap, P0).r;
            //
            //         float P0LayerHeight = length(P0) / offlayerUVL;
            //
            //         if (P0Height < P0LayerHeight)
            //         {
            //             T0 = P0;
            //
            //         }
            //         else
            //         {
            //             T1= P0;
            //         }
            //
            //     }
            //
            //     return (T0 + T1) / 2 - uv;
            // }

            inline float2 POM( Texture2D heightMap, float2 uvs, float2 dx, float2 dy,
            	float3 normalWorld, float3 viewWorld, float3 viewDirTan, int minSamples, int maxSamples,
            	float parallax, float refPlane, float2 tilling, float2 curv, int index )
			{
				float3 result = 0;
				int stepIndex = 0;
				int numSteps = ( int )lerp( (float)maxSamples, (float)minSamples, saturate( dot( normalWorld, viewWorld ) ) );
				float layerHeight = 1.0 / numSteps;
				float2 plane = parallax * ( viewDirTan.xy / viewDirTan.z );
				uvs.xy += refPlane * plane;
				float2 deltaTex = -plane * layerHeight;
				float2 prevTexOffset = 0;
				float prevRayZ = 1.0f;
				float prevHeight = 0.0f;
				float2 currTexOffset = deltaTex;
				float currRayZ = 1.0f - layerHeight;
				float currHeight = 0.0f;
				float intersection = 0;
				float2 finalTexOffset = 0;
				while ( stepIndex < numSteps + 1 )
				{
			 		// currHeight = tex2Dgrad( heightMap, uvs + currTexOffset, dx, dy ).r;
					currHeight = SAMPLE_TEXTURE2D_GRAD(heightMap, sampler_HeightMap, uvs + currTexOffset, dx, dy).r;
			 		if ( currHeight > currRayZ )
			 		{
			 	 		stepIndex = numSteps + 1;
			 		}
			 		else
			 		{
			 	 		stepIndex++;
			 	 		prevTexOffset = currTexOffset;
			 	 		prevRayZ = currRayZ;
			 	 		prevHeight = currHeight;
			 	 		currTexOffset += deltaTex;
			 	 		currRayZ -= layerHeight;
			 		}
				}
				int sectionSteps = 2;
				int sectionIndex = 0;
				float newZ = 0;
				float newHeight = 0;
				while ( sectionIndex < sectionSteps )
				{
			 		intersection = ( prevHeight - prevRayZ ) / ( prevHeight - currHeight + currRayZ - prevRayZ );
			 		finalTexOffset = prevTexOffset + intersection * deltaTex;
			 		newZ = prevRayZ - intersection * layerHeight;
			 		// newHeight = tex2Dgrad( heightMap, uvs + finalTexOffset, dx, dy ).r;
					newHeight = SAMPLE_TEXTURE2D_GRAD(heightMap, sampler_HeightMap, uvs + finalTexOffset, dx, dy).r;
			 		if ( newHeight > newZ )
			 		{
			 	 		currTexOffset = finalTexOffset;
			 	 		currHeight = newHeight;
			 	 		currRayZ = newZ;
			 	 		deltaTex = intersection * deltaTex;
			 	 		layerHeight = intersection * layerHeight;
			 		}
			 		else
			 		{
			 	 		prevTexOffset = finalTexOffset;
			 	 		prevHeight = newHeight;
			 	 		prevRayZ = newZ;
			 	 		deltaTex = ( 1 - intersection ) * deltaTex;
			 	 		layerHeight = ( 1 - intersection ) * layerHeight;
			 		}
			 		sectionIndex++;
				}
				return uvs.xy + finalTexOffset;
			}
            
            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------
                //采样 初始化
            	float2 SecondaryUV = input.uv;
            	#ifdef _PARALLAX_ON
            	half3 viewDirWS = GetCameraPositionWS() - input.positionWS;
            	half3x3 TangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
            	half3 viewDirTS = TransformWorldToTangent(viewDirWS, TangentToWorld);
            	float2 parallax_uv_offset = POM( _HeightMap, input.uv, ddx(input.uv), ddy(input.uv),
					input.normalWS, viewDirWS, viewDirTS, 8, 8,
					_HeightScale, 0, _HeightMap_ST.xy, float2(0,0), 0 );
            	// return (half4(parallax_uv_offset,0,1));
                input.uv = parallax_uv_offset;
            	#ifdef _SECONDARY_PARALLAX_ON
            	SecondaryUV = parallax_uv_offset;
            	#endif
            	#endif

                PBRData pbrData;    //KIIF自定义结构体
                // PBRInitialize(input, pbrData);
                PBR_Secondary_Initialize(input, pbrData, SecondaryUV);
                
                //细节贴图
                // SecondaryFunction(input.uv, pbrData.TangentToWorld,
                //     pbrData.albedo, pbrData.smoothness, pbrData.metallic, pbrData.normalWS);
                
                //PBR光照
                BRDFData brdfData = (BRDFData)0;
                InitializeBRDFData(pbrData.albedo, pbrData.metallic, half3(0.0h, 0.0h, 0.0h), pbrData.smoothness, pbrData.alpha, brdfData);
                
                half fogCoord = input.fogFactorAndVertexLight.x;
                half3 vertexLighting = input.fogFactorAndVertexLight.yzw;
                
                float4 shadowCoord = TransformWorldToShadowCoord(pbrData.positionWS); //主光计算阴影
                Light mainLight = GetMainLight(shadowCoord);
                
                half4 color = GetDirectLightColor(mainLight, brdfData, pbrData);
                half3 GIcolor = GetGIColor(input, mainLight, brdfData, pbrData);
                
                color.rgb += GIcolor;
                
                #ifdef _ADDITIONAL_LIGHTS
                color.rgb += GetAdditionalLightColor(brdfData, pbrData);
                #endif
                
                // -------------------------------------
                color.rgb += pbrData.emissionColor;
                // color.rgb = MixFog(color.rgb, fogCoord);
                return color;
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

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
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

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
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
    CustomEditor "PBR_Secondary_ShaderGUI"
}
