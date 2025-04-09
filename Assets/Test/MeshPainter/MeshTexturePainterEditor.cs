using System;
using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.Linq;
using System.IO;

namespace Tomokin
{
#if UNITY_EDITOR
    [CustomEditor(typeof(MeshTexturePainter))]
    public class MeshTexturePainterEditor : Editor
    {
        private MeshTexturePainter painter;
        private MonoScript monoScript;
        private GUIContent editIcon;
        // private bool isCreatTexture = false;            // 是否正在选择新纹理
        // private bool isReplaceTexture = false;          // 是否正在选择新纹理
        private bool isTextureChangede = false;         // 是否修改了地形纹理
        private static readonly int[] TextureSizes = { 128, 256, 512, 1024, 2048, 4096 };

        private Texture2D[] terrainBrushes;
        private int selectedBrushIndex;

        private void OnEnable()
        {
            painter = (MeshTexturePainter)target;
            monoScript = MonoScript.FromMonoBehaviour(painter);
            editIcon = EditorGUIUtility.IconContent("EditCollider"); // 绘制模式图标
            terrainBrushes = LoadBrushes();
        }

        public static Texture2D[] LoadBrushes()
        {
            // 获取当前脚本的路径
            string scriptGUID = AssetDatabase.FindAssets("MeshTexturePainter t:Script")[0];
            string scriptPath = AssetDatabase.GUIDToAssetPath(scriptGUID);
            scriptPath = Path.GetDirectoryName(scriptPath);
            // 获取 Editor 目录下 Brushes 文件夹的路径
            string[] guids = AssetDatabase.FindAssets("Brushes", new[] { scriptPath });

            if (guids.Length == 0)
            {
                Debug.LogError("未找到 Brushes 文件夹！");
                return null;
            }

            string brushesFolderPath = AssetDatabase.GUIDToAssetPath(guids[0]);

            if (!Directory.Exists(brushesFolderPath))
            {
                Debug.LogError($"未找到 Brushes 文件夹: {brushesFolderPath}");
                return null;
            }

            // 支持的图片格式
            string[] supportedFormats = { "*.png", "*.jpg", "*.jpeg", "*.tga", "*.psd" };

            // 获取 Brushes 目录下所有支持的图片文件
            List<string> brushFiles = new List<string>();
            foreach (var format in supportedFormats)
            {
                brushFiles.AddRange(Directory.GetFiles(brushesFolderPath, format));
            }

            if (brushFiles.Count == 0)
            {
                Debug.LogWarning("Brushes 文件夹中没有找到可用的图片纹理！");
                return null;
            }

            // 加载所有图片纹理
            Texture2D[] brushes = new Texture2D[brushFiles.Count];
            for (int i = 0; i < brushFiles.Count; i++)
            {
                string assetPath = brushFiles[i].Replace(Application.dataPath, "").Replace("\\", "/");
                brushes[i] = AssetDatabase.LoadAssetAtPath<Texture2D>(assetPath);
            }

            Debug.Log($"成功加载 {brushes.Length} 个笔刷！");
            return brushes;
        }

