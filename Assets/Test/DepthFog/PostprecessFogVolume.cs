using UnityEngine.Rendering;
using System;
using System.Diagnostics;

[System.Serializable, VolumeComponentMenu("Custom_Feature/PostprocessFog")]
public class PostprecessFogVolume : VolumeComponent
{
    public BoolParameter EnableFog = new BoolParameter(false, false);
    
    public bool IsActive() => EnableFog.value;
}
