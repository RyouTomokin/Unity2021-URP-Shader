Shader "KIIF/Effect/ParallaxMapping"
{
    Properties
    {
		_BaseColor("BaseColor", Color) = (1,1,1,1)
		_BaseMap("BaseMap", 2D) = "white" {}
		_ColorIntensity("ColorIntensity(Custom1.y)", Range( 0 , 10)) = 1
		_DarkColor("DarkColor", Color) = (0,0,0,1)
		[HDR]_EmissionColor("EmissionColor", Color) = (0,0,0,1)
		[NoScaleOffset] _EmissionMap("EmissionMap", 2D) = "black" {}
		_ParallaxScale("ParrallaxScale", Float) = 0
		[NoScaleOffset] _HeightMap("HeightMap", 2D) = "white" {}
		_Dissolve("Dissolve(Custom1.x)", Range(0, 1)) = 0
        _DissolveMaskSharpen("DissolveMaskSharpen", Range(0.0, 0.5)) = 0
//		[Toggle]_UseCustom1X("UseCustom1X", Float) = 0
		_DissolveMap("DissolveMap", 2D) = "white" {}
//		_StreamMap("StreamMap", 2D) = "white" {}
//		[HDR]_StreamColor("StreamColor", Color) = (0,0,0,1)
//		_StreamTiling("StreamTiling", Vector) = (1,1,0,0)

        [Space(20)]
        [Header(Stencil)]
        [Space]
        _RefValue("Ref Value",Int) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8      //默认Always
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep

//        [HideInInspector] _Surface("__surface", Float) = 0.0
//        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 0.0
        [HideInInspector] _Cull("__cull", Float) = 2.0
    }
    SubShader
    {
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "Queue" = "Transparent+50"}
        LOD 300
        //ForwardLit
        Pass
        {
//            Name "ForwardLit"
//            Tags{"LightMode" = "UniversalForward"}

            Stencil
            {
                Ref [_RefValue]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }

            Blend SrcAlpha OneMinusSrcAlpha
//            ZTest Always
            ZWrite off
            Cull [_Cull]

            HLSLPROGRAM

            // #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords

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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ParticlesInstancing.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
            #include "Assets/Art/Shaders/Library/KIIFCommon.hlsl"

            struct AttributesUnlit
            {
                float4 positionOS               : POSITION;
                float4 uv                       : TEXCOORD0;
                half4 color                     : COLOR;

                float3 normalOS                 : NORMAL;
                float4 tangentOS                : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VaryingsUnlit
            {
                float4 positionCS               : SV_POSITION;
                half4 color                     : COLOR;
                float4 uv                       : TEXCOORD0;
                float3 positionWS               : TEXCOORD2;
                float3 normalWS                 : TEXCOORD3;
                float3 tangentWS                : TEXCOORD4;
                float3 bitangentWS              : TEXCOORD5;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _EmissionColor;
            float4 _DarkColor;
			float4 _BaseMap_ST;
			float4 _HeightMap_ST;
			float4 _DissolveMap_ST;
			// float4 _StreamTiling;
			// float4 _StreamColor;
			float4 _BaseColor;
			float _ParallaxScale;
			float _ColorIntensity;
			float _Dissolve;
			float _DissolveMaskSharpen;
            CBUFFER_END

            TEXTURE2D(_BaseMap);                SAMPLER(sampler_BaseMap);
            TEXTURE2D(_EmissionMap);            SAMPLER(sampler_EmissionMap);
            TEXTURE2D(_HeightMap);              SAMPLER(sampler_HeightMap);
            // TEXTURE2D(_StreamMap);              SAMPLER(sampler_StreamMap);
            TEXTURE2D(_DissolveMap);            SAMPLER(sampler_DissolveMap);

            VaryingsUnlit vert_Unlit(AttributesUnlit input)
            {
                VaryingsUnlit output = (VaryingsUnlit)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);


                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionWS = vertexInput.positionWS;
                output.normalWS = normalInput.normalWS;
                output.tangentWS = normalInput.tangentWS;
                output.bitangentWS = normalInput.bitangentWS;

                output.uv = input.uv;
                output.color = input.color;

                output.positionCS = vertexInput.positionCS;

                // -------------------------------------

                return output;
            }

            inline float2 POM( Texture2D heightMap, float2 uvs, float2 dx, float2 dy,
            	float3 normalWorld, float3 viewWorld, float3 viewDirTan, int minSamples, int maxSamples,
            	float parallax, float refPlane, float2 tilling, float2 curv, int index )
			{
				float3 result = 0;
				int stepIndex = 0;
				int numSteps = floor(lerp( (float)maxSamples, (float)minSamples, saturate( dot( normalWorld, viewWorld ) ) ));
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

            half4 frag_Unlit(VaryingsUnlit input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // -------------------------------------

                float2 uv = input.uv.xy;
                float customDissolve = input.uv.z;
                float customIntensity = input.uv.w;
                // float2 heightUV = TRANSFORM_TEX(uv, _HeightMap);
                float2 baseUV = TRANSFORM_TEX(uv, _BaseMap);
                // half height = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, heightUV);
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

                half3x3 TangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
                float3 viewDirTS = TransformWorldToTangent(viewDirWS, TangentToWorld);
                float2 parallax_uv_offset = POM( _HeightMap, input.uv, ddx(input.uv), ddy(input.uv),
					input.normalWS, viewDirWS, viewDirTS, 1, 8,
					_ParallaxScale, 0, _HeightMap_ST.xy, float2(0,0), 0 );
                // float2 Offset = (height - 1) * viewDirTS.xy * _ParallaxScale + baseUV;

                // 采样纹理颜色
                // -------------------------------------
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);
                half baseAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv).a;
                baseColor.a = baseAlpha;
                baseColor *= _BaseColor;

                float2 parallaxUV = parallax_uv_offset;
                half3 emissionColor = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, parallaxUV).rgb;
                half emissionAlpha = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).a;

                float3 heightColor = lerp(0, _DarkColor, emissionColor);
                baseColor.rgb = lerp(baseColor.rgb, heightColor, emissionAlpha);
                baseColor.rgb += emissionColor * _EmissionColor * emissionAlpha * _ColorIntensity * customIntensity;
                baseColor.a = lerp(baseColor.a, emissionAlpha, emissionAlpha);

                // -------------------------------------
                half2 dissolveUV = uv * _DissolveMap_ST.xy + _DissolveMap_ST.zw * _Time.y;
                half2 dissolve = SAMPLE_TEXTURE2D(_DissolveMap, sampler_DissolveMap, dissolveUV).rg;    //dissolve和dissolveMask
                half dissolveFactor = customDissolve + _Dissolve;
                half dissolveMask_1 = lerp(0 - _DissolveMaskSharpen, 1 + _DissolveMaskSharpen, dissolve.g);
                dissolveMask_1 -= lerp(-1, 1, dissolveFactor);
                dissolveMask_1 = (dissolveMask_1 - _DissolveMaskSharpen) / (1 - 2 * _DissolveMaskSharpen);
                dissolveMask_1 = saturate(dissolveMask_1);

                half dissolve_1 = lerp(0, 1, dissolve);
                dissolve_1 += dissolveMask_1;
                dissolve_1 *= dissolveMask_1;

                // -------------------------------------
                half3 color = baseColor.rgb * input.color.rgb;
                half alpha = baseColor.a * dissolve_1 * input.color.a;
                alpha = saturate(alpha);

                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
}