        public override void OnInspectorGUI()
        {
            serializedObject.Update();

            // 显示脚本信息（不可修改）
            EditorGUI.BeginDisabledGroup(true);
            EditorGUILayout.ObjectField("Script", monoScript, typeof(MonoScript), false);
            EditorGUI.EndDisabledGroup();

            EditorGUILayout.Space();

            if (painter.terrainTextures != null)
            {
                // ================ 绘制模式开关 ================
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
                        // painter.SaveWeightTextureArray();
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

                // ================ 画笔设置 ================
                painter.brushSize = EditorGUILayout.Slider("画笔大小", painter.brushSize, 0.01f, 10f);
                painter.brushStrength = EditorGUILayout.Slider("画笔强度", painter.brushStrength, 0.01f, 1f);

                EditorGUILayout.Space();

                // ================ 地形纹理管理 ================
                EditorGUILayout.LabelField("地形纹理", EditorStyles.boldLabel);
                Texture2D[] terrainPreview = painter.terrainPreview;
                int textureCount = 0;
                if (terrainPreview != null) textureCount = terrainPreview.Length;
                int sIndex = painter.selectedIndex;
                int gridHeight = (int)((float)textureCount / painter.controlChannels + 0.9f) * 90; // 计算网格高度

                // **添加/替换/删除纹理按钮**
                GUILayout.BeginHorizontal();

                if (GUILayout.Button("添加新纹理", GUILayout.Width(100)))
                {
                    // EditorGUIUtility.ShowObjectPicker<Texture2D>(null, false, "", 0);
                    Undo.RecordObject(painter, "Create Texture");
                    painter.AddTerrainTexture();
                    painter.SaveTerrainTexturesToTexture2DArray();      // 添加新层后保存一遍
                    painter.UpdateWeightMaps();                         // 添加新层后刷新权重图
                    EditorUtility.SetDirty(painter);
                    isTextureChangede = true;
                }

                // GUI.enabled = painter.terrainTextures.Count > 0;
                // if (GUILayout.Button("替换纹理", GUILayout.Width(100)))
                // {
                //     EditorGUIUtility.ShowObjectPicker<Texture2D>(null, false, "", 0);
                //     isReplaceTexture = true;
                // }

                if (GUILayout.Button("删除选中的纹理", GUILayout.Width(100)))
                {
                    if (sIndex >= 0 && sIndex < textureCount)
                    {
                        Undo.RecordObject(painter, "Remove Texture");
                        painter.terrainTextures.RemoveAt(sIndex);
                        painter.SaveTerrainTexturesToTexture2DArray();      // 删除层后保存一遍
                        painter.UpdateWeightMaps();                         // 删除层后刷新权重图

                        // 确保索引不会越界
                        sIndex = Mathf.Clamp(sIndex, 0, painter.terrainTextures.Count - 1);

                        EditorUtility.SetDirty(painter);
                        isTextureChangede = true;
                    }
                }

                if (GUILayout.Button("保存地形层数据", GUILayout.Width(100)))
                {
                    if (painter.terrainAsset == null)
                    {
                        string path = painter.GetPath;
                        path += painter.gameObject.name + "TerrainTextureData.asset";
                        if (!string.IsNullOrEmpty(path))
                        {
                            TerrainTextureSaver.SaveTerrainTextures(painter.terrainTextures, path);
                        }

                        painter.terrainAsset = AssetDatabase.LoadAssetAtPath<TerrainTextureAsset>(path);
                    }
                    else
                    {
                        EditorUtility.SetDirty(painter.terrainAsset);
                        AssetDatabase.SaveAssets();
                        AssetDatabase.Refresh();
                    }
                }

                if (GUILayout.Button("加载地形层数据", GUILayout.Width(100)))
                {
                    if (painter.terrainAsset != null)
                    {
                        AssetDatabase.Refresh();
                        string path = AssetDatabase.GetAssetPath(painter.terrainAsset);
                        Debug.Log($"path={path}");
                        painter.terrainAsset = AssetDatabase.LoadAssetAtPath<TerrainTextureAsset>(path);
                        painter.terrainTextures = painter.terrainAsset.terrainTextures;
                        terrainPreview = painter.ConvertToPreviewTexture();
                        painter.SaveTerrainTexturesToTexture2DArray();
                        painter.UpdateWeightMaps();
                        Debug.Log("加载地形数据");
                        painter.ManualInitialize();
                        Debug.Log("初始化");
                    }
                    else
                    {
                        Debug.LogWarning("没有指定地形数据");
                    }
                }

                GUI.enabled = true;
                GUILayout.EndHorizontal();

                painter.terrainAsset = (TerrainTextureAsset)EditorGUILayout.ObjectField(
                    "地形层数据", painter.terrainAsset, typeof(TerrainTextureAsset), false);

                // **显示纹理列表**
                if (textureCount > 0 && terrainPreview != null && terrainPreview.Length > 0)
                {
                    // Texture2D[] textureArray = painter.terrainTextures.ToArray();
                    int newTextureIndex = GUILayout.SelectionGrid(sIndex, terrainPreview, painter.controlChannels,
                        GUILayout.Width(360), GUILayout.Height(gridHeight));

                    // **点击选中纹理**
                    if (newTextureIndex != sIndex)
                    {
                        Undo.RecordObject(painter, "Change Selected Texture");
                        // TODO undo后实际绘制的通道还是之前的
                        painter.SelectTexture(newTextureIndex);
                        sIndex = newTextureIndex;
                        EditorUtility.SetDirty(painter);
                        GUI.FocusControl(null); // 取消输入框焦点
                    }

                    // **纹理信息**
                    if (painter.terrainTextures.Count > 0)
                    {
                        EditorGUILayout.BeginVertical("box");
                        // EditorGUI.BeginChangeCheck();

                        EditorGUI.BeginChangeCheck();
                        painter.terrainTextures[sIndex].tilling = EditorGUILayout.FloatField("Tiling",
                            painter.terrainTextures[sIndex].tilling);
                        if (EditorGUI.EndChangeCheck())
                        {
                            painter.UpdateTiling(sIndex);
                        }
                        // 检测鼠标点击时，认为是停止输入
                        if (Event.current.type == EventType.MouseDown)
                        {
                            GUI.FocusControl(null); // 取消输入框焦点
                        }

                        // ** 颜色纹理 **
                        EditorGUILayout.BeginHorizontal();
                        EditorGUILayout.LabelField("Albedo Map", GUILayout.Width(100));
                        GUILayout.FlexibleSpace(); // 添加弹性间距，让右侧贴图槽靠近 Inspector 右侧
                        EditorGUI.BeginChangeCheck();
                        Texture2D albedo = (Texture2D)EditorGUILayout.ObjectField(
                            painter.terrainTextures[sIndex].albedoMap, typeof(Texture2D), false,
                            GUILayout.Width(72), GUILayout.Height(72));
                        if (EditorGUI.EndChangeCheck())
                        {
                            Undo.RecordObject(painter, "Modify Albedo Map");
                            painter.terrainTextures[sIndex].albedoMap = albedo;
                            painter.UpdateAlbedoInArray(albedo);
                            terrainPreview = painter.ConvertToPreviewTexture();     // 颜色纹理修改时，更新预览图
                            EditorUtility.SetDirty(painter);
                            Debug.Log("Albedo Map 修改了！");
                        }
                        EditorGUILayout.EndHorizontal();

                        // ** 法线纹理 **
                        EditorGUILayout.BeginHorizontal();
                        EditorGUILayout.LabelField("Normal Map", GUILayout.Width(100));
                        GUILayout.FlexibleSpace(); // 添加弹性间距，让右侧贴图槽靠近 Inspector 右侧
                        EditorGUI.BeginChangeCheck();
                        Texture2D normal = (Texture2D)EditorGUILayout.ObjectField(
                            painter.terrainTextures[sIndex].normalMap, typeof(Texture2D), false,
                            GUILayout.Width(72), GUILayout.Height(72));
                        if (EditorGUI.EndChangeCheck())
                        {
                            Undo.RecordObject(painter, "Modify Normal Map");
                            painter.terrainTextures[sIndex].normalMap = normal;
                            painter.UpdateNormalInArray(normal);
                            EditorUtility.SetDirty(painter);
                            Debug.Log("Normal  Map 修改了！");
                        }
                        EditorGUILayout.EndHorizontal();

                        // ** 光滑金属度纹理 **
                        EditorGUILayout.BeginHorizontal();
                        EditorGUILayout.LabelField("Smoothness&Metalic Map", GUILayout.Width(100));
                        GUILayout.FlexibleSpace(); // 添加弹性间距，让右侧贴图槽靠近 Inspector 右侧
                        EditorGUI.BeginChangeCheck();
                        Texture2D mask = (Texture2D)EditorGUILayout.ObjectField(
                            painter.terrainTextures[sIndex].maskMap, typeof(Texture2D), false,
                            GUILayout.Width(72), GUILayout.Height(72));
                        if (EditorGUI.EndChangeCheck())
                        {
                            Undo.RecordObject(painter, "Modify SM Map");
                            painter.terrainTextures[sIndex].maskMap = mask;
                            painter.UpdateMaskInArray(mask);
                            EditorUtility.SetDirty(painter);
                            Debug.Log("SM  Map 修改了！");
                        }
                        EditorGUILayout.EndHorizontal();

                        EditorGUILayout.EndVertical();
                    }
                }
                else
                {
                    EditorGUILayout.HelpBox("当前没有地形纹理，请添加！", MessageType.Warning);
                    terrainPreview = painter.ConvertToPreviewTexture();
                }

                EditorGUILayout.Space();

                // **检测 Object Picker 选择结果**
                // if (isCreatTexture && Event.current.commandName == "ObjectSelectorUpdated")
                // {
                //     Texture2D selectedTexture = (Texture2D)EditorGUIUtility.GetObjectPickerObject();
                //     if (selectedTexture != null)
                //     {
                //         Undo.RecordObject(painter, "Create Texture");
                //         // painter.terrainTextures.Add(selectedTexture);
                //         painter.AddTerrainTexture(selectedTexture);
                //         painter.selectedIndex = sIndex + 1;
                //         EditorUtility.SetDirty(painter);
                //     }
                //     isCreatTexture = false;
                //     isTextureChangede = true;
                // }

                // if (isReplaceTexture && Event.current.commandName == "ObjectSelectorUpdated")
                // {
                //     Texture2D selectedTexture = (Texture2D)EditorGUIUtility.GetObjectPickerObject();
                //     if (selectedTexture != null)
                //     {
                //         Undo.RecordObject(painter, "Replace Texture");
                //         painter.terrainTextures[painter.selectedTextureIndex] = selectedTexture;
                //         EditorUtility.SetDirty(painter);
                //     }
                //     isReplaceTexture = false;
                //     isTextureChangede = true;
                // }

                if (isTextureChangede)
                {
                    terrainPreview = painter.ConvertToPreviewTexture();
                    isTextureChangede = false;
                }

                // ================ 绘制笔刷纹理 ================
                EditorGUILayout.LabelField("地形笔刷", EditorStyles.boldLabel);
                if (terrainBrushes != null && terrainBrushes.Length > 0)
                {
                    GUILayout.BeginHorizontal();
                    GUILayout.Box(terrainBrushes[selectedBrushIndex], GUILayout.Width(80), GUILayout.Height(80));
                    GUILayout.BeginHorizontal("box");
                    int brushGridHeight = (int)((float)terrainBrushes.Length / 6 + 0.9f) * 47; // 计算网格高度
                    selectedBrushIndex = GUILayout.SelectionGrid(selectedBrushIndex, terrainBrushes, 6,
                        GUILayout.Width(280), GUILayout.Height(brushGridHeight));
                    painter.brushTexture = terrainBrushes[selectedBrushIndex];
                    GUILayout.EndHorizontal();
                    GUILayout.EndHorizontal();
                }
                else
                {
                    terrainBrushes = LoadBrushes(); // 加载笔刷纹理
                    if (terrainBrushes == null || terrainBrushes.Length == 0)
                    {
                        EditorGUILayout.HelpBox("未找到笔刷纹理，请检查 Brushes 文件夹！", MessageType.Warning);
                    }
                }
                if (GUILayout.Button("重新加载笔刷", GUILayout.Width(150)))
                {
                    terrainBrushes = LoadBrushes(); // 加载笔刷纹理
                }

                // ================ 权重贴图信息 ================
                EditorGUILayout.LabelField("权重贴图", EditorStyles.boldLabel);

                if(painter.weightMapArray == null)
                {
                    EditorGUILayout.HelpBox("地形纹理或权重贴图未设置！", MessageType.Warning);
                    int selectedSizeIndex = Mathf.Max(0, System.Array.IndexOf(TextureSizes, painter.TextureSize));
                    selectedSizeIndex = EditorGUILayout.Popup("权重贴图尺寸", selectedSizeIndex, TextureSizes.Select(size => size.ToString()).ToArray());
                    painter.TextureSize = TextureSizes[selectedSizeIndex];
                    if (GUILayout.Button("新建权重图", GUILayout.Width(150)))
                    {
                        painter.UpdateWeightMaps();
                    }
                }
                else
                {
                    EditorGUI.BeginDisabledGroup(true);
                    EditorGUILayout.IntField("权重贴图数量", painter.weightMapArray.depth);
                    EditorGUI.EndDisabledGroup();
                    // EditorGUILayout.IntField("权重贴图尺寸", painter.TextureSize);
                    // 获取当前 TextureSize 在数组中的索引
                    int selectedIndex = Mathf.Max(0, System.Array.IndexOf(TextureSizes, painter.TextureSize));
                    // 创建可编辑的下拉菜单
                    selectedIndex = EditorGUILayout.Popup("权重贴图尺寸", selectedIndex,
                        TextureSizes.Select(size => size.ToString()).ToArray());
                    painter.TextureSize = TextureSizes[selectedIndex];

                    GUILayout.BeginHorizontal();
                    if (GUILayout.Button("保存权重图", GUILayout.Width(150)))
                    {
                        painter.UpdateWeightMaps();
                    }

                    GUILayout.EndHorizontal();

                    if (GUILayout.Button("保存地形纹理为图集", GUILayout.Width(150)))
                    {
                        painter.SaveTerrainTexturesToTexture2DArray();
                    }
                }
            }
            serializedObject.ApplyModifiedProperties();
        }
    }

