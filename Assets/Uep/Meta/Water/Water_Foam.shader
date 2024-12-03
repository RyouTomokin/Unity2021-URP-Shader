Shader "Lilith/Water_Foam"
{
    Properties
    {
        _WaterColor("Water Color", Color) = (1,1,1,1)
        _WaterDarkColor("Water Dark Color", Color) = (1,1,1,1)
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        _HighLightColor("HighLight Color", Color) = (1,1,1,1)
        _FoamMap("Foam Map", 2D) = "white" {}
        _FoamMaskMap("Foam Mask Map", 2D) = "white" {}
        _ColorMaskMap("Color Mask Map", 2D) = "white" {}
        
//        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float2 uv                       : TEXCOORD0;
                // half4 color                     : COLOR;
                float4 positionOS               : POSITION;
            };

            struct Varyings
            {
                float2 uv                       : TEXCOORD0;
                // half4 color                     : COLOR;
                float4 positionCS               : SV_POSITION;
            };

            CBUFFER_START(UnityPerMaterial)

            half4 _WaterColor;
            half4 _WaterDarkColor;
            half4 _SpecularColor;
            half4 _HighLightColor;
            
            float4 _FoamMap_ST;
            float4 _FoamMaskMap_ST;
            float4 _ColorMaskMap_ST;
            
            CBUFFER_END
            TEXTURE2D(_FoamMap);            SAMPLER(sampler_FoamMap);
            TEXTURE2D(_FoamMaskMap);        SAMPLER(sampler_FoamMaskMap);
            TEXTURE2D(_ColorMaskMap);        SAMPLER(sampler_ColorMaskMap);

            Varyings vert (Attributes input)
            {
                Varyings output = (Varyings)0;;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                
                output.uv = input.uv;
                // output.color = input.color;
                return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
                float2 uv = input.uv;
                
                // 采样遮罩贴图
                float2 foamUV = uv * _FoamMap_ST.xy + _FoamMap_ST.zw * float2(_Time.y, 1);
                half foamMap = SAMPLE_TEXTURE2D(_FoamMap, sampler_FoamMap, foamUV).r;
                
                float2 foamMaskUV = uv * _FoamMaskMap_ST.xy + _FoamMaskMap_ST.zw * float2(_Time.y, 1);
                half foamMaskMap = SAMPLE_TEXTURE2D(_FoamMaskMap, sampler_FoamMaskMap, foamMaskUV).r;

                float2 maskUV = uv * _ColorMaskMap_ST.xy + _ColorMaskMap_ST.zw;
                half maskMap = SAMPLE_TEXTURE2D(_ColorMaskMap, sampler_ColorMaskMap, maskUV).r;

                // 控制颜色的渐变
                // half4 color = lerp(_WaterDarkColor, _WaterColor, saturate(uv.x * _ColorRange + _ColorOffset));
                // color += foamMap * foamMaskMap * _HighLightColor;
                half4 color = lerp(_WaterColor, _WaterDarkColor, maskMap);
                color += _SpecularColor * foamMap * (1 - maskMap);
                color += _HighLightColor * foamMaskMap * (1 - maskMap);
                return color;
            }
            ENDHLSL
        }
    }
}
