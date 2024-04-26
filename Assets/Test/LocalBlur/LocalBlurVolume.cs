using UnityEngine.Rendering;

[System.Serializable, VolumeComponentMenu("Post-processing/LocalBlur")]
public class LocalBlurVolume : VolumeComponent
{
    // public BoolParameter isActive = new BoolParameter(true);
    public ClampedFloatParameter blurRadius = new ClampedFloatParameter(1.0f, 0.0f, 2.0f);
    public ClampedIntParameter iteration = new ClampedIntParameter(0, 0, 4);
    public bool IsActive() => iteration.value > 0;
}