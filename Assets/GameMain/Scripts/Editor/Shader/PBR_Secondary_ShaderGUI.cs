using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor.Rendering.Universal;

public class PBR_Secondary_ShaderGUI : ShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
    {
        base.OnGUI(materialEditor, props);
        
        Material material = materialEditor.target as Material;
        MaterialProperty alphaTest = FindProperty("_AlphaTest", props);
        if (alphaTest.floatValue == 1)
        {
            material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.AlphaTest;
            material.EnableKeyword("_ALPHATEST_ON");
        }
        else
        {
            material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Geometry;
            material.DisableKeyword("_ALPHATEST_ON");
        }
        TextureHasMap(material);
        BakeEmissive(material);
    }
    
    public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
    {
        base.AssignNewShaderToMaterial(material, oldShader, newShader);
        TextureHasMap(material);
        BakeEmissive(material);
    }

    //贴图槽存在贴图则开启关键字
    void TextureHasMap(Material material)
    {
        if(material.HasProperty("_BumpMap"))
            CoreUtils.SetKeyword(material, "_NORMALMAP", material.GetTexture("_BumpMap"));
        if(material.HasProperty("_SMAEMap"))
            CoreUtils.SetKeyword(material, "_SMAEMAP", material.GetTexture("_SMAEMap"));
        if(material.HasProperty("_SecondaryMap"))
            CoreUtils.SetKeyword(material, "_SECONDARY_COLORMAP", material.GetTexture("_SecondaryMap"));
        if(material.HasProperty("_SecondaryBumpMap"))
            CoreUtils.SetKeyword(material, "_SECONDARY_NORMALMAP", material.GetTexture("_SecondaryBumpMap"));
        if(material.HasProperty("_SecondarySMAEMap"))
            CoreUtils.SetKeyword(material, "_SECONDARY_SMAEMAP", material.GetTexture("_SecondarySMAEMap"));
        if(material.HasProperty("_NoiseMap"))
            CoreUtils.SetKeyword(material, "_NOISEMAP", material.GetTexture("_NoiseMap"));
    }

    //自发光强度大于0，开启自发光的烘焙
    void BakeEmissive(Material material)
    {
        if (material.HasProperty("_EmissionStrength"))
        {
            if (material.GetFloat("_EmissionStrength") > 0.0)
            {
                material.globalIlluminationFlags = MaterialGlobalIlluminationFlags.BakedEmissive;
            }
            else
            {
                material.globalIlluminationFlags = MaterialGlobalIlluminationFlags.EmissiveIsBlack;
            }
        }
    }
}
