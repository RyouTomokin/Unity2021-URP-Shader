using System;
using UnityEditor;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;
using UnityEditor.Rendering.Universal;

public class Effect_ShaderGUI : ShaderGUI
{
    private static bool _Base_Foldout = false;
    private static bool _Color_Foldout = true;
    
    MaterialEditor m_MaterialEditor;
    
    //基础设置
    MaterialProperty BlendMode = null;
    MaterialProperty CullMode = null;
    MaterialProperty DepthTest = null;
    //基础颜色
    MaterialProperty BaseColor = null;
    MaterialProperty BaseMap = null;
    MaterialProperty Cutoff = null;
    MaterialProperty SoftParticlesEnabled = null;
    MaterialProperty SoftParticle = null;
    MaterialProperty MoveToCamera = null;
    
    static bool Foldout(bool display, string title)
    {
        var style = new GUIStyle("ShurikenModuleTitle");
        style.font = new GUIStyle(EditorStyles.boldLabel).font;
        style.border = new RectOffset(15, 7, 4, 4);
        style.fixedHeight = 22;
        style.contentOffset = new Vector2(20f, -2f);
        style.fontSize = 11;
        style.normal.textColor = new Color(0.7f, 0.8f, 0.9f);

        var rect = GUILayoutUtility.GetRect(16f, 25f, style);
        GUI.Box(rect, title, style);

        var e = Event.current;

        var toggleRect = new Rect(rect.x + 4f, rect.y + 2f, 13f, 13f);
        if (e.type == EventType.Repaint)
        {
            EditorStyles.foldout.Draw(toggleRect, false, false, display, false);
        }

        if (e.type == EventType.MouseDown && rect.Contains(e.mousePosition))
        {
            display = !display;
            e.Use();
        }

        return display;
    }
    /// <summary>
    /// 获取Shader参数
    /// </summary>
    /// <param name="props"></param>
    public void FindProperties(MaterialProperty[] props)
    {
        BlendMode = FindProperty("_Blend", props);
        CullMode = FindProperty("_Cull", props);
        DepthTest = FindProperty("_DepthTest", props);
        
        BaseColor = FindProperty("_BaseColor", props);
        BaseMap = FindProperty("_BaseMap", props);
        Cutoff = FindProperty("_Cutoff", props);
        SoftParticlesEnabled = FindProperty("_SoftParticlesEnabled", props);
        SoftParticle = FindProperty("_SoftParticle", props);
        MoveToCamera = FindProperty("_MoveToCamera", props);
    }
    
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
    {
        FindProperties(props);
        
        m_MaterialEditor = materialEditor;
        Material material = materialEditor.target as Material;
        
        //--------------------------------------
        //基础设置
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        _Base_Foldout = Foldout(_Base_Foldout, "基础设置");

        if (_Base_Foldout)
        {
            EditorGUI.indentLevel++;
            m_MaterialEditor.ShaderProperty(BlendMode, "叠加模式");
            // https://docs.unity3d.com/Manual/SL-Blend.html
            if (material.GetFloat("_Blend") == 0)
            {
                material.SetFloat("_SrcBlend", 5);  //SrcAlpha
                material.SetFloat("_DstBlend", 10); //OneMinusSrcAlpha
            }
            else
            {
                material.SetFloat("_SrcBlend", 5);  //SrcAlpha
                material.SetFloat("_DstBlend", 1);  //Add
            }
            m_MaterialEditor.ShaderProperty(CullMode, "剔除模式");
            m_MaterialEditor.ShaderProperty(DepthTest, "深度测试");
            if (material.GetFloat("_DepthTest") == 0)
            {
                material.SetFloat("_ZTest", 8);
            }
            else
            {
                material.SetFloat("_ZTest", 4);
            }
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndVertical();
        
        //--------------------------------------
        //基础颜色
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        _Color_Foldout = Foldout(_Color_Foldout, "基础颜色");
        
        if (_Color_Foldout)
        {
            EditorGUI.indentLevel++;
            m_MaterialEditor.ShaderProperty(BaseColor, "颜色");
            m_MaterialEditor.ShaderProperty(BaseMap, "颜色贴图");
            m_MaterialEditor.ShaderProperty(Cutoff, "透明度裁切");
            m_MaterialEditor.ShaderProperty(SoftParticlesEnabled, "开启软粒子");
            if (material.GetFloat("_SoftParticlesEnabled") == 1)
            {
                CoreUtils.SetKeyword(material, "_SOFTPARTICLES_ON", true);
                m_MaterialEditor.ShaderProperty(SoftParticle, "软粒子");
            }
            else
            {
                CoreUtils.SetKeyword(material, "_SOFTPARTICLES_ON", false);
            }
            m_MaterialEditor.ShaderProperty(MoveToCamera, "移向摄像机");
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndVertical();
        
        MaterialProperty[] emptyProp = { };
        base.OnGUI(materialEditor, emptyProp);
    }
    
    public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
    {
        base.AssignNewShaderToMaterial(material, oldShader, newShader);
    }
}
