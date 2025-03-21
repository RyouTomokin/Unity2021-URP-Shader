using System;
using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Unity.Collections;
using Unity.VisualScripting;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

namespace Tomokin
{
    [ExecuteInEditMode]
    public class MeshTexturePainter : MonoBehaviour
    {
        // public List<Texture2D> terrainTextures = new List<Texture2D>(); // 地形纹理列表
        public List<TerrainTexture> terrainTextures = new List<TerrainTexture>();

        public class TerrainTexture
        {
            public Texture2D albedoMap;
            public Texture2D normalMap;
            public Texture2D maskMap;

            public TerrainTexture(Texture2D albedo = null)
            {
                this.albedoMap = albedo;
                this.normalMap = null;
                this.maskMap = null;
            }
        }

        public void AddTerrainTexture()
        {
            terrainTextures.Add(new TerrainTexture());
        }

        public void AddTerrainTexture(Texture2D albedoMap)
        {
            terrainTextures.Add(new TerrainTexture(albedoMap));
        }


        public Texture2D[] ConvertToPreviewTexture()
        {
            List<TerrainTexture> source = terrainTextures;
            if (source == null || source.Count == 0)
                return null;

            // 创建一个新的 Texture2D 数组
            Texture2D[] result = new Texture2D[source.Count];

            for (int i = 0; i < source.Count; i++)
            {
                Texture2D originalTexture = source[i].albedoMap;
                if (originalTexture == null)
                {
                    // 如果纹理为空，设置为黑色
                    Texture2D blackTexture = new Texture2D(2, 2);
                    Color32 black = new Color32(0, 0, 0, 255);
                    blackTexture.SetPixels32(new Color32[] { black, black, black, black });
                    blackTexture.Apply();

                    // result[i] = blackTexture;
                    originalTexture = blackTexture;
                }

                // 创建一个 RenderTexture，并将原纹理渲染到其中
                RenderTexture renderTexture = RenderTexture.GetTemporary(originalTexture.width, originalTexture.height,
                    0, RenderTextureFormat.ARGB32);
                Graphics.Blit(originalTexture, renderTexture);

                // 从 RenderTexture 中读取像素数据
                Texture2D newTexture = new Texture2D(originalTexture.width, originalTexture.height,
                    TextureFormat.RGBA32, false);
                RenderTexture previous = RenderTexture.active;
                RenderTexture.active = renderTexture;
                newTexture.ReadPixels(new Rect(0, 0, renderTexture.width, renderTexture.height), 0, 0);
                newTexture.Apply();
                RenderTexture.active = previous;

                // 释放 RenderTexture
                RenderTexture.ReleaseTemporary(renderTexture);

                // 获取新纹理的像素数据
                Color[] pixels = newTexture.GetPixels();

                // 修改 Alpha 通道为 1
                for (int j = 0; j < pixels.Length; j++)
                {
                    pixels[j].a = 1f; // 设置 Alpha 为 1
                }

                // 将修改后的像素数据应用到新纹理
                newTexture.SetPixels(pixels);
                newTexture.Apply(); // 应用更改

                // 将新纹理添加到结果数组中
                result[i] = newTexture;
            }

            return result;
        }

        public Texture2DArray weightMapArray; // 权重贴图列表

        public Texture2D brushTexture; // 笔刷纹理

        private TextureFormat _textureFormat
        {
            get => TextureFormat.RGBA32;
        }

        private RenderTextureFormat _renderTextureFormat
        {
            get => RenderTextureFormat.ARGB32;
        }

        private int selectedTextureIndex = 0; // 选择的地形纹理索引

        public int selectedIndex
        {
            get => (terrainTextures.Count > selectedTextureIndex)
                ? selectedTextureIndex
                : 0;

            set => selectedTextureIndex = value >= terrainTextures.Count 
                ? terrainTextures.Count - 1 
                : value;
        }

        public float brushSize = 0.1f;
        private float brushScale = 1.0f;
        public float brushStrength = 0.5f;