    // 在纹理修改时，重新导入触发保存
    // public class TextureReimportChecker : AssetPostprocessor
    // {
    //     static private bool isTextureImport = false;
    //     void OnPostprocessTexture(Texture2D texture)
    //     {
    //         if (texture == null)
    //             return;
    //
    //         Debug.Log($"has texture imported :{assetPath}");
    //         isTextureImport = true;
    //     }
    //
    //     private static void OnPostprocessAllAssets(string[] importedAssets, string[] deletedAssets, string[] movedAssets,
    //         string[] movedFromAssetPaths)
    //     {
    //         if (isTextureImport)
    //         {
    //             // 查找当前场景所有的 MeshTexturePainter
    //             MeshTexturePainter[] allPainters = GameObject.FindObjectsOfType<MeshTexturePainter>();
    //             if (allPainters.Length == 0)
    //                 return;
    //
    //             // Debug.Log($"Texture {assetPath} reimported, updating terrain textures...");
    //
    //             // 遍历所有 Painter，调用保存方法
    //             foreach (var painter in allPainters)
    //             {
    //                 painter.SaveTerrainTexturesToTexture2DArray();
    //                 painter.ConvertToPreviewTexture();
    //             }
    //
    //             isTextureImport = false;
    //         }
    //     }
    // }
#endif
}
