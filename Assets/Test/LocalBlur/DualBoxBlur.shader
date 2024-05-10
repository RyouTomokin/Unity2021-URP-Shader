Shader "Hidden/DualBoxBlur"
{
    Properties
    {
    	[HideInInspector] _MainTex("MainTex", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline"}
        LOD 100

        Cull Off ZWrite Off ZTest Always

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float4 _MainTex_TexelSize;
        float _BlurRange;
        CBUFFER_END

        struct Attributes
        {
            float4 positionOS   : POSITION;
            float2 texcoord     : TEXCOORD0;
        };

        struct Varyings
        {
            float2 uv           : TEXCOORD0;
            float4 positionCS   : SV_POSITION;
        };

        TEXTURE2D(_MainTex);                          SAMPLER(sampler_MainTex);

        half3 BoxFliter(float2 uv, float t)
        {
            float4 d = _MainTex_TexelSize.xyxy * float4(-t, -t, t, t);

            half3 col = 0;
            // 平均盒体采样
            col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + d.xy).rgb * 0.25h;
            col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + d.zy).rgb * 0.25h;
            col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + d.xw).rgb * 0.25h;
            col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + d.zw).rgb * 0.25h;

            return saturate(col);
        }
        
        Varyings VertDefault (Attributes v)
        {
            Varyings output;
            VertexPositionInputs  PositionInputs = GetVertexPositionInputs(v.positionOS.xyz);
            output.positionCS = PositionInputs.positionCS;
            output.uv = v.texcoord;

            return output;
        }

        half4 FragBoxBlur (Varyings input) : SV_Target
        {
            half4 col = half4(BoxFliter(input.uv, _BlurRange).rgb, 1);

            return col;
        }

        half4 FragCombine (Varyings input) : SV_Target
        {

            half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);

            return col;
        }

        ENDHLSL
        
        //Box模糊
        Pass                
        {
            Name "BoxBlur"
            
            ZWrite Off ZTest Always
            
            HLSLPROGRAM
            
            #pragma vertex VertDefault
            #pragma fragment FragBoxBlur
            
            ENDHLSL
        }
        //模糊合并
        Pass               
        {
            Name "BlurCombine"

            ZWrite Off ZTest Always

            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment FragCombine
            
            ENDHLSL
        }
    }
}