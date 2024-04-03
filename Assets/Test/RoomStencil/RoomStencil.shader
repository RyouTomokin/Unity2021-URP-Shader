Shader "Hidden/RoomStencil"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BlurRange("Blur Range",Float) = 2
        _RefValue("Ref Value",Int) = 2
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

        struct appdata
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD0;
        };

        struct v2f
        {
            float2 uv : TEXCOORD0;
            float4 positionCS : SV_POSITION;
        };

        TEXTURE2D(_MainTex);                          SAMPLER(sampler_MainTex);

        TEXTURE2D(_SourceTex);                          SAMPLER(sampler_SourceTex);

        ENDHLSL

        //提取Stencil区域 0
        Pass                
        {
            Stencil
            {
                Ref [_RefValue]
                Comp LEqual
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs  PositionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = PositionInputs.positionCS;
                o.uv = v.texcoord;

                return o;
            }


            half4 frag (v2f i) : SV_Target
            {
                // half4 col = half4(0,0,0,1);
                half4 col = half4(1,1,1,1);
                //col += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv)*0.01;
                return col;
            }
            ENDHLSL
        }
        
        //Box模糊 1
        Pass                
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs  PositionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = PositionInputs.positionCS;
                o.uv = v.texcoord;

                return o;
            }


            half4 frag (v2f i) : SV_Target
            {

                //half4 tex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                half4 col = half4(BoxFliter(i.uv, _BlurRange).rgb, 1);

                return col;
            }
            ENDHLSL
        }
         //Box模糊 + 亮度叠加 2
        Pass               
        {

            blend one zero                // 主要是这里

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs  PositionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = PositionInputs.positionCS;
                o.uv = v.texcoord;

                return o;
            }


            half4 frag (v2f i) : SV_Target
            {

                half4 tex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                // half4 col = half4(BoxFliter(i.uv, _BlurRange).rgb, 1);
                half4 col = tex;

                return col;
            }
            ENDHLSL
        }
        //合并 3
        Pass                
        {

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs  PositionInputs = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = PositionInputs.positionCS;
                o.uv = v.texcoord;

                return o;
            }


            half4 frag (v2f i) : SV_Target
            {

                half3 soure = SAMPLE_TEXTURE2D(_SourceTex,sampler_SourceTex, i.uv).rgb;
                half3 blur = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex, i.uv).rgb;
                half3 col = lerp(0,soure,saturate(blur));

                return half4(col, 1);
            }
            ENDHLSL
        }
    }
}