using UnityEngine.Rendering;

[System.Serializable, VolumeComponentMenu("Post-processing/LocalBlur")]
public class LocalBlurVolume : VolumeComponent
{
    public BoolParameter isActive = new BoolParameter(true);
    public ClampedFloatParameter blurRadius = new ClampedFloatParameter(0.003f, 0.0f, 0.005f);
    public ClampedIntParameter iteration = new ClampedIntParameter(3, 1, 4);
}