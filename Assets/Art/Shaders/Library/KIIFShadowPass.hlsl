#ifndef KIIF_ShadowPass_INCLUDED
#define KIIF_ShadowPass_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
#include "Assets/Art/Shaders/Library/KIIFCommon.hlsl"

half _Melt;
half _MeltEdgeSize;
half4 _MeltEdgeColor;
// TEXTURE2D(_EmissionMap);           SAMPLER(sampler_EmissionMap);

half4 DissipateShadowPassFragment(Varyings input) : SV_TARGET
{
    #ifdef _DISSOLVE_ON
    half4 Emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, input.uv);
    DissipateCompletely(Emission.b, _Melt, _MeltEdgeSize, _MeltEdgeColor.rgb);
    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    #endif
    return 0;
}

#endif
