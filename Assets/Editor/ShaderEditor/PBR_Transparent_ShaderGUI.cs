using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor.Rendering.Universal;

public class PBR_Transparent_ShaderGUI : ShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
    {
        base.OnGUI(materialEditor, props);
        
        Material material = materialEditor.target as Material;
        SetDepthWrite(material, props);
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
    }
    
    //切换是否深度写入
    void SetDepthWrite(Material material, MaterialProperty[] props)
    {
        MaterialProperty ZWrite = FindProperty("_DepthWrite", props);
        
        material.SetFloat("_ZWrite", ZWrite.floatValue);
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
