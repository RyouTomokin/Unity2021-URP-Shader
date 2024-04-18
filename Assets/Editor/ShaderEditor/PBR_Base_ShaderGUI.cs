using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor.Rendering.Universal;

public class PBR_Base_ShaderGUI : ShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
    {
        base.OnGUI(materialEditor, props);
        
        Material material = materialEditor.target as Material;
        MaterialProperty alphaTest = FindProperty("_AlphaTest", props);
        ClipMode(material, props);
        CullMode(material, props);
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
        if(material.HasProperty("_SnowMap"))
            CoreUtils.SetKeyword(material, "_SNOWMAP", material.GetTexture("_SnowMap"));
        if(material.HasProperty("_SnowNormalMap"))
            CoreUtils.SetKeyword(material, "_SNOWNORMALMAP", material.GetTexture("_SnowNormalMap"));
    }
    
    //切换是否剔除像素
    void ClipMode(Material material, MaterialProperty[] props)
    {
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
    }
    
    //根据DoubleSide参数去选择剔除模式
    void CullMode(Material material, MaterialProperty[] props)
    {
        MaterialProperty doubleSide = FindProperty("_DoubleSide", props);
        if (doubleSide.floatValue == 1)
        {
            material.SetFloat("_Cull", 0);
        }
        else
        {
            material.SetFloat("_Cull", 2);
        }
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
