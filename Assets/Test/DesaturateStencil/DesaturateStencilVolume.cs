using UnityEngine.Rendering;

[System.Serializable, VolumeComponentMenu("Post-processing/DesaturateStencil")]
public class DesaturateStencilVolume : VolumeComponent
{
    public IntParameter stencilRefValue = new IntParameter(0);
    // public ClampedFloatParameter blurRadius = new ClampedFloatParameter(1.0f, 0.0f, 2.0f);
    // public ClampedIntParameter iteration = new ClampedIntParameter(0, 0, 4);
    public bool IsActive() => stencilRefValue.value > 0;
}