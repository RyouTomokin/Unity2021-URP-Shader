Shader "Lilith/Water_Column"
{
    Properties
    {
        _WaterColor("Water Color", Color) = (1,1,1,1)
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        _HighLightColor("HighLight Color", Color) = (1,1,1,1)
        
        _BumpMap("Normal Map", 2D) = "bump" {}
        _ColumnMaskMap("Column Mask Map", 2D) = "white" {}
        _Strength("Strength", Float) = 0
        _Speed("Speed", Float) = 0
        
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
            half4 _SpecularColor;
            half4 _HighLightColor;

            half _ColorRange;
            half _ColorOffset;
            
            float4 _BumpMap_ST;
            float4 _ColumnMaskMap_ST;

            float _Strength;
            float _Speed;

            half _Cutoff;
            
            CBUFFER_END
            TEXTURE2D(_BumpMap);            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_ColumnMaskMap);      SAMPLER(sampler_ColumnMaskMap);

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
                float2 noiseUV = TRANSFORM_TEX(uv, _BumpMap);
                noiseUV.y += _Speed * _Time.y;
                
                half noiseMap = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, noiseUV).g;
                noiseMap *= _Strength;
                
                // 采样遮罩贴图
                float2 columnMaskUV = uv * _ColumnMaskMap_ST.xy + _ColumnMaskMap_ST.zw + half2(noiseMap, 0);
                half4 columnMaskMap = SAMPLE_TEXTURE2D(_ColumnMaskMap, sampler_ColumnMaskMap, columnMaskUV);

                // 颜色
                half4 color = columnMaskMap.r * _WaterColor;
                color += columnMaskMap.g * _SpecularColor;
                color = lerp(color, _HighLightColor, columnMaskMap.b);
                
                return color;
            }
            ENDHLSL
        }
    }
}