        [HideInInspector] public bool isPainting = false;
        private double lastRepaintTime = 0; // 上次刷新的时间
        private const double repaintInterval = 0.03; // 限制 30ms 刷新一次（大约 33FPS）

        private Material material;
        private const int CHANNELS_PER_MAP = 4; // 每张权重图支持 4 层纹理

        public int controlChannels
        {
            get => CHANNELS_PER_MAP;
        }

        private int requiredWeightMaps
        {
            get => Mathf.CeilToInt(terrainTextures.Count / (float)CHANNELS_PER_MAP);
        }

        private int weightMapIndex = 0; // 记录是第几个Weight纹理
        private int weightMapChannel = 0; // 记录是Weight纹理中RGBA哪一个通道

        private int _weightTextureSize = 2048;
        private int _terrainTextureSize = 1024;

        public int TextureSize
        {
            get => _weightTextureSize; // 读取值
            set
            {
                _weightTextureSize = Mathf.Clamp(value, 128, 4096); // 限制范围，防止异常值
                // Debug.Log($"纹理大小已更新：{_weightTextureSize}");
            }
        }

        // TODO 遵循地形烘焙的规则
        private const string CONTROL_MAP_PATH = "Assets/ControlMaps/";

        private string controlMapName
        {
            get => gameObject.name + "_Control";
        }

        private string controlMapPath
        {
            get => CONTROL_MAP_PATH + controlMapName + ".asset";
        }

        private ComputeShader brushComputeShader;

        // private Texture2D savedWeightMap;           // 备份贴图
        private Texture2DArray backupWeightMapArray; // 备份贴图
        private RenderTexture paintRT; // 记录当前绘制路径
        private RenderTexture weightMapArrayRT; // 记录当前绘制路径

        private void OnEnable()
        {
            InitializeComputeShader(); // 获取绘制使用的ComputeShader
            InitializeTextures(); // 初始化权重提
            InitializeBrushScale(); // 根据模型的大小匹配笔刷大小
            SceneView.duringSceneGui += OnSceneGUI;
        }

        private void OnDisable()
        {
            SceneView.duringSceneGui -= OnSceneGUI;

            DestroyImmediate(backupWeightMapArray);
            DestroyImmediate(paintRT);
            DestroyImmediate(weightMapArrayRT);
        }

        private void InitializeComputeShader()
        {
#if UNITY_EDITOR
            string path = AssetDatabase.GetAssetPath(MonoScript.FromMonoBehaviour(this));
            path = Path.GetDirectoryName(path);
            path += "/BrushCompute.compute";
            // Debug.Log($"当前脚本路径: {path}");
            brushComputeShader = AssetDatabase.LoadAssetAtPath<ComputeShader>(path);
            if (brushComputeShader == null)
            {
                Debug.LogError($"Compute Shader 未找到！请检查路径是否正确: {path}");
            }
#endif
        }

        private void InitializeBrushScale()
        {
            MeshFilter meshFilter = gameObject.GetComponent<MeshFilter>();
            if (meshFilter != null)
            {
                Mesh mesh = meshFilter.sharedMesh;
                // 获取GameObject的缩放
                Vector3 objectScale = transform.localScale;
                Vector2 objectScaleXZ = new Vector2(objectScale.x, objectScale.z);

                // 获取模型的BoundBox尺寸
                Bounds modelBounds = mesh.bounds;
                Vector3 modelSize = modelBounds.size;
                // Debug.Log("Model BoundBox Size: " + modelSize);

                // 获取UV的BoundBox尺寸
                Vector2[] uvs = mesh.uv;
                if (uvs.Length > 0)
                {
                    Vector2 uvMin = uvs[0];
                    Vector2 uvMax = uvs[0];

                    foreach (Vector2 uv in uvs)
                    {
                        uvMin = Vector2.Min(uvMin, uv);
                        uvMax = Vector2.Max(uvMax, uv);
                    }

                    Vector2 uvSize = uvMax - uvMin;
                    // Debug.Log("UV BoundBox Size: " + uvSize);

                    // 计算模型BoundBox与UV BoundBox的比值
                    Vector2 ratio = new Vector2(uvSize.x / modelSize.x, uvSize.y / modelSize.z);
                    ratio *= objectScaleXZ;
                    // Debug.Log("Model BoundBox to UV BoundBox Ratio: " + ratio);
                    brushScale = Mathf.Max(ratio.x, ratio.y);
                }
            }
        }

