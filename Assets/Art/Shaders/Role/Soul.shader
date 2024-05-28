Shader "KIIF/Soul"
{
    Properties
    {
    	[MainColor][HDR] _BaseColor("Color", Color) = (0.5, 0.5, 0.5,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
    	_ColorIntensity("ColorIntensity", Float) = 1
    	
		[HDR]_InnerColor("InnerColor", Color) = (0, 0.3, 0.9, 1)
		[HDR]_OuterColor("OuterColor", Color) = (0, 0.45, 0.75, 1)
		_FresnelPower("FresnelPower", Float) = 5
		_Dissolve("Dissolve", Range( 0 , 1)) = 0
        _DissolveMap("溶解贴图", 2D) = "white" {}
        _DissolveSpeed("溶解流动速度", Float) = 0
        _DissolveMaskSoft("溶解遮罩软硬", Float) = 0.5
        _DissolveMaskRange("溶解遮罩范围", Float) = 0.5
		_Alpha("Alpha", Range( 0 , 1)) = 1
    }
    SubShader
    {
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "Queue" = "Transparent"}
        
        Pass
		{
			Name "Forward"
			Tags { "LightMode"="UniversalForward" }
			
			Blend SrcAlpha OneMinusSrcAlpha , One OneMinusSrcAlpha
			ZWrite Off
			ZTest Equal
			Offset 0 , 0
			ColorMask RGBA
			

			HLSLPROGRAM
			
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x

			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			// #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
			#include "Assets/Art/Shaders/Library/KIIFCommon.hlsl"
			
			#define ASE_NEEDS_FRAG_WORLD_POSITION

			#pragma multi_compile_instancing


			struct VertexInput
			{
				float4 positionOS	: POSITION;
				float3 normalOS		: NORMAL;
				float2 texcoord     : TEXCOORD0;
				
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct VertexOutput
			{
				float2 uv                       : TEXCOORD0;
				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
				float3 positionWS				: TEXCOORD1;
				#endif
				#ifdef ASE_FOG
				float fogFactor					: TEXCOORD2;
				#endif
				float4 normalWS					: TEXCOORD3;
				float4 positionCS				: SV_POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _BaseMap_ST;
			half4 _BaseColor;
			half _ColorIntensity;
			float4 _InnerColor;
			float4 _OuterColor;
			float _FresnelPower;
			float _Dissolve;
			float4 _DissolveMap_ST;
			half _DissolveSpeed;
			half _DissolveMaskSoft;
			half _DissolveMaskRange;
			float _Alpha;
			CBUFFER_END
			TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_DissolveMap);        SAMPLER(sampler_DissolveMap);

			VertexOutput vert ( VertexInput v  )
			{
				VertexOutput o = (VertexOutput)0;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.uv = v.texcoord;

				o.normalWS.xyz = TransformObjectToWorldNormal(v.normalOS);
				
				o.normalWS.w = 0;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
					float3 defaultVertexValue = v.vertex.xyz;
				#else
					float3 defaultVertexValue = float3(0, 0, 0);
				#endif
				float3 vertexValue = defaultVertexValue;
				#ifdef ASE_ABSOLUTE_VERTEX_POS
					v.vertex.xyz = vertexValue;
				#else
					v.positionOS.xyz += vertexValue;
				#endif

				VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
				
				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
				o.positionWS = vertexInput.positionWS;
				#endif
				o.positionCS = vertexInput.positionCS;
				
				#ifdef ASE_FOG
				o.fogFactor = ComputeFogFactor( positionCS.z );
				#endif
				return o;
			}

			half4 frag ( VertexOutput IN  ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID( IN );
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( IN );

				#if defined(ASE_NEEDS_FRAG_WORLD_POSITION)
				float3 worldPosition = IN.positionWS;
				#endif

				//菲涅尔亮边
				float3 worldViewDir = normalize(_WorldSpaceCameraPos.xyz - worldPosition);
				float NdotV = dot(IN.normalWS.xyz, worldViewDir);
				float fresnel = pow(1.0 - NdotV, _FresnelPower);
				float4 soulColor = lerp(_InnerColor, _OuterColor, fresnel);
				// return soulColor;

				//颜色贴图
				float2 uv = IN.uv.xy;
				float2 baseUV = TRANSFORM_TEX(uv, _BaseMap);
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);
				color *= _BaseColor;

				// Screen Blend
				color = lerp(color, 1 - (1 - soulColor) * (1 - color), 0.5) * _ColorIntensity;
				color.a = saturate(soulColor.a);

				// return color;
				//溶解
				half2 dissolveUV = uv * _DissolveMap_ST.xy + _DissolveSpeed * _DissolveMap_ST.zw * _Time.y;
                half4 dissolveMap = SAMPLE_TEXTURE2D(_DissolveMap, sampler_DissolveMap, dissolveUV);

				float4 objectPosition = float4( GetObjectToWorldMatrix()[0][3],
					GetObjectToWorldMatrix()[1][3],
					GetObjectToWorldMatrix()[2][3],
					GetObjectToWorldMatrix()[3][3]);
				// 局部空间中，Y方向的高度
				half dissolveMask = saturate((worldPosition.y - objectPosition.y) * _DissolveMaskSoft + _DissolveMaskRange);
				half2 dissolve_side = Dissolve(_Dissolve, dissolveMap.r, dissolveMask);

				// color.rgb += dissolve_side.g * _OuterColor;
				color.a = saturate(color.a - (1 - _Alpha)) * saturate(dissolve_side.r + dissolveMask);
				
				// float3 BakedAlbedo = 0;
				// float3 BakedEmission = 0;
				// float3 Color = color;
				// float Alpha = saturate( ( saturate( (lerpResult9).a ) - ( 1.0 - _Alpha ) ) );
				// float AlphaClipThreshold = 0.5;

				#ifdef _ALPHATEST_ON
					clip( Alpha - AlphaClipThreshold );
				#endif

				#ifdef LOD_FADE_CROSSFADE
					LODDitheringTransition( IN.clipPos.xyz, unity_LODFade.x );
				#endif

				#ifdef ASE_FOG
					Color = MixFog( Color, IN.fogFactor );
				#endif

				return color;
			}
			ENDHLSL
        }

    	// PreDepth Pass
        Pass
        {
        	ColorMask 0
            ZTest LEqual
            ZWrite On
            Cull Back
        }
    }
}
