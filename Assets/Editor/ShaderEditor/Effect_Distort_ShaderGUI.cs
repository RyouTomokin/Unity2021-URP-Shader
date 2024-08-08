using System;
using UnityEditor;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;
using UnityEditor.Rendering.Universal;

public class Effect_Distort_ShaderGUI : ShaderGUI
{
    private static bool _Base_Foldout = false;
    private static bool _Color_Foldout = true;
    private static bool _Twist_Foldout = false;
    private static bool _Mask_Foldout = false;
    private static bool _Dissolve_Foldout = false;
    
    MaterialEditor m_MaterialEditor;
    
    //基础设置
    MaterialProperty BlendMode = null;
    MaterialProperty CullMode = null;
    MaterialProperty DepthTest = null;
    //基础颜色
    MaterialProperty BaseColor = null;
    MaterialProperty Brighten = null;
    MaterialProperty SelfMask = null;
    MaterialProperty BaseMap = null;
    MaterialProperty MainSpeed = null;
    MaterialProperty MainClampEnabled = null;
    MaterialProperty MainClamp = null;
    MaterialProperty Cutoff = null;
    MaterialProperty SoftParticlesEnabled = null;
    MaterialProperty SoftParticle = null;
    MaterialProperty MoveToCamera = null;
    //扭曲
    MaterialProperty TwistSpeed = null;
    MaterialProperty TwistMap = null;
    MaterialProperty TwistStrength = null;
    //遮罩
    MaterialProperty MaskMap = null;
    MaterialProperty MaskTwistStrength = null;
    MaterialProperty MaskSoft = null;
    //溶解
    MaterialProperty DissolveMode = null;
    MaterialProperty DissolveMaskMap = null;
    MaterialProperty DissolveMaskSharpen = null;
    MaterialProperty DissolveSpeed = null;
    MaterialProperty Dissolve = null;
    MaterialProperty DissolveMap = null;
    MaterialProperty DissolveSharpen = null;
    MaterialProperty DissolveSideColor = null;
    MaterialProperty DissolveSideWidth = null;
    
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
        Brighten = FindProperty("_Brighten", props);
        SelfMask = FindProperty("_SelfMask", props);
        BaseMap = FindProperty("_BaseMap", props);
        MainSpeed = FindProperty("_MainSpeed", props);
        MainClampEnabled = FindProperty("_MainClampEnabled", props);
        MainClamp = FindProperty("_MainClamp", props);
        Cutoff = FindProperty("_Cutoff", props);
        SoftParticlesEnabled = FindProperty("_SoftParticlesEnabled", props);
        SoftParticle = FindProperty("_SoftParticle", props);
        MoveToCamera = FindProperty("_MoveToCamera", props);
        
        TwistSpeed = FindProperty("_TwistSpeed", props);
        TwistMap = FindProperty("_TwistMap", props);
        TwistStrength = FindProperty("_TwistStrength", props);
        
        MaskMap = FindProperty("_MaskMap", props);
        MaskTwistStrength = FindProperty("_MaskTwistStrength", props);
        MaskSoft = FindProperty("_MaskSoft", props);
        
        DissolveMode = FindProperty("_DissolveMode", props);
        DissolveMaskMap = FindProperty("_DissolveMaskMap", props);
        DissolveMaskSharpen = FindProperty("_DissolveMaskSharpen", props);
        DissolveSpeed = FindProperty("_DissolveSpeed", props);
        Dissolve = FindProperty("_Dissolve", props);
        DissolveMap = FindProperty("_DissolveMap", props);
        DissolveSharpen = FindProperty("_DissolveSharpen", props);
        DissolveSideColor = FindProperty("_DissolveSideColor", props);
        DissolveSideWidth = FindProperty("_DissolveSideWidth", props);
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
            m_MaterialEditor.ShaderProperty(Brighten, "提亮");
            m_MaterialEditor.ShaderProperty(SelfMask, "自我遮罩(R通道作为A通道)");
            m_MaterialEditor.ShaderProperty(BaseMap, "颜色贴图");
            m_MaterialEditor.ShaderProperty(MainSpeed, "主贴图流动速度");
            m_MaterialEditor.ShaderProperty(MainClampEnabled, "开启贴图Clamp");
            m_MaterialEditor.ShaderProperty(MainClamp, "主贴图Clamp");
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

        //--------------------------------------
        //扭曲
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        _Twist_Foldout = Foldout(_Twist_Foldout, "扭曲");
        if (_Twist_Foldout)
        {
            m_MaterialEditor.ShaderProperty(TwistSpeed, "扭曲流动速度");
            m_MaterialEditor.ShaderProperty(TwistMap, "扭曲贴图(offset为流动方向)");
            m_MaterialEditor.ShaderProperty(TwistStrength, "扭曲强度");
        }
        EditorGUILayout.EndVertical();
        
        //--------------------------------------
        //遮罩
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        _Mask_Foldout = Foldout(_Mask_Foldout, "遮罩");
        if (_Mask_Foldout)
        {
            m_MaterialEditor.ShaderProperty(MaskMap, "遮罩贴图");
            m_MaterialEditor.ShaderProperty(MaskTwistStrength, "遮罩图被扭曲的强度");
            m_MaterialEditor.ShaderProperty(MaskSoft, "遮罩硬度");
        }
        EditorGUILayout.EndVertical();
        
        //--------------------------------------
        //溶解
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        _Dissolve_Foldout = Foldout(_Dissolve_Foldout, "溶解");
        if (_Dissolve_Foldout)
        {
            m_MaterialEditor.ShaderProperty(DissolveMode, "轴向溶解模式");
            m_MaterialEditor.ShaderProperty(DissolveMaskMap, "溶解的遮罩贴图");
            m_MaterialEditor.ShaderProperty(DissolveMaskSharpen, "溶解遮罩渐变范围");
            m_MaterialEditor.ShaderProperty(DissolveSpeed, "溶解流动速度");
            m_MaterialEditor.ShaderProperty(Dissolve, "溶解进度");
            m_MaterialEditor.ShaderProperty(DissolveMap, "溶解贴图");
            m_MaterialEditor.ShaderProperty(DissolveSharpen, "溶解硬度");
            m_MaterialEditor.ShaderProperty(DissolveSideColor, "溶解边缘颜色");
            m_MaterialEditor.ShaderProperty(DissolveSideWidth, "溶解边缘宽度(溶解较硬需要0.5以上)");
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