        // private string GetControlMapName(int id, bool isCopy = false)
        // {
        //     if (isCopy)
        //     {
        //         return "ControlMap_" + id + "_copy.png";
        //     }
        //     else
        //     {
        //         return "ControlMap_" + id + ".png";
        //     }
        // }

        // TODO 应当直接使用Array存储数据
        /// <summary>
        /// 把权重图链接到材质上
        /// </summary>
        public void RelatedToMaterial()
        {
            material = GetComponent<MeshRenderer>().sharedMaterial;
            if (material.HasProperty("_ControlMap"))
            {
                material.SetTexture("_ControlMap", weightMapArray);
            }
            else
            {
                Debug.LogWarning("Shader 没有_ControlMap参数");
            }

            if (material.HasProperty("_LayerCount"))
            {
                material.SetFloat("_LayerCount", terrainTextures.Count);
            }
        }

        /// <summary>
        /// 脚本Enable的时候初始化
        /// </summary>
        private void InitializeTextures()
        {
            if (terrainTextures.Count == 0 || GetComponent<MeshRenderer>() == null) return;

            UpdateWeightMaps();
        }

        /// <summary>
        /// 保存权重图执行的事件
        /// </summary>
        public void UpdateWeightMaps()
        {
            Debug.Log("更新权重图。");

            if (!Directory.Exists(CONTROL_MAP_PATH))
            {
                Directory.CreateDirectory(CONTROL_MAP_PATH);
            }

            if (File.Exists(controlMapPath))
            {
                weightMapArray = LoadTextureArray(controlMapPath);
                if (weightMapArray != null)
                {
                    if (weightMapArray.depth < requiredWeightMaps)
                    {
                        Debug.Log("已有权重图层数不足，扩展层数。");
                        weightMapArray = ExpandTextureArray(weightMapArray, requiredWeightMaps);
                        SaveTextureArray(weightMapArray, controlMapPath);
                    }
                    else if (weightMapArray.depth > requiredWeightMaps)
                    {
                        Debug.Log("已有权重图层数过多，裁剪层数。");
                        weightMapArray = TrimTextureArray(weightMapArray, requiredWeightMaps);
                        SaveTextureArray(weightMapArray, controlMapPath);
                    }
                }
            }
            else
            {
                Debug.Log("创建新的权重图数组。");
                weightMapArray = CreateNewTextureArray(requiredWeightMaps);
                SaveTextureArray(weightMapArray, controlMapPath);
            }

            // 贴图传递到材质球中
            RelatedToMaterial();
        }

        #region UpdateWeightMaps

        private Texture2DArray LoadTextureArray(string path)
        {
            return AssetDatabase.LoadAssetAtPath<Texture2DArray>(path);
        }

        private Texture2DArray CreateNewTextureArray(int layers)
        {
            Texture2DArray texArray =
                new Texture2DArray(_weightTextureSize, _weightTextureSize, layers, _textureFormat, false, true);
            texArray.wrapMode = TextureWrapMode.Repeat;
            texArray.filterMode = FilterMode.Bilinear;

            // 第一层填充 1.0 (白色)
            Color32[] firstLayerPixels = new Color32[_weightTextureSize * _weightTextureSize];
            for (int i = 0; i < firstLayerPixels.Length; i++)
                firstLayerPixels[i] = new Color32(255, 0, 0, 0);

            // 其他层填充 0.0 (黑色)
            Color32[] blackPixels = new Color32[_weightTextureSize * _weightTextureSize];
            for (int i = 0; i < blackPixels.Length; i++)
                blackPixels[i] = new Color32(0, 0, 0, 0);

            for (int i = 0; i < layers; i++)
            {
                Texture2D tempTex = new Texture2D(_weightTextureSize, _weightTextureSize, _textureFormat, false);
                tempTex.SetPixels32(i == 0 ? firstLayerPixels : blackPixels);
                tempTex.Apply();
                Graphics.CopyTexture(tempTex, 0, 0, texArray, i, 0);
                DestroyImmediate(tempTex);
            }

            return texArray;
        }

