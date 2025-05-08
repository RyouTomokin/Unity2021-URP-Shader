Shader "KIIF/Effect/KawaseBlur"
{
    Properties
    {
        [NoScaleOffset][MainTexture] _MainTex ("Texture", 2D) = "white" {}
        _Offset ("Offset", Range(0, 10)) = 1.0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalRenderPipeline" }
        Pass
        {
            Name "KawaseBlurHighQuality"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            float _Offset;

            Varyings vert (Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.uv;
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                float2 uv = i.uv;
                float2 texel = _MainTex_TexelSize.xy * _Offset;

                half3 col = half3(0,0,0);

                // 16 directions (including diagonals and half-diagonals)
                col += tex2D(_MainTex, uv + texel * float2(1,1)).rgb;
                col += tex2D(_MainTex, uv + texel * float2(-1,1)).rgb;
                col += tex2D(_MainTex, uv + texel * float2(1,-1)).rgb;
                col += tex2D(_MainTex, uv + texel * float2(-1,-1)).rgb;

                col += tex2D(_MainTex, uv + texel * float2(2,0)).rgb;
                col += tex2D(_MainTex, uv + texel * float2(-2,0)).rgb;
                col += tex2D(_MainTex, uv + texel * float2(0,2)).rgb;
                col += tex2D(_MainTex, uv + texel * float2(0,-2)).rgb;

                col += tex2D(_MainTex, uv + texel * float2(2,1)).rgb;
                col += tex2D(_MainTex, uv + texel * float2(-2,1)).rgb;
                col += tex2D(_MainTex, uv + texel * float2(2,-1)).rgb;
                col += tex2D(_MainTex, uv + texel * float2(-2,-1)).rgb;

                col += tex2D(_MainTex, uv + texel * float2(1,2)).rgb;
                col += tex2D(_MainTex, uv + texel * float2(-1,2)).rgb;
                col += tex2D(_MainTex, uv + texel * float2(1,-2)).rgb;
                col += tex2D(_MainTex, uv + texel * float2(-1,-2)).rgb;

                col /= 16.0;

                return half4(col, 1.0);
            }
            ENDHLSL
        }
    }
}