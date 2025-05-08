using UnityEngine;

public class FreezeBlurManager : MonoBehaviour
{
    public KeyCode triggerKey = KeyCode.Space;

    void Update()
    {
        if (Input.GetKeyDown(triggerKey))
        {
            if (FreezeBlurRendererFeature.Instance != null)
            {
                FreezeBlurRendererFeature.Instance.TriggerFreeze(); 
                Debug.Log("FreezeBlur triggered.");
            }
            else
            {
                Debug.LogWarning("FreezeBlurRendererFeature not found on active renderer!");
            }
        }
    }
}