        private Texture2DArray ExpandTextureArray(Texture2DArray original, int newLayerCount)
        {
            Texture2DArray newArray =
                new Texture2DArray(_weightTextureSize, _weightTextureSize, newLayerCount, _textureFormat, false, true);

            int originalLayers = original.depth;
            for (int i = 0; i < originalLayers; i++)
            {
                Graphics.CopyTexture(original, i, 0, newArray, i, 0);
            }

            // 额外层填充 0.0 (黑色)
            Color32[] blackPixels = new Color32[_weightTextureSize * _weightTextureSize];
            for (int i = 0; i < blackPixels.Length; i++)
                blackPixels[i] = new Color32(0, 0, 0, 0);

            for (int i = originalLayers; i < newLayerCount; i++)
            {
                Texture2D tempTex = new Texture2D(_weightTextureSize, _weightTextureSize, _textureFormat, false);
                tempTex.SetPixels32(blackPixels);
                tempTex.Apply();
                Graphics.CopyTexture(tempTex, 0, 0, newArray, i, 0);
                Destroy(tempTex);
            }

            return newArray;
        }

        private Texture2DArray TrimTextureArray(Texture2DArray original, int newLayerCount)
        {
            Texture2DArray newArray =
                new Texture2DArray(_weightTextureSize, _weightTextureSize, newLayerCount, _textureFormat, false, true);

            for (int i = 0; i < newLayerCount; i++)
            {
                Graphics.CopyTexture(original, i, 0, newArray, i, 0);
            }

            return newArray;
        }

        public void SaveTextureArray()
        {
            SaveTextureArray(weightMapArray, controlMapPath);
        }

        private void SaveTextureArray(Texture2DArray texArray, string assetPath)
        {
            texArray.name = controlMapName;
            // 检查该资产是否已经存在
            Texture2DArray existingAsset = LoadTextureArray(assetPath);
            if (existingAsset != null)
            {
                // 直接覆盖现有的资产数据
                EditorUtility.CopySerialized(texArray, existingAsset); // 保持 GUID 不变
            }
            else
            {
                // 如果资源不存在，则创建新的
                AssetDatabase.CreateAsset(texArray, assetPath);
            }

            // 保存资产和刷新
            AssetDatabase.SaveAssets();
            AssetDatabase.ImportAsset(assetPath, ImportAssetOptions.ForceUpdate);
            AssetDatabase.Refresh();

            // 异步保存，效果不佳
            // AsyncEditorSave.SaveAssetAsync(assetPath);

            // 解决保存卡顿的效果不佳
            // EditorApplication.delayCall += () =>
            // {
            //     // 保存资产和刷新
            //     AssetDatabase.SaveAssets();
            //     AssetDatabase.ImportAsset(assetPath, ImportAssetOptions.ForceUpdate);
            //     AssetDatabase.Refresh();
            //
            //     Debug.Log($"Texture2DArray 已保存到 {assetPath}");
            // };
        }

        #endregion

