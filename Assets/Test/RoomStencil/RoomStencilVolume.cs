using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

[System.Serializable, VolumeComponentMenu("Post-processing/RoomStencil")]
public class RoomStencilVolume : VolumeComponent
{
    public IntParameter stencilRefValue = new IntParameter(0);
    public FloatParameter blurSpread = new FloatParameter(0);
    public IntParameter preDownSample = new IntParameter(1);
    public IntParameter blurIterations = new IntParameter(4);
    public bool IsActive() => stencilRefValue.value > 0;

    public bool IsTileCompatible() => false;
}