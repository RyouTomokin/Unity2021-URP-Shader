Shader "KIIF/Special/PostProcessFog"
{
    Properties
    {
    	[MainColor][HDR] _BaseColor("Color", Color) = (1,1,1,1)
    	[MainTexture] _BaseMap("雾纹理", 2D) = "white" {}
        
        _FogDistance("雾深度比例", Float) = 1
    	
        _FogStartDistance("雾开始距离", Float) = 0
        _FogFarDistance("雾结束距离", Float) = 10
    	
        _PlaneHeight("平面高度", Float) = 0
    	_FogScale("雾缩放大小", Float) = 1
    	_FogSpeed("雾流动速度", Vector) = (0,0,0,0)
        _BumpHeight("视差高度", Float) = 0.5
        
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
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True" "Queue" = "Transparent"}
        LOD 300
        //后处理深度雾
        Pass
        {
            Name "PostProcessFog"
            Tags{"LightMode" = "UniversalForward"}
            Blend SrcAlpha OneMinusSrcAlpha
            Stencil
            {
                Ref [_RefValue]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }
        	Zwrite Off
            
            HLSLPROGRAM

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Assets/Art/Shaders/Library/KIIFCommon.hlsl"

            struct Attributes
			{
				float4 positionOS	: POSITION;
				float4 normalOS		: NORMAL;
            	float4 tangentOS    : TANGENT;
				float2 texcoord     : TEXCOORD0;
			};

			struct Varyings
			{
				float2 uv                       : TEXCOORD0;
			    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

			    float3 positionWS               : TEXCOORD2;

				float3 normalWS                 : TEXCOORD3;    // xyz: normal
			    float3 tangentWS                : TEXCOORD4;    // xyz: tangent
			    float3 bitangentWS              : TEXCOORD5;    // xyz: bitangent

			    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
			    float4 shadowCoord              : TEXCOORD7;
			    #endif
			    #ifdef _SCREENPOSITION_ON
			    float4 screenPos                : TEXCOORD8;
			    #endif
			    

			    float4 positionCS               : SV_POSITION;
			};

			CBUFFER_START(UnityPerMaterial)
            half4 _BaseColor;
            float4 _BaseMap_ST;
			float _FogDistance;
			float _FogStartDistance;
			float _FogFarDistance;
			float _PlaneHeight;
			float _FogScale;
			float4 _FogSpeed;
			float _BumpHeight;
			CBUFFER_END

            TEXTURE2D(_BaseMap);			SAMPLER(sampler_BaseMap);

			Varyings vert(Attributes input)
			{
				Varyings output = (Varyings)0;

				output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
				
				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
				VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS.xyz, input.tangentOS);
				
				output.positionCS = vertexInput.positionCS;
				output.positionWS = vertexInput.positionWS;
				output.normalWS = normalInput.normalWS;
				output.tangentWS = normalInput.tangentWS;
				output.bitangentWS = normalInput.bitangentWS;
				
				return output;
			}

            half4 frag(Varyings input) : SV_Target
            {
            	// -------------------------------------
                // 初始化粒子参数
                
                // 要计算用于采样深度缓冲区的 UV 坐标，
                // 请将像素位置除以渲染目标分辨率
                // _ScaledScreenParams。
                float2 screenUV = input.positionCS.xy / _ScaledScreenParams.xy;
                // 从摄像机深度纹理中采样深度。
                #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(screenUV);
                #else
                    //  调整 Z 以匹配 OpenGL 的 NDC ([-1, 1])
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif

            	// 重映射场景深度
            	float depthRemap = max((depth * 1000 - _FogStartDistance) * _FogDistance , 0);
            	depthRemap = smoothstep(1, 0, depthRemap);
            	// return half4(depthRemap * half3(1,1,1), 1);

                // -------------------------------------
                // 重建世界空间位置。
                float3 worldPos = ComputeWorldSpacePosition(screenUV, depth, UNITY_MATRIX_I_VP);

            	float3 cameraPos = _WorldSpaceCameraPos;            	

            	float fogPlaneHeight = cameraPos.y - _PlaneHeight;

            	float3 cameraDir = normalize(worldPos - cameraPos);
            	float3 offsetLen = (fogPlaneHeight - worldPos.y) * rcp(cameraDir.y);
            	// 计算平面的新坐标
            	float3 planePos = offsetLen * cameraDir + worldPos;
            	// return half4(frac(planePos.xz), 0, 1);

            	float2 uv = TRANSFORM_TEX(planePos.xz, _BaseMap) / _PlaneHeight;
            	float2 fogUV0 = uv + _Time.y * _FogSpeed.xy;
            	fogUV0 *= _FogScale;
            	float2 fogUV1 = uv + _Time.y * _FogSpeed.zw;
            	fogUV1 *= _FogScale;
            	
            	half3x3 TangentToWorld = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);
            	// half3 cameraDirection =  -1 * mul((float3x3)UNITY_MATRIX_M, transpose(mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V)) [2].xyz);
            	half3 cameraVector = normalize(cameraPos - input.positionWS);
            	fogUV1 = BumpOffset(TangentToWorld, cameraVector, fogUV1, _BumpHeight);

            	// 采样纹理图
            	half4 fogTex0 = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, fogUV0);
            	// return fogTex0;
            	half4 fogTex1 = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, fogUV1);
            	half density = fogTex0.r + fogTex0.r * fogTex1.r;
            	// density = fogTex1.r;
            	// return half4(density, 0,0,1);

            	// 雾密度
            	density *= depthRemap;
            	density += depthRemap;
            	density = saturate(density);
				// 雾最远的裁切距离
            	density *= smoothstep(_FogFarDistance, 0, length(offsetLen));
            	// 只显示在下方的雾
				density *= step(cameraDir.y, 0);

            	half4 color = _BaseColor;
            	color.a *= density;
                return color;
            }
            ENDHLSL
        }
    }
}
