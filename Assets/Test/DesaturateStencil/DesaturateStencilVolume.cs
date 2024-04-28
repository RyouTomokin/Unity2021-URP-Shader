using UnityEngine.Rendering;
using System;

[System.Serializable, VolumeComponentMenu("Post-processing/DesaturateStencil")]
public class DesaturateStencilVolume : VolumeComponent
{
    public IntParameter stencilRefValue = new IntParameter(0);
    public ClampedFloatParameter desaturate = new ClampedFloatParameter(1.0f, 0.0f, 1.0f);
    public DepthOfFieldModeParameter stencilCompare = new DepthOfFieldModeParameter(CompareFunction.Greater);
    
    public bool IsActive() => stencilRefValue.value > 0 && desaturate.value > 0;
}

[Serializable]
public sealed class DepthOfFieldModeParameter : VolumeParameter<CompareFunction> { public DepthOfFieldModeParameter(CompareFunction value, bool overrideState = false) : base(value, overrideState) { } }