        private void OnSceneGUI(SceneView sceneView)
        {
            if (!(isPainting && Selection.activeGameObject == gameObject))
            {
                Tools.hidden = false;
                return;
            }

            Tools.hidden = true; // 隐藏移动、旋转、缩放 Gizmo

            Event e = Event.current;
            if (e == null) return;

            // 获取鼠标射线
            Ray ray = HandleUtility.GUIPointToWorldRay(e.mousePosition);
            RaycastHit hit;

            if (Physics.Raycast(ray, out hit))
            {
                if (hit.collider.gameObject == gameObject)
                {
                    // 屏蔽 Scene 视图中的默认鼠标交互
                    HandleUtility.AddDefaultControl(0);
                    // 绘制笔刷预览
                    Handles.color = new Color(0.5f, 0.5f, 1.0f, 0.2f);
                    Handles.DrawSolidDisc(hit.point, hit.normal, brushSize);
                    // Handles.CircleHandleCap(0, hit.point, Quaternion.LookRotation(hit.normal),
                    //     brushSize, EventType.Repaint);
                    Handles.color = new Color(0.6f, 0.6f, 0.9f, 1f);
                    Handles.DrawLine(hit.point, hit.point + hit.normal * brushSize);

                    // **Ctrl + 滚轮调整笔刷大小**
                    if (e.control && e.type == EventType.ScrollWheel)
                    {
                        brushSize += e.delta.y * -0.01f * brushSize;
                        brushSize = Mathf.Clamp(brushSize, 0.01f, 10f); // 限制大小范围
                        e.Use();
                    }

                    // **绘制**
                    // if ((e.type == EventType.MouseDrag || e.type == EventType.MouseDown) && e.button == 0)
                    // {
                    //
                    //     if (e.shift)
                    //     {
                    //         // **Shift + 左键擦除**
                    //         // EraseAtUV(hit.textureCoord);
                    //     }
                    //     else
                    //     {
                    //         // **左键绘制**
                    //         PaintAtUV(hit.textureCoord);
                    //     }
                    //
                    //     e.Use(); // 屏蔽默认框选行为
                    // }

                    if (e.type == EventType.MouseDown && e.button == 0)
                    {
                        // 鼠标按下时，初始化
                        OnMouseDown();
                        // 绘制
                        OnMouseDrag(hit.textureCoord);
                        // 刷新Handle
                        HandleUtility.Repaint();
                    }

                    if (e.type == EventType.MouseDrag && e.button == 0)
                    {
                        // 绘制
                        OnMouseDrag(hit.textureCoord);
                        // 刷新Handle
                        HandleUtility.Repaint();
                    }

                    if (e.type == EventType.MouseMove)
                    {
                        double currentTime = EditorApplication.timeSinceStartup;
                        if (currentTime - lastRepaintTime > repaintInterval)
                        {
                            lastRepaintTime = currentTime;
                            HandleUtility.Repaint();
                        }
                    }
                }
            }

            if (e.type == EventType.MouseUp && e.button == 0)
            {
                // 绘制
                OnMouseUp();
                // TODO Undo笔刷
                // Undo.RegisterCompleteObjectUndo(weightMaps[weightMapIndex], "Modify Texture");
                //
                // // 如果需要撤销，恢复备份，目前只支持回退一次
                // Undo.undoRedoPerformed += () =>
                // {
                //     weightMaps[weightMapIndex].SetPixels(savedWeightMap.GetPixels());
                //     weightMaps[weightMapIndex].Apply();
                // };

                // TODO 现在关闭及时保存
                // string texturePath = CONTROL_MAP_PATH + GetControlMapName(weightMapIndex);
                // SaveTextureAsPNG(weightMaps[weightMapIndex], texturePath);



                // 刷新Handle
                HandleUtility.Repaint();
                // updateDebugGizmos = true;
            }
            // HandleUtility.Repaint();
        }

        /// <summary>
        /// 用于更新绘制的通道和纹理数量
        /// </summary>
        public void SelectTexture(int index)
        {
            if (index >= 0 && index < terrainTextures.Count)
            {
                selectedTextureIndex = index;

                weightMapIndex = selectedTextureIndex / CHANNELS_PER_MAP;
                weightMapChannel = selectedTextureIndex % CHANNELS_PER_MAP;
            }
        }

