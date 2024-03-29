using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class RoomStencilVolume : VolumeComponent
{
    //[Tooltip("Threshold")] public FloatParameter Threshold = new FloatParameter(1f);
    public IntParameter StencilRefValue = new IntParameter(2);
    public FloatParameter blurSpread = new FloatParameter(0);
    public IntParameter preDownSample = new IntParameter(1);
    public IntParameter BlurIterations = new IntParameter(4);
    //public bool IsActive() => StencilRefValue.value > 0;
    //public bool IsTileCompatible() => false;
    
}