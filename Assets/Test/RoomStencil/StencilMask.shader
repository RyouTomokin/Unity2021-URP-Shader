Shader "Unlit/StencilMask"
{
    Properties
    {
//        _StencilColor("StencilColor",Color)=(1,1,1,1)
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Int) = 8
        
        [Space(20)]
        _RefValue("Ref Value",Int)=2
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comp",Int) = 8      //默认Always
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass",Int) = 0            //默认Keep
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        
        ColorMask 0

        Pass
        {
            
            Stencil
            {
                Ref [_RefValue]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }
            ZTest [_ZTest]
            ZWrite Off
            Cull Back
        }
    }
}
