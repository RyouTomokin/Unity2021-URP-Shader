// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "KIIF/UI/GaussianBlur"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)
        _BlurRange ("BlurRange", Float) = 1.0
//    	_BlurOffset ("BlurOffset", Vector) = (0,0,0,0)
        [MaterialToggle] PixelSnap ("Pixel snap", Float) = 0
        [HideInInspector] _RendererColor ("RendererColor", Color) = (1,1,1,1)
        [HideInInspector] _Flip ("Flip", Vector) = (1,1,1,1)
        [PerRendererData] _AlphaTex ("External Alpha", 2D) = "white" {}
        [PerRendererData] _EnableExternalAlpha ("Enable External Alpha", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
        }

        Cull Off
        Lighting Off
        ZWrite Off
        Blend One OneMinusSrcAlpha

        Pass
        {
        CGPROGRAM
            #pragma vertex VertGaussianBlur
            #pragma fragment FragGaussianBlur
            #pragma target 2.0
            #pragma multi_compile_instancing
            #pragma multi_compile_local _ PIXELSNAP_ON
            #pragma multi_compile _ ETC1_EXTERNAL_ALPHA
            #include "UnitySprites.cginc"

            float _BlurRange;
            // half4 _BlurOffset;
            float4 _MainTex_TexelSize;
        
            struct appdata_blur
            {
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float2 uv       : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f_blur
            {
                float4 vertex   : SV_POSITION;
                fixed4 color    : COLOR;
                float2 uv       : TEXCOORD0;
                float4 uv01     : TEXCOORD1;
		        float4 uv23     : TEXCOORD2;
		        float4 uv45     : TEXCOORD3;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f_blur VertGaussianBlur(appdata_blur IN)
            {
                v2f_blur OUT;

                UNITY_SETUP_INSTANCE_ID (IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                OUT.vertex = UnityFlipSprite(IN.vertex, _Flip);
                OUT.vertex = UnityObjectToClipPos(OUT.vertex);
                OUT.uv = IN.uv;
                OUT.color = IN.color * _Color * _RendererColor;

            	float2 offset = saturate(OUT.uv.xy - float2(0.5, 0.5))
            		* _MainTex_TexelSize.xy * _BlurRange;

                OUT.uv01 = OUT.uv.xyxy + offset.xyxy * float4(1, 1, -1, -1);
		        OUT.uv23 = OUT.uv.xyxy + offset.xyxy * float4(1, 1, -1, -1) * 2.0;
		        OUT.uv45 = OUT.uv.xyxy + offset.xyxy * float4(1, 1, -1, -1) * 6.0;

                #ifdef PIXELSNAP_ON
                OUT.vertex = UnityPixelSnap (OUT.vertex);
                #endif

                return OUT;
            }        

            // half3 BoxFliter(float2 uv, float t)
            // {
            //     float4 d = _MainTex_TexelSize.xyxy * float4(-t, -t, t, t);
            //
            //     half3 col = 0;
            //     // 平均盒体采样
            //     col += SampleSpriteTexture(uv + d.xy).rgb * 0.25h;
            //     col += SampleSpriteTexture(uv + d.zy).rgb * 0.25h;
            //     col += SampleSpriteTexture(uv + d.xw).rgb * 0.25h;
            //     col += SampleSpriteTexture(uv + d.zw).rgb * 0.25h;
            //
            //     return saturate(col);
            // }

            // half4 FragBoxBlur (v2f_blur IN) : SV_Target
            // {
            //     half4 col = half4(BoxFliter(IN.uv, _BlurRange).rgb, 1);
            //     // half4 col = SampleSpriteTexture (IN.texcoord) * IN.color;
            //
            //     return col;
            // }

            float4 FragGaussianBlur(v2f_blur i): SV_Target
	        {
		        half4 color = float4(0, 0, 0, 0);
		        
		        color += 0.40 * tex2D(_MainTex, i.uv);
		        color += 0.15 * tex2D(_MainTex, i.uv01.xy);
		        color += 0.15 * tex2D(_MainTex, i.uv01.zw);
		        color += 0.10 * tex2D(_MainTex, i.uv23.xy);
		        color += 0.10 * tex2D(_MainTex, i.uv23.zw);
		        color += 0.05 * tex2D(_MainTex, i.uv45.xy);
		        color += 0.05 * tex2D(_MainTex, i.uv45.zw);

	        	color *= i.color;
		        
		        return color;
	        }
        ENDCG
        }
    }
}