using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.Linq;

namespace Tomokin
{
    [CustomEditor(typeof(MeshTexturePainter))]
    public class MeshTexturePainterEditor : Editor
    {
        private MeshTexturePainter painter;
        private MonoScript monoScript;
        private GUIContent editIcon;
        // private bool showTexturePicker = false;     // 是否显示 ObjectField 修改纹理
        private bool isCreatTexture = false;        // 是否正在选择新纹理
        private bool isReplaceTexture = false;      // 是否正在选择新纹理
        // private double lastClickTime = 0;           // 记录上次点击的时间// 预设的可选纹理尺寸
        private static readonly int[] TextureSizes = { 128, 256, 512, 1024, 2048, 4096 };

        private void OnEnable()
        {
            painter = (MeshTexturePainter)target;
            monoScript = MonoScript.FromMonoBehaviour(painter);
            editIcon = EditorGUIUtility.IconContent("EditCollider"); // 绘制模式图标
        }

        public override void OnInspectorGUI()
        {
            serializedObject.Update();

            // 显示脚本信息（不可修改）
            EditorGUI.BeginDisabledGroup(true);
            EditorGUILayout.ObjectField("Script", monoScript, typeof(MonoScript), false);
            EditorGUI.EndDisabledGroup();

            EditorGUILayout.Space();

            if (painter.terrainTextures != null && painter.weightMaps != null)
            {
                // 绘制模式开关
                GUILayout.BeginHorizontal();
                GUILayout.FlexibleSpace();
                bool oldValue = painter.isPainting;  // 记录原始值
                painter.isPainting = GUILayout.Toggle(painter.isPainting, editIcon, "Button",
                    GUILayout.Width(35), GUILayout.Height(25));
                // 检测 Toggle 是否被按下或松开
                if (oldValue != painter.isPainting) 
                {
                    if (painter.isPainting) 
                    {
                        // 初始化RT
                        painter.InitializeRT();
                    }
                    else 
                    {
                        // 卸载RT
                        painter.ClearRT();
                        // 保存现在的权重图
                        painter.SaveAllWeightMaps();
                    }
                }
                // painter.isDebugMode = GUILayout.Toggle(painter.isDebugMode, "Debug", "Button",
                //     GUILayout.Width(50), GUILayout.Height(25));
                // if (painter.isDebugMode)
                // {
                //     painter.RelatedToMaterial();
                // }
                GUILayout.FlexibleSpace();
                GUILayout.EndHorizontal();

                EditorGUILayout.Space();

                // 画笔设置
                painter.brushSize = EditorGUILayout.Slider("画笔大小", painter.brushSize, 0.01f, 10f);
                painter.brushStrength = EditorGUILayout.Slider("画笔强度", painter.brushStrength, 0.01f, 1f);

                EditorGUILayout.Space();

                // **地形纹理管理**
                EditorGUILayout.LabelField("地形纹理", EditorStyles.boldLabel);

                int textureCount = painter.terrainTextures.Count;
                int gridHeight = (int)((float)textureCount / painter.controlChannels + 0.9f) * 90; // 计算网格高度

                if (textureCount > 0)
                {
                    Texture2D[] textureArray = painter.terrainTextures.ToArray();
                    int newTextureIndex = GUILayout.SelectionGrid(painter.selectedTextureIndex, textureArray, painter.controlChannels,
                        "gridlist", GUILayout.Width(360), GUILayout.Height(gridHeight));

                    // **点击选中纹理**
                    if (newTextureIndex != painter.selectedTextureIndex)
                    {
                        Undo.RecordObject(painter, "Change Selected Texture");
                        // TODO undo后实际绘制的通道还是之前的
                        painter.SelectTexture(newTextureIndex);
                        EditorUtility.SetDirty(painter);
                    }

                    // // **检测双击**
                    // Event e = Event.current;
                    // if (e.type == EventType.MouseDown && e.button == 0) // 鼠标左键点击
                    // {
                    //     double timeSinceLastClick = EditorApplication.timeSinceStartup - lastClickTime;
                    //     lastClickTime = EditorApplication.timeSinceStartup;
                    //
                    //     if (timeSinceLastClick < 0.3f) // 300ms 内二次点击，视为双击
                    //     {
                    //         showTexturePicker = true;
                    //     }
                    // }
                    //
                    // if (showTexturePicker)
                    // {
                    //     EditorGUI.BeginChangeCheck();
                    //     Texture2D newTex = (Texture2D)EditorGUILayout.ObjectField(
                    //         "修改纹理", painter.terrainTextures[painter.selectedTextureIndex], typeof(Texture2D), false);
                    //     if (EditorGUI.EndChangeCheck())
                    //     {
                    //         painter.terrainTextures[painter.selectedTextureIndex] = newTex;
                    //         EditorUtility.SetDirty(painter);
                    //     }
                    // }
                }
                else
                {
                    EditorGUILayout.HelpBox("当前没有地形纹理，请添加！", MessageType.Warning);
                }

                EditorGUILayout.Space();

                // **添加/替换/删除纹理按钮**
                GUILayout.BeginHorizontal();

                if (GUILayout.Button("添加新纹理", GUILayout.Width(150)))
                {
                    EditorGUIUtility.ShowObjectPicker<Texture2D>(null, false, "", 0);
                    isCreatTexture = true;
                }

                GUI.enabled = painter.terrainTextures.Count > 0;
                if (GUILayout.Button("替换纹理", GUILayout.Width(150)))
                {
                    EditorGUIUtility.ShowObjectPicker<Texture2D>(null, false, "", 0);
                    isReplaceTexture = true;
                }

                if (GUILayout.Button("删除选中的纹理", GUILayout.Width(150)))
                {
                    if (painter.selectedTextureIndex >= 0 && painter.selectedTextureIndex < painter.terrainTextures.Count)
                    {
                        Undo.RecordObject(painter, "Remove Texture");
                        painter.terrainTextures.RemoveAt(painter.selectedTextureIndex);

                        // 确保索引不会越界
                        painter.selectedTextureIndex = Mathf.Clamp(painter.selectedTextureIndex, 0, painter.terrainTextures.Count - 1);

                        EditorUtility.SetDirty(painter);
                        
                        // 检查地形纹理的数量
                        painter.CheckWeightMapsCount();
                    }
                }
                GUI.enabled = true;
                GUILayout.EndHorizontal();

                // **检测 Object Picker 选择结果**
                if (isCreatTexture && Event.current.commandName == "ObjectSelectorUpdated")
                {
                    Texture2D selectedTexture = (Texture2D)EditorGUIUtility.GetObjectPickerObject();
                    if (selectedTexture != null)
                    {
                        Undo.RecordObject(painter, "Create Texture");
                        painter.terrainTextures.Add(selectedTexture);
                        EditorUtility.SetDirty(painter);
                    }
                    isCreatTexture = false;
                    // showTexturePicker = false; // 关闭双击的修改窗口
                    
                    // 检查地形纹理的数量
                    painter.CheckWeightMapsCount();
                }

                if (isReplaceTexture && Event.current.commandName == "ObjectSelectorUpdated")
                {
                    Texture2D selectedTexture = (Texture2D)EditorGUIUtility.GetObjectPickerObject();
                    if (selectedTexture != null)
                    {
                        Undo.RecordObject(painter, "Replace Texture");
                        painter.terrainTextures[painter.selectedTextureIndex] = selectedTexture;
                        EditorUtility.SetDirty(painter);
                    }
                    isReplaceTexture = false;
                }

                // **显示权重贴图信息**
                EditorGUILayout.LabelField("权重贴图", EditorStyles.boldLabel);
                EditorGUI.BeginDisabledGroup(true);
                EditorGUILayout.IntField("权重贴图数量", painter.weightMaps.Count);
                EditorGUI.EndDisabledGroup();
                // EditorGUILayout.IntField("权重贴图尺寸", painter.TextureSize);
                // 获取当前 TextureSize 在数组中的索引
                int selectedIndex = Mathf.Max(0, System.Array.IndexOf(TextureSizes, painter.TextureSize));
                // 创建可编辑的下拉菜单
                selectedIndex = EditorGUILayout.Popup("权重贴图尺寸", selectedIndex, TextureSizes.Select(size => size.ToString()).ToArray());
                painter.TextureSize = TextureSizes[selectedIndex];
                
                GUILayout.BeginHorizontal();
                if (GUILayout.Button("保存权重图", GUILayout.Width(150)))
                {
                    painter.UpdateWeightMaps();
                }
                if (GUILayout.Button("获取权重图", GUILayout.Width(150)))
                {
                    painter.UpdateWeightMapsFromDisk();
                }
                if (GUILayout.Button("清理数据", GUILayout.Width(150)))
                {
                    painter.ClearWeightMaps();
                }
                GUILayout.EndHorizontal();

                if (GUILayout.Button("保存地形纹理为图集", GUILayout.Width(150)))
                {
                    painter.SaveTerrainTexturesToTexture2DArray();
                }
            }
            else
            {
                EditorGUILayout.HelpBox("地形纹理或权重贴图未设置！", MessageType.Warning);
            }

            serializedObject.ApplyModifiedProperties();
        }
    }
}