        /// <summary>
        /// 开启编辑开关时，初始化需要实时更新的RT
        /// </summary>
        public void InitializeRT()
        {
            backupWeightMapArray =
                new Texture2DArray(_weightTextureSize, _weightTextureSize, requiredWeightMaps, _textureFormat, false, true);

            paintRT = new RenderTexture(_weightTextureSize, _weightTextureSize, 0, _renderTextureFormat,
                RenderTextureReadWrite.Linear);
            paintRT.enableRandomWrite = true;
            paintRT.Create();

            weightMapArrayRT = new RenderTexture(_weightTextureSize, _weightTextureSize, 0, _renderTextureFormat,
                RenderTextureReadWrite.Linear);
            weightMapArrayRT.enableRandomWrite = true;
            weightMapArrayRT.volumeDepth = requiredWeightMaps;
            weightMapArrayRT.dimension = TextureDimension.Tex2DArray;
            weightMapArrayRT.Create();
        }

        /// <summary>
        /// 关闭编辑开关后，清理RT
        /// </summary>
        public void ClearRT()
        {
            // 删除内存
            DestroyImmediate(backupWeightMapArray);
            // 释放显存
            if (paintRT != null)
                paintRT.Release();
            if (weightMapArrayRT != null)
                weightMapArrayRT.Release();
        }

        private void OnMouseDown()
        {
            if (weightMapArray.depth == 0 || weightMapArray == null) return;

            if (backupWeightMapArray == null || paintRT == null || weightMapArrayRT == null) InitializeRT();

            // 备份当前 weightMap
            Graphics.CopyTexture(weightMapArray, backupWeightMapArray);
            // SaveTextureArray(backupWeightMapArray, controlMapPath.Replace("_Control", "_1_Control"));

            // 初始化 paintRT 为透明
            RenderTexture activeRT = RenderTexture.active;
            RenderTexture.active = paintRT;
            GL.Clear(true, true, Color.clear);
            RenderTexture.active = activeRT;
        }

        /// <summary>
        /// ComputeShader RT绘制
        /// </summary>
        private void OnMouseDrag(Vector2 uv)
        {
            if (weightMapArray.depth == 0 || weightMapArray == null) return;

            int texWidth = paintRT.width;
            int texHeight = paintRT.height;
            int threadGroupX = Mathf.CeilToInt(texWidth / 8.0f);
            int threadGroupY = Mathf.CeilToInt(texHeight / 8.0f);

            // ================ 绘制到 paintRT ================ 
            int paintKernel = brushComputeShader.FindKernel("DrawPaintRT");

            brushComputeShader.SetTexture(paintKernel, "_BrushMap", brushTexture);
            brushComputeShader.SetTexture(paintKernel, "_PaintRT", paintRT);

            brushComputeShader.SetInt("_TexWidth", texWidth);
            brushComputeShader.SetInt("_TexHeight", texHeight);
            brushComputeShader.SetFloat("_BrushSize", brushSize * brushScale);
            brushComputeShader.SetFloat("_BrushStrength", brushStrength);
            brushComputeShader.SetVector("_UV", new Vector4(uv.x, uv.y, 0, 0));

            brushComputeShader.Dispatch(paintKernel, threadGroupX, threadGroupY, 1);

            // ================  混合weightMap RT ================ 
            int blendKernel = brushComputeShader.FindKernel("BlendWeightMaps");

            brushComputeShader.SetInt("_LayerCount", terrainTextures.Count);
            brushComputeShader.SetInt("_TargetLayer", selectedTextureIndex);
            brushComputeShader.SetFloat("_BrushStrength", brushStrength);

            // 传递 3 张纹理
            brushComputeShader.SetTexture(blendKernel, "_WeightMapArray", backupWeightMapArray); // 只读
            brushComputeShader.SetTexture(blendKernel, "_PaintMap", paintRT); // 只读
            brushComputeShader.SetTexture(blendKernel, "_OutputWeightMapArray", weightMapArrayRT); // RW 可写

            brushComputeShader.Dispatch(blendKernel, threadGroupX, threadGroupY, 1);

            // GraphicsFence fence = Graphics.CreateGraphicsFence(GraphicsFenceType.AsyncQueueSynchronisation, SynchronisationStageFlags.PixelProcessing);
            // Graphics.WaitOnAsyncGraphicsFence(fence);
            //
            // Graphics.CopyTexture(weightMapArrayRT, weightMapArray);

            AsyncGPUReadback.Request(weightMapArrayRT, 0, request =>
            {
                if (request.hasError)
                {
                    Debug.LogError("❌ GPU Readback failed!");
                    return;
                }

                // 计算完成，执行 CopyTexture
                Graphics.CopyTexture(weightMapArrayRT, weightMapArray);
            });
        }

