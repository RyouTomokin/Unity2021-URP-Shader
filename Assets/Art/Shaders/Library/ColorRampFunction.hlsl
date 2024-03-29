#ifndef KIIF_ColorRampFunction_INCLUDED
#define KIIF_ColorRampFunction_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

half4 _RampColor;
half _RampBottom;
half _RampLength;

inline void ColorRampFunction(half3 positionWS, inout half4 color)
{
    #if _COLORRAMP_ON
    // half rampFactor = saturate((positionWS.y - _RampBottom) / (_RampTop - _RampBottom));
    half rampFactor = saturate((positionWS.y - _RampBottom) / _RampLength);
    rampFactor = smoothstep(0, 1, rampFactor);
    color = lerp(_RampColor, color, rampFactor);
    #endif
}

#endif
