Shader "KIIF/Special/DecryptionPath"
{
    Properties
    {    	
    	[MainColor][HDR] _BaseColor("Color", Color) = (1,1,1,1)
    	_BaseSpeed("纹理流动速度", Float) = 0
		[MainTexture] _BaseMap("BaseMap(offset为流动方向)", 2D) = "white" {}
    	
    	_Distance("Distance", Float) = 0
		_Width("Width", Float) = 2
    	
    	[Space(20)]
    	_MaskSpeed("遮罩流动速度", Float) = 0
    	_MaskMap("遮罩图(offset为流动方向)", 2D) = "white" {}
    	
    	[Space(20)]
		_TwistSpeed("扭曲流动速度", Float) = 0
        _TwistMap("扭曲贴图(offset为流动方向)", 2D) = "white" {}
        _TwistStrength("扭曲强度", Float) = 0
    	
    	[Space(20)]
		_OffsetStrength("顶点偏移强度", Float) = 0
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
			Offset 0 , 0
			ColorMask RGBA
			

			HLSLPROGRAM
			
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x

			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			
			#define REQUIRES_WORLD_SPACE_POS_INTERPOLATOR

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
				#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
				float3 positionWS				: TEXCOORD1;
				#endif
				float4 normalWS					: TEXCOORD3;
				float4 positionCS				: SV_POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			CBUFFER_START(UnityPerMaterial)
			float4 _BaseMap_ST;
			half4 _BaseColor;
			half _BaseSpeed;
			half _Distance;
			half _Width;
			
			half _MaskSpeed;
			float4 _MaskMap_ST;

			half _TwistSpeed;
			float4 _TwistMap_ST;
			half _TwistStrength;

			float _OffsetStrength;
			CBUFFER_END
			TEXTURE2D(_BaseMap);            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MaskMap);			SAMPLER(sampler_MaskMap);
            TEXTURE2D(_TwistMap);			SAMPLER(sampler_TwistMap);

			VertexOutput vert ( VertexInput v  )
			{
				VertexOutput o = (VertexOutput)0;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.uv = v.texcoord;

				o.normalWS.xyz = TransformObjectToWorldNormal(v.normalOS);
				//世界空间顶点偏移
				half2 offsetUV = v.texcoord * _TwistMap_ST.xy + _TwistSpeed * _TwistMap_ST.zw * _Time.y;
				half4 twistMap = SAMPLE_TEXTURE2D_LOD(_TwistMap, sampler_TwistMap, offsetUV, 0);
				float3  vertexOffset = twistMap.r * _OffsetStrength * o.normalWS.xyz;
				
				v.positionOS.xyz += vertexOffset;

				
				VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
				
				#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
				o.positionWS = vertexInput.positionWS;
				#endif
				o.positionCS = vertexInput.positionCS;
				
				return o;
			}

			half4 frag ( VertexOutput IN  ) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID( IN );
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX( IN );

				#if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
				float3 worldPosition = IN.positionWS;
				#endif

				float2 uv = IN.uv.xy;

				//扭曲
				half2 twistUV = uv * _TwistMap_ST.xy + _TwistSpeed * _TwistMap_ST.zw * _Time.y;
                half2 twist = SAMPLE_TEXTURE2D(_TwistMap, sampler_TwistMap, twistUV).rg;
                twist *= _TwistStrength;
				
				//颜色纹理
				half2 baseUV = uv * _BaseMap_ST.xy + _BaseSpeed * _BaseMap_ST.zw * _Time.y + twist;
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);

				half4 color = _BaseColor;
				half area_v = 1 - smoothstep(0, _Width, uv.y - (_Distance - _Width));
				color.a *= area_v * baseMap.r;

				//遮罩
				half2 maskUV = uv * _MaskMap_ST.xy + _MaskSpeed * _MaskMap_ST.zw * _Time.y;
                half4 maskMap = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, maskUV);
				color.a *= maskMap.r;

				return color;
			}
			ENDHLSL
        }
    }
}