        private void OnMouseUp()
        {
            AsyncGPUReadback.Request(weightMapArrayRT, 0, 0, weightMapArrayRT.width, 0, weightMapArrayRT.height, 0,
                weightMapArrayRT.volumeDepth, request =>
                {
                    if (request.hasError)
                    {
                        Debug.LogError("❌ GPU Readback 失败！");
                        return;
                    }

                    // 拷贝数据到 Texture2DArray
                    for (int i = 0; i < weightMapArrayRT.volumeDepth; i++)
                    {
                        Color32[] layerPixels = request.GetData<Color32>(i).ToArray();
                        weightMapArray.SetPixels32(layerPixels, i);
                    }

                    weightMapArray.Apply();

                    // 保存为 Unity 资源
                    // SaveTextureArray(weightMapArray, controlMapPath);
                });
        }

        /// <summary>
        /// 把地形纹理打包为Array TODO 应该在添加或删除或替换纹理时自动保存，需要管理路径
        /// </summary>
        public void SaveTerrainTexturesToTexture2DArray()
        {
            string path = CONTROL_MAP_PATH + "Terrain_Albedo.asset";
            List<Texture2D> albedoTextures = terrainTextures.Select(t => t.albedoMap).ToList();
            TextureArrayGenerator.CreateAndSaveTextureArray(albedoTextures, path, 1024);
            
            path = CONTROL_MAP_PATH + "Terrain_Normal.asset";
            Texture2D defaultNormal = new Texture2D(1, 1, TextureFormat.RGBA32, false);
            defaultNormal.SetPixel(0, 0, new Color(0.5f, 0.5f, 1f, 1f)); // 标准法线颜色
            defaultNormal.Apply();
            // List<Texture2D> normalTextures = terrainTextures.Select(t => t.normalMap).ToList();
            List<Texture2D> normalTextures =
                terrainTextures.Select(t => t.normalMap != null ? t.normalMap : defaultNormal).ToList();
            TextureArrayGenerator.CreateAndSaveTextureArray(normalTextures, path, 1024);
            
            path = CONTROL_MAP_PATH + "Terrain_Mask.asset";
            Texture2D defaultMask = new Texture2D(1, 1, TextureFormat.RGBA32, false);
            defaultMask.SetPixel(0, 0, new Color(1f, 1f, 1f, 1f)); // 标准法线颜色
            defaultMask.Apply();
            List<Texture2D> maskTextures =
                terrainTextures.Select(t => t.maskMap != null ? t.maskMap : defaultMask).ToList();
            TextureArrayGenerator.CreateAndSaveTextureArray(maskTextures, path, 1024);
        }

        /// <summary>
        /// 异步保存，解决卡顿的问题不佳
        /// </summary>
        public static class AsyncEditorSave
        {
            private static readonly Queue<string> assetQueue = new Queue<string>();
            private static bool isSaving = false;

            public static void SaveAssetAsync(string assetPath)
            {
                if (!assetQueue.Contains(assetPath))
                {
                    assetQueue.Enqueue(assetPath);
                }

                if (!isSaving)
                {
                    isSaving = true;
                    EditorApplication.update += ProcessSaveQueue;
                }
            }

            private static void ProcessSaveQueue()
            {
                if (assetQueue.Count > 0)
                {
                    string assetPath = assetQueue.Dequeue();
                    AssetDatabase.ImportAsset(assetPath, ImportAssetOptions.ForceUpdate);
                    AssetDatabase.SaveAssets();
                    AssetDatabase.Refresh();
                    Debug.Log($"异步保存: {assetPath}");
                }
                else
                {
                    // 没有需要保存的内容，停止更新
                    EditorApplication.update -= ProcessSaveQueue;
                    isSaving = false;
                }
            }
        }
    }
}