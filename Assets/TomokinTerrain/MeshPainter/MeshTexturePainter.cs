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
#if UNITY_EDITOR

    [RequireComponent(typeof(MeshCollider))]
    [ExecuteInEditMode]
    public class MeshTexturePainter : MonoBehaviour
    {
        // public List<Texture2D> terrainTextures = new List<Texture2D>(); // 地形纹理列表
        public List<TerrainTexture> terrainTextures = new List<TerrainTexture>();
        public TerrainTextureAsset terrainAsset;
        public Texture2D[] terrainPreview;

        // [Serializable]
        // public class TerrainTexture
        // {
        //     public Texture2D albedoMap;
        //     public Texture2D normalMap;
        //     public Texture2D maskMap;
        //     public float tilling;
        //
        //     public TerrainTexture(Texture2D albedo = null)
        //     {
        //         this.albedoMap = albedo;
        //         this.normalMap = null;
        //         this.maskMap = null;
        //         this.tilling = 1;
        //     }
        // }

        public void AddTerrainTexture()
        {
            if (terrainTextures.Count == 0)
            {
                terrainTextures.Add(new TerrainTexture());
            }
            else
            {
                // terrainTextures.Insert(selectedIndex + 1, new TerrainTexture());
                // selectedIndex++;
                terrainTextures.Add(new TerrainTexture());
            }
        }

        public void AddTerrainTexture(Texture2D albedoMap)
        {
            terrainTextures.Add(new TerrainTexture(albedoMap));
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

        public float brushSize = 1.0f;
        private const float brushSizeDelta = 0.2f;
        private float brushScale = 1.0f;                // 初始化时，对齐模型的尺寸
        public float brushStrength = 0.5f;

        [HideInInspector] public static bool isSelected = false;
        [HideInInspector] public bool isPainting = false;
        [HideInInspector] public bool isSavedWeight = false;
        private double lastRepaintTime = 0; // 上次刷新的时间
        private const double repaintInterval = 0.03; // 限制 30ms 刷新一次（大约 33FPS）
        private bool _onMouseDone;

        private Material _material;

        private Material material
        {
            get
            {
                if (_material == null)
                {
                    _material = GetComponent<MeshRenderer>()?.sharedMaterial;
                }
                return _material;
            }
            set
            {
                _material = value;
                if (_material != null)
                {
                    // 获取材质完整路径
                    string fullPath = AssetDatabase.GetAssetPath(_material);
                    // 仅获取所在文件夹路径
                    CONTROL_MAP_PATH = Path.GetDirectoryName(fullPath).Replace("\\", "/") + "/";

                    Debug.Log("材质路径已更新: " + CONTROL_MAP_PATH);
                }
                else
                {
                    CONTROL_MAP_PATH = null;
                }
            }
        }
        private const int CHANNELS_PER_MAP = 4; // 每张权重图支持 4 层纹理

        public int controlChannels
        {
            get => CHANNELS_PER_MAP;
        }

        private int requiredWeightMaps
        {
            get => Mathf.CeilToInt(terrainTextures.Count / (float)CHANNELS_PER_MAP);
        }

        private int weightMapIndex = 0;     // 记录是第几个Weight纹理
        private int weightMapChannel = 0;   // 记录是Weight纹理中RGBA哪一个通道

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

        // 会随着材质球的路径变化而变化
        private string CONTROL_MAP_PATH = "Assets/ControlMaps/";

        public string GetPath => CONTROL_MAP_PATH;

        private string controlMapName => "T_" + gameObject.name + "_Control";
        private string controlMapPath => CONTROL_MAP_PATH + controlMapName + ".asset";
        private string albedoMapName => "T_" + gameObject.name + "_D";     // Albedo
        private string albedoMapPath => CONTROL_MAP_PATH + albedoMapName + ".asset";
        private string normalMapName => "T_" + gameObject.name + "_N";     // Normal
        private string normalMapPath => CONTROL_MAP_PATH + normalMapName + ".asset";
        private string maskMapName => "T_" + gameObject.name + "_SM";      // Mask
        private string maskMapPath => CONTROL_MAP_PATH + maskMapName + ".asset";

        private ComputeShader brushComputeShader;

        // private Texture2D savedWeightMap;           // 备份贴图
        private Texture2DArray backupWeightMapArray; // 备份贴图
        private RenderTexture paintRT; // 记录当前绘制路径
        private RenderTexture weightMapArrayRT; // 记录当前绘制路径

        private void Reset()
        {
            if (GetComponent<MeshRenderer>() == null)
            {
                Debug.LogWarning("没有MeshRenderer");
                return;
            }
            // 新建组件时初始化材质球和路径
            _material = GetComponent<MeshRenderer>()?.sharedMaterial;
            if (_material == null)
            {
                Debug.LogWarning("没有材质球，请添加后重新启用组件以更新纹理保存路径");
                return;
            }
            // 获取材质完整路径
            string fullPath = AssetDatabase.GetAssetPath(_material);
            // 仅获取所在文件夹路径
            CONTROL_MAP_PATH = Path.GetDirectoryName(fullPath).Replace("\\", "/") + "/";
        }

        private void OnEnable()
        {
            InitializeComputeShader();  // 获取绘制使用的ComputeShader
            InitializeTextures();       // 初始化权重贴图
            InitializeBrushScale();     // 根据模型的大小匹配笔刷大小
            ConvertToPreviewTexture();  // 初始化预览图
            SceneView.duringSceneGui -= OnSceneGUI;
            SceneView.duringSceneGui += OnSceneGUI;
            
            Selection.selectionChanged -= UpdateIsSelected;
            Selection.selectionChanged += UpdateIsSelected;
        }

        public void ManualInitialize()
        {
            OnEnable();
        }

        private void OnDisable()
        {
            SceneView.duringSceneGui -= OnSceneGUI;
            Selection.selectionChanged -= UpdateIsSelected;

            DestroyImmediate(backupWeightMapArray);
            DestroyImmediate(paintRT);
            DestroyImmediate(weightMapArrayRT);

            isPainting = false;
            Tools.hidden = false;
            // SaveWeightTextureArray();
        }

        private void OnDestroy()
        {
            OnDisable();
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

        /// <summary>
        /// 把权重图链接到材质上
        /// </summary>
        public void RelatedToMaterial()
        {
            // material = GetComponent<MeshRenderer>().sharedMaterial;
            if (weightMapArray == null)
            {
                Debug.LogError("没有权重图");
            }
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
            // 标记材质为“脏”（表示已修改）
            EditorUtility.SetDirty(material);
            // 保存修改到磁盘
            AssetDatabase.SaveAssets();
        }

        /// <summary>
        /// 脚本Enable的时候初始化
        /// </summary>
        private void InitializeTextures()
        {
            if (terrainTextures.Count == 0 || GetComponent<MeshRenderer>() == null) return;

            _material = GetComponent<MeshRenderer>()?.sharedMaterial;
            // 获取材质完整路径
            string fullPath = AssetDatabase.GetAssetPath(_material);
            // 仅获取所在文件夹路径
            CONTROL_MAP_PATH = Path.GetDirectoryName(fullPath).Replace("\\", "/") + "/";

            UpdateWeightMaps();
        }

        /// <summary>
        /// 保存权重图执行的事件
        /// </summary>
        public void UpdateWeightMaps()
        {
            // 如果正处在编辑模式，重新初始化RT
            if (isPainting)
            {
                ClearRT();
                InitializeRT();
            }
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
                DestroyImmediate(tempTex);
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

        public void SaveWeightTextureArray()
        {
            if (weightMapArray == null) return;
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

            weightMapArray = LoadTextureArray(assetPath);
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

        private void UpdateIsSelected()
        {
            // 检查当前是否有 Painter 组件被选中
            isSelected = false;
            foreach (var obj in Selection.gameObjects)
            {
                if (obj.GetComponent<MeshTexturePainter>() != null)
                {
                    isSelected = true;
                    break; // 只要找到一个，就不需要继续遍历
                }
            }

            // 强制 SceneView 刷新，保证 Tools.hidden 及时更新
            SceneView.RepaintAll();
        }
        
        private void OnSceneGUI(SceneView sceneView)
        {
            if (Selection.activeGameObject == gameObject)
            {
                Tools.hidden = isPainting;
                if (!isPainting)
                {
                    if (!isSavedWeight)
                    {
                        SaveWeightTextureArray();
                        isSavedWeight = true;
                    }
                    return;
                }
            }
            else
            {
                // 没有任何带此脚本的物体被选中
                if(!isSelected) Tools.hidden = false;
                return;
            }

            // Tools.hidden = true; // 隐藏移动、旋转、缩放 Gizmo

            Event e = Event.current;
            if (e == null) return;
            
            if (e.type == EventType.KeyUp && 
                e.control && 
                e.keyCode == KeyCode.S)
            {
                Debug.Log("检测到 Ctrl+S，保存纹理数据...");
                SaveTerrainTexturesToTexture2DArray();          // 保存纹理层
                UpdateWeightMaps();                             // 刷新权重图
                ConvertToPreviewTexture();                      // 刷新纹理预览
            }
            
            if (e.alt)
            {
                return;
            }

            // **Ctrl + 鼠标水平位移调整笔刷强度**
            if (e.control && e.type == EventType.MouseDrag && e.button == 0)
            {
                brushStrength += e.delta.x * 0.001f; // 根据鼠标水平移动调整强度
                brushStrength = Mathf.Clamp(brushStrength, 0.001f, 1f); // 限制范围

                e.Use(); // 使用事件，防止 Unity 处理它
                return;
            }

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
                    if (_onMouseDone)
                    {
                        Handles.CircleHandleCap(0, hit.point, Quaternion.LookRotation(hit.normal),
                            brushSize, EventType.Repaint);
                    }
                    else
                    {
                        Handles.DrawSolidDisc(hit.point, hit.normal, brushSize);
                    }
                    Handles.color = new Color(0.6f, 0.6f, 0.9f, 1f);
                    Handles.DrawLine(hit.point, hit.point + hit.normal * brushSize);
                    
                    // **Ctrl + 滚轮调整笔刷大小**
                    if (e.control && e.type == EventType.ScrollWheel)
                    {
                        brushSize += e.delta.y * -0.01f * brushSize;
                        brushSize = Mathf.Clamp(brushSize, 0.01f, 10f);     // 限制大小范围
                        e.Use();
                    }

                    // **[ ] 调整笔刷大小**
                    if (e.type == EventType.KeyDown && e.keyCode == KeyCode.LeftBracket)
                    {
                        brushSize -= brushSizeDelta;
                        brushSize = Mathf.Clamp(brushSize, 0.01f, 10f);     // 限制大小范围
                        e.Use();
                    }
                    if (e.type == EventType.KeyDown && e.keyCode == KeyCode.RightBracket)
                    {
                        brushSize += brushSizeDelta;
                        brushSize = Mathf.Clamp(brushSize, 0.01f, 10f); // 限制大小范围
                        e.Use();
                    }

                    // **绘制**
                    if (e.type == EventType.MouseDown && e.button == 0 && !e.control)
                    {
                        // 鼠标按下时，初始化
                        OnEditorMouseDown();
                        // 绘制
                        OnEditorMouseDrag(hit.textureCoord);
                        // 刷新Handle
                        HandleUtility.Repaint();
                        _onMouseDone = true;
                        
                        // 如果有新的绘制，才会执行保存
                        isSavedWeight = false;
                    }

                    if (e.type == EventType.MouseDrag && e.button == 0 && !e.control)
                    {
                        // 绘制
                        OnEditorMouseDrag(hit.textureCoord);
                        // 刷新Handle
                        HandleUtility.Repaint();
                    }

                    // **刷新笔刷GUI**
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

            if (e.type == EventType.MouseUp && e.button == 0 && _onMouseDone)
            {
                // 绘制
                OnEditorMouseUp();
                _onMouseDone = false;
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
                    _textureFormat, false);
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

            terrainPreview = result;

            return result;
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

        private void OnEditorMouseDown()
        {
            if (weightMapArray.depth == 0 || weightMapArray == null) return;

            if (backupWeightMapArray == null || paintRT == null || weightMapArrayRT == null) InitializeRT();

            Undo.RegisterCompleteObjectUndo(weightMapArray, "Modify WeightMapArray");
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
        private void OnEditorMouseDrag(Vector2 uv)
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

        private void OnEditorMouseUp()
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
                    // EditorUtility.SetDirty(weightMapArray);

                    // 保存为 Unity 资源
                    // SaveTextureArray(weightMapArray, controlMapPath);
                });
        }

        /// <summary>
        /// 把地形纹理打包为Array
        /// </summary>
        public void SaveTerrainTexturesToTexture2DArray()
        {
            List<Texture2D> albedoTextures = terrainTextures.Select(t => t.albedoMap).ToList();
            TextureArrayGenerator.CreateAndSaveTextureArray(albedoTextures, albedoMapPath, _terrainTextureSize);

            Texture2D defaultNormal = new Texture2D(1, 1, _textureFormat, false);
            // defaultNormal.SetPixel(0, 0, new Color(0.5f, 0.5f, 1f, 1f)); // 标准法线颜色
            defaultNormal.SetPixel(0, 0, new Color(1.0f, 0.5f, 0.5f, 0.5f)); // DXT5nm法线颜色
            defaultNormal.Apply();
            // List<Texture2D> normalTextures = terrainTextures.Select(t => t.normalMap).ToList();
            List<Texture2D> normalTextures =
                terrainTextures.Select(t => t.normalMap != null ? t.normalMap : defaultNormal).ToList();
            TextureArrayGenerator.CreateAndSaveTextureArray(normalTextures, normalMapPath, _terrainTextureSize);

            Texture2D defaultMask = new Texture2D(1, 1, _textureFormat, false);
            defaultMask.SetPixel(0, 0, new Color(0f, 0f, 0f, 1f)); // 光滑 0 金属 0
            defaultMask.Apply();
            List<Texture2D> maskTextures =
                terrainTextures.Select(t => t.maskMap != null ? t.maskMap : defaultMask).ToList();
            TextureArrayGenerator.CreateAndSaveTextureArray(maskTextures, maskMapPath, _terrainTextureSize);

            // ================ 把纹理传入材质球 ================
            // material = GetComponent<MeshRenderer>().sharedMaterial;
            Texture2DArray tempLoadTextureArray = LoadTextureArray(albedoMapPath);
            if (material.HasProperty("_BaseMap"))
                material.SetTexture("_BaseMap", tempLoadTextureArray);
            else
                Debug.LogWarning("Shader 没有_BaseMap参数");

            tempLoadTextureArray = LoadTextureArray(normalMapPath);
            if (material.HasProperty("_BumpMap"))
            {
                material.SetTexture("_BumpMap", tempLoadTextureArray);
                material.EnableKeyword("_NORMALMAP");
            }
            else
                Debug.LogWarning("Shader 没有_BumpMap参数");

            tempLoadTextureArray = LoadTextureArray(maskMapPath);
            if (material.HasProperty("_SMAEMap"))
                material.SetTexture("_SMAEMap", tempLoadTextureArray);
            else
                Debug.LogWarning("Shader 没有_SMAEMap参数");
            
            // 标记材质为“脏”（表示已修改）
            EditorUtility.SetDirty(material);
            // 保存修改到磁盘
            AssetDatabase.SaveAssets();
        }

        #region UpadateTerrainLayer

        public void UpdateTiling(int index)
        {
            if (material == null)
            {
                return;
            }

            string paramName = $"_UVScale{index+1:D2}";
            if (material.HasProperty(paramName))
            {
                material.SetFloat(paramName, terrainTextures[index].tilling);
            }
            else
            {
                Debug.LogWarning($"没有参数:{paramName}");
            }
            paramName = $"_UVOffset{index+1:D2}";
            if (material.HasProperty(paramName))
            {
                Vector4 current = material.GetVector(paramName);
                Vector2 offset = terrainTextures[index].offset;
                current.z = offset.x;
                current.w = offset.y;
                material.SetVector(paramName, current);
            }
            else
            {
                Debug.LogWarning($"没有参数:{paramName}");
            }
        }
        public void UpdateAlbedoInArray(Texture2D newTexture)
        {
            if (newTexture == null)
            {
                Debug.LogWarning($"Texture at index {selectedIndex} is null, using a black texture.");
                newTexture = new Texture2D(1, 1, _textureFormat, false);
                newTexture.SetPixel(0, 0, Color.black);
                newTexture.Apply();
            }
            UpdateTextureInArray(newTexture, selectedIndex, albedoMapPath);
        }
        public void UpdateNormalInArray(Texture2D newTexture)
        {
            if (newTexture == null)
            {
                Debug.LogWarning($"Texture at index {selectedIndex} is null, default normal texture.");
                newTexture = new Texture2D(1, 1, _textureFormat, false);
                newTexture.SetPixel(0, 0, new Color(1.0f, 0.5f, 0.5f, 0.5f));
                newTexture.Apply();
            }
            UpdateTextureInArray(newTexture, selectedIndex, normalMapPath);
        }
        public void UpdateMaskInArray(Texture2D newTexture)
        {
            if (newTexture == null)
            {
                Debug.LogWarning($"Texture at index {selectedIndex} is null, using a black texture.");
                newTexture = new Texture2D(1, 1, _textureFormat, false);
                newTexture.SetPixel(0, 0, Color.black);
                newTexture.Apply();
            }
            UpdateTextureInArray(newTexture, selectedIndex, maskMapPath);
        }
        private static void UpdateTextureInArray(Texture2D newTexture, int index, string textureArrayPath)
        {
            // **加载已有的 Texture2DArray**
            Texture2DArray textureArray = AssetDatabase.LoadAssetAtPath<Texture2DArray>(textureArrayPath);
            if (textureArray == null)
            {
                Debug.LogError("未找到 Texture2DArray 资源: " + textureArrayPath);
                return;
            }

            if (index < 0 || index >= textureArray.depth)
            {
                Debug.LogError("索引超出范围: " + index);
                return;
            }

            int width = textureArray.width;
            int height = textureArray.height;
            TextureFormat format = TextureFormat.RGBA32;

            // **拷贝新纹理到 `Texture2DArray` 的指定层**

            // 手动解压 贴图 到 RGBA32
            Texture2D tempTexture = new Texture2D(width, height, format, false);
            // Debug.LogError($"Texture {i} has a different size! Rescale required.");
            RenderTexture rt = RenderTexture.GetTemporary(width, height, 0);
            
            Graphics.Blit(newTexture, rt);
            RenderTexture.active = rt;
            tempTexture.ReadPixels(new Rect(0, 0, width, height), 0, 0);
            tempTexture.Apply();
            RenderTexture.active = null;
            RenderTexture.ReleaseTemporary(rt);

            // 拷贝到Texture2DArray
            Graphics.CopyTexture(tempTexture, 0, 0, textureArray, index, 0);

            // **标记资源已更改**
            EditorUtility.SetDirty(textureArray);
            AssetDatabase.SaveAssets();
            Debug.Log($"更新 {index} 层的贴图成功！");
        }
        #endregion

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

#endif
}
