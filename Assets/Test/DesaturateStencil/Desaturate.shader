Shader "KIIF/Special/Desaturate"
{
    Properties
    {
        _Alpha("去饱和程度", Range(0, 1)) = 1.0
        
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
        //ForwardLit
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            Blend SrcAlpha OneMinusSrcAlpha
            Stencil
            {
                Ref [_RefValue]
                Comp Greater
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

            struct Attributes
			{
				float4 positionOS	: POSITION;
				float2 texcoord     : TEXCOORD0;
			};

			struct Varyings
			{
				float2 uv                       : TEXCOORD0;
				float4 positionCS				: SV_POSITION;
			};

			CBUFFER_START(UnityPerMaterial)
			float _Alpha;
			CBUFFER_END
			// TEXTURE2D(_DesaturateBuffer);		SAMPLER(sampler_DesaturateBuffer);

			Varyings vert(Attributes input)
			{
				Varyings output = (Varyings)0;

				output.uv = input.texcoord;
				
				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
				
				output.positionCS = vertexInput.positionCS;
				
				return output;
			}

            half4 frag(Varyings input) : SV_Target
            {
				
            	// half4 desaturateColor =  SAMPLE_TEXTURE2D(_DesaturateBuffer, sampler_DesaturateBuffer, input.uv);

            	half2 uv = input.uv;
                half4 color;
            	color.rgb = SampleSceneColor(uv);
            	color.rgb = Desaturate(color.rgb, 0);
            	color.a = _Alpha;
                return color;
            }
            ENDHLSL
        }
    }
}
