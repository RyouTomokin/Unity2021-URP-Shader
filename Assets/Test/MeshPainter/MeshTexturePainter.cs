using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;
using Unity.Collections;
using Unity.VisualScripting;
using UnityEngine.Rendering;

namespace Tomokin
{
    [ExecuteInEditMode]
    public class MeshTexturePainter : MonoBehaviour
    {
        public List<Texture2D> terrainTextures = new List<Texture2D>(); // 地形纹理列表
        public List<Texture2D> weightMaps = new List<Texture2D>(); // 权重贴图列表
        public int selectedTextureIndex = 0; // 选择的地形纹理索引
        public float brushSize = 0.1f;
        private float brushScale = 1.0f;
        public float brushStrength = 0.5f;

        [HideInInspector] public bool isPainting = false;
        private double lastRepaintTime = 0;
        private const double repaintInterval = 0.03; // 限制 30ms 刷新一次（大约 33FPS）

        private Material material;
        private const int CHANNELS_PER_MAP = 4;     // 每张权重图支持 4 层纹理
        public int controlChannels
        {
            get => CHANNELS_PER_MAP;
        }
        private int weightMapIndex = 0;
        private int weightMapChannel = 0;

        private int _textureSize = 2048;
        public int TextureSize
        {
            get => _textureSize; // 读取值
            set
            {
                _textureSize = Mathf.Clamp(value, 128, 4096); // 限制范围，防止异常值
                // Debug.Log($"纹理大小已更新：{_textureSize}");
            }
        }
        // TODO 遵循地形烘焙的规则
        private const string CONTROL_MAP_PATH = "Assets/ControlMaps/";

        private ComputeShader brushComputeShader;
        private Texture2D savedWeightMap;           // 备份贴图
        private RenderTexture paintRT;              // 记录当前绘制路径
        private RenderTexture finalWeightRT;        // 记录当前绘制路径

        public bool isDebugMode;

        #region OnDrawGizmos

        private Texture2D rTexture, gTexture, bTexture, aTexture;

        private void UpdateChannelTextures()
        {
            if (weightMaps[0] == null) return;

            int width = weightMaps[0].width;
            int height = weightMaps[0].height;

            // 创建灰度贴图
            if (rTexture == null) rTexture = new Texture2D(width, height, TextureFormat.RGBA32, false);
            if (gTexture == null) gTexture = new Texture2D(width, height, TextureFormat.RGBA32, false);
            if (bTexture == null) bTexture = new Texture2D(width, height, TextureFormat.RGBA32, false);
            if (aTexture == null) aTexture = new Texture2D(width, height, TextureFormat.RGBA32, false);

            Color[] pixels = weightMaps[0].GetPixels();
            Color[] rPixels = new Color[pixels.Length];
            Color[] gPixels = new Color[pixels.Length];
            Color[] bPixels = new Color[pixels.Length];
            Color[] aPixels = new Color[pixels.Length];

            for (int i = 0; i < pixels.Length; i++)
            {
                float r = pixels[i].r;
                float g = pixels[i].g;
                float b = pixels[i].b;
                float a = pixels[i].a;

                rPixels[i] = new Color(r, r, r, 1);  // 灰度图：R 通道
                gPixels[i] = new Color(g, g, g, 1);  // 灰度图：G 通道
                bPixels[i] = new Color(b, b, b, 1);  // 灰度图：B 通道
                aPixels[i] = new Color(a, a, a, 1);  // 灰度图：A 通道
            }

            rTexture.SetPixels(rPixels);
            gTexture.SetPixels(gPixels);
            bTexture.SetPixels(bPixels);
            aTexture.SetPixels(aPixels);

            rTexture.Apply();
            gTexture.Apply();
            bTexture.Apply();
            aTexture.Apply();
        }

        private bool updateDebugGizmos = false;
        private void OnDrawGizmos()
        {
            if (savedWeightMap == null || !isDebugMode) return;
            if (updateDebugGizmos)
            {
                // 更新通道贴图
                UpdateChannelTextures();
                updateDebugGizmos = false;
            }

            Handles.BeginGUI();
            float size = 128;
            GUI.DrawTexture(new Rect(10, 10, size, size), savedWeightMap, ScaleMode.ScaleToFit);
            GUI.Label(new Rect(10, 10 + size, size, 20), "Original");

            GUI.DrawTexture(new Rect(20 + size, 10, size, size), rTexture, ScaleMode.ScaleToFit);
            GUI.Label(new Rect(20 + size, 10 + size, size, 20), "R Channel");

            GUI.DrawTexture(new Rect(30 + 2 * size, 10, size, size), gTexture, ScaleMode.ScaleToFit);
            GUI.Label(new Rect(30 + 2 * size, 10 + size, size, 20), "G Channel");

            GUI.DrawTexture(new Rect(40 + 3 * size, 10, size, size), bTexture, ScaleMode.ScaleToFit);
            GUI.Label(new Rect(40 + 3 * size, 10 + size, size, 20), "B Channel");

            GUI.DrawTexture(new Rect(50 + 4 * size, 10, size, size), aTexture, ScaleMode.ScaleToFit);
            GUI.Label(new Rect(50 + 4 * size, 10 + size, size, 20), "A Channel");

            Handles.EndGUI();
        }

        #endregion

        private void OnEnable()
        {
            InitializeComputeShader();
            InitializeTextures();
            InitializeBrushScale();
            SceneView.duringSceneGui += OnSceneGUI;
        }

        private void OnDisable()
        {
            SceneView.duringSceneGui -= OnSceneGUI;
            
            DestroyImmediate(savedWeightMap);
            DestroyImmediate(paintRT);
            DestroyImmediate(finalWeightRT);
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

        private string GetControlMapName(int id, bool isCopy = false)
        {
            if (isCopy)
            {
                return "ControlMap_" + id + "_copy.png";
            }
            else
            {
                return "ControlMap_" + id + ".png";
            }
        }

        public void RelatedToMaterial()
        {
            material = GetComponent<MeshRenderer>().sharedMaterial;
            if (isDebugMode)
            {
                material.mainTexture = weightMaps.Count > 0 ? weightMaps[0] : null; // 设置第一张权重图为材质主纹理
            }
            else
            {
                if (weightMaps.Count < 0)
                {
                    Debug.LogWarning("请点击获取权重图");
                    return;
                }

                // if (weightMaps[0] == null)
                // {
                //     // 尝试重磁盘获取贴图
                //     UpdateWeightMapsFromDisk();
                // }
                if (material.HasProperty("_ControlMap"))
                {
                    material.SetTexture("_ControlMap", weightMaps.Count > 0 ? weightMaps[0] : null);
                }
                else
                {
                    Debug.LogWarning("Shader 没有_ControlMap参数");
                }
            }
        }
        
        private void InitializeTextures()
        {
            // weightMaps.Clear();
            if (terrainTextures.Count == 0 || GetComponent<MeshRenderer>() == null) return;

            // UpdateWeightMaps();
            UpdateWeightMapsFromDisk();
        }
        
        public void UpdateWeightMaps()
        {
            int requiredWeightMaps = Mathf.CeilToInt(terrainTextures.Count / (float)CHANNELS_PER_MAP);

            if (!Directory.Exists(CONTROL_MAP_PATH))
            {
                Directory.CreateDirectory(CONTROL_MAP_PATH);
            }

            // 判断weightMaps是否多余
            for (int i = weightMaps.Count - 1; i >= 0; i--)
            {
                string texturePath = CONTROL_MAP_PATH + GetControlMapName(i);
                // 如果weightMaps[i]为空，查找路径下是否有贴图，若没有，创建一个
                if (weightMaps[i] == null)
                {
                    Texture2D texture = (Texture2D)AssetDatabase.LoadAssetAtPath(texturePath, typeof(Texture2D));
                    if (texture == null)
                    {
                        texture = CreateNewWeightMap(_textureSize);
                        SaveTextureAsPNG(texture, texturePath);
                        texture = (Texture2D)AssetDatabase.LoadAssetAtPath(texturePath, typeof(Texture2D));
                        weightMaps[i] = texture;
                    }
                    weightMaps[i] = texture;
                }
                // 删除超出数量的内存贴图
                if (i >= requiredWeightMaps)
                {
                    texturePath = CONTROL_MAP_PATH + GetControlMapName(i, true);
                    // Texture2D newTexture = CreateNewWeightMap(_textureSize);
                    SaveTextureAsPNG(weightMaps[i], texturePath);
                    
                    DestroyImmediate(weightMaps[i], true); // 释放贴图
                    weightMaps.RemoveAt(i);
                }
                else
                {
                    // 把内存中的贴图保存到磁盘
                    // Texture2D newWeightMap = CreateNewWeightMap(_textureSize);
                    SaveTextureAsPNG(weightMaps[i], texturePath);
                    weightMaps[i] = (Texture2D)AssetDatabase.LoadAssetAtPath(texturePath, typeof(Texture2D));
                }
            }

            // weightMaps不足则添加
            if (requiredWeightMaps > weightMaps.Count)
            {
                for (int i = weightMaps.Count; i < requiredWeightMaps; i++)
                {
                    // 贴图不够，创建新的贴图
                    string texturePath = CONTROL_MAP_PATH + GetControlMapName(i);
                    Texture2D newWeightMap = CreateNewWeightMap(_textureSize);
                    SaveTextureAsPNG(newWeightMap, texturePath);
                    weightMaps.Add(newWeightMap);
                }
            }

            RelatedToMaterial();
        }

        public void UpdateWeightMapsFromDisk()
        {
            int requiredWeightMaps = Mathf.CeilToInt(terrainTextures.Count / (float)CHANNELS_PER_MAP);
            // 从磁盘获取weightMaps，若本地没有则把内存中的东西保存到磁盘，再重新引用磁盘纹理
            for (int i = 0; i < requiredWeightMaps; i++)
            {
                string texturePath = CONTROL_MAP_PATH + GetControlMapName(i);
                Texture2D texture = (Texture2D)AssetDatabase.LoadAssetAtPath(texturePath, typeof(Texture2D));
                if (texture == null)
                {
                    texture = CreateNewWeightMap(_textureSize);
                    SaveTextureAsPNG(texture, texturePath);
                    texture = (Texture2D)AssetDatabase.LoadAssetAtPath(texturePath, typeof(Texture2D));
                }

                if (weightMaps.Count < i + 1)
                {
                    weightMaps.Add(texture);
                }
                else
                {
                    weightMaps[i] = texture;
                }
            }
            RelatedToMaterial();
        }
        
        public void ClearWeightMaps()
        {
            weightMaps.Clear();
        }

        public void CheckWeightMapsCount()
        {
            int requiredWeightMaps = Mathf.CeilToInt(terrainTextures.Count / (float)CHANNELS_PER_MAP);
            if(requiredWeightMaps == weightMaps.Count) return;
            UpdateWeightMaps();
        }

        /// <summary>
        /// 创建新的 Weight Map 贴图
        /// </summary>
        private Texture2D CreateNewWeightMap(int size)
        {
            // 所有权重图都需要线性
            Texture2D newTexture = new Texture2D(size, size, TextureFormat.RGBA32, false, true)
            {
                wrapMode = TextureWrapMode.Clamp
            };

            Color[] pixels = new Color[size * size];
            for (int i = 0; i < pixels.Length; i++)
            {
                pixels[i] = new Color(0, 0, 0, 0); // 初始化全透明
            }

            newTexture.SetPixels(pixels);
            newTexture.Apply();
            return newTexture;
        }

        /// <summary>
        /// 保存贴图到本地
        /// </summary>
        private void SaveTextureAsPNG(Texture2D texture, string path)
        {
            Texture2D textureToSave = texture;

            // 如果贴图大小不符合 _textureSize，则创建新的
            if (texture.width != _textureSize || texture.height != _textureSize)
            {
                RenderTexture rt = new RenderTexture(_textureSize, _textureSize, 0, RenderTextureFormat.ARGB32);
                Graphics.Blit(texture, rt);

                // 创建新的 Texture2D 以存储数据,需要线性
                textureToSave = new Texture2D(_textureSize, _textureSize, TextureFormat.RGBA32, false, true);
                RenderTexture.active = rt;
                textureToSave.ReadPixels(new Rect(0, 0, _textureSize, _textureSize), 0, 0);
                textureToSave.Apply();

                // 清理 RenderTexture
                RenderTexture.active = null;
                rt.Release();
                DestroyImmediate(rt);
            }

            // 保存 PNG
            byte[] bytes = textureToSave.EncodeToPNG();
            File.WriteAllBytes(path, bytes);
            AssetDatabase.ImportAsset(path);

            // 确保贴图可读写
            TextureImporter importer = AssetImporter.GetAtPath(path) as TextureImporter;
            if (importer != null)
            {
                importer.textureType = TextureImporterType.Default;
                importer.sRGBTexture = false;
                importer.isReadable = true;
                importer.mipmapEnabled = false;
                importer.wrapMode = TextureWrapMode.Repeat;
                importer.maxTextureSize = _textureSize;
                
                TextureImporterPlatformSettings settings = importer.GetDefaultPlatformTextureSettings();
                settings.resizeAlgorithm = TextureResizeAlgorithm.Mitchell;
                settings.format = TextureImporterFormat.RGBA32;
                importer.SetPlatformTextureSettings(settings);
                
                importer.SaveAndReimport();
            }

            // 只有在新创建了 Texture2D 时才销毁它
            if (textureToSave != texture)
            {
                DestroyImmediate(textureToSave);
            }
        }

        public void SaveAllWeightMaps()
        {
            for (int i = 0; i < weightMaps.Count; i++)
            {
                string texturePath = CONTROL_MAP_PATH + GetControlMapName(weightMapIndex);
                SaveTextureAsPNG(weightMaps[i], texturePath);
            }
        }

        private void OnSceneGUI(SceneView sceneView)
        {
            if (!(isPainting && Selection.activeGameObject == gameObject)) return;

            Tools.hidden = true;  // 隐藏移动、旋转、缩放 Gizmo

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
                updateDebugGizmos = true;
            }
            // HandleUtility.Repaint();
        }

        public void SelectTexture(int index)
        {
            if (index >= 0 && index < terrainTextures.Count)
            {
                selectedTextureIndex = index;

                weightMapIndex = selectedTextureIndex / CHANNELS_PER_MAP;
                weightMapChannel = selectedTextureIndex % CHANNELS_PER_MAP;
            }
        }

        //TODO 笔刷样式
        // public void PaintAtUV(Vector2 uv)
        // {
        //     if (weightMaps.Count == 0 || selectedTextureIndex >= terrainTextures.Count) return;
        //     
        //     Texture2D weightMap = weightMaps[weightMapIndex];
        //
        //     int texWidth = weightMap.width;
        //     int texHeight = weightMap.height;
        //
        //     float brushSizeInPixels = brushSize * brushScale;       // 计算笔刷像素大小
        //     int startX = Mathf.FloorToInt((uv.x - brushSizeInPixels) * texWidth);
        //     int startY = Mathf.FloorToInt((uv.y - brushSizeInPixels) * texHeight);
        //     int endX = Mathf.FloorToInt((uv.x + brushSizeInPixels) * texWidth);
        //     int endY = Mathf.FloorToInt((uv.y + brushSizeInPixels) * texHeight);
        //
        //     Color[] pixels = weightMap.GetPixels();
        //
        //     for (int x = startX; x < endX; x++)
        //     {
        //         for (int y = startY; y < endY; y++)
        //         {
        //             if (x >= 0 && x < texWidth && y >= 0 && y < texHeight)
        //             {
        //                 int index = y * texWidth + x;
        //                 Color pixel = pixels[index];
        //
        //                 float weight = Mathf.Clamp01(pixel[weightMapChannel] + brushStrength);
        //                 pixel[weightMapChannel] = weight;
        //
        //                 // 确保所有通道总和不超过 1.0
        //                 float totalWeight = pixel.r + pixel.g + pixel.b + pixel.a;
        //                 if (totalWeight > 1.0f)
        //                 {
        //                     float scale = 1.0f / totalWeight;
        //                     pixel.r *= scale;
        //                     pixel.g *= scale;
        //                     pixel.b *= scale;
        //                     pixel.a *= scale;
        //                 }
        //
        //                 pixels[index] = pixel;
        //             }
        //         }
        //     }
        //
        //     weightMap.SetPixels(pixels);
        //     weightMap.Apply(false);
        // }
        //
        public void PaintAtUV(Vector2 uv)
        {
            if (weightMaps.Count == 0 || selectedTextureIndex >= terrainTextures.Count) return;

            // RenderTexture weightMap = weightMaps[weightMapIndex]; // 需要转换为 RenderTexture
            Texture2D weightTexture2D = weightMaps[weightMapIndex];
            // TODO:不要每帧new RT
            RenderTexture weightMap = new RenderTexture(weightTexture2D.width, weightTexture2D.height, 0, RenderTextureFormat.ARGB32);
            weightMap.enableRandomWrite = true;     // 纹理在创建时启用 UAV
            Graphics.Blit(weightMaps[weightMapIndex], weightMap);
            int texWidth = weightMap.width;
            int texHeight = weightMap.height;

            // 设置 Compute Shader 参数
            brushComputeShader.SetTexture(0, "_WeightMap", weightMap);
            brushComputeShader.SetInt("_TexWidth", texWidth);
            brushComputeShader.SetInt("_TexHeight", texHeight);
            brushComputeShader.SetFloat("_BrushSize", brushSize * brushScale);
            brushComputeShader.SetFloat("_BrushStrength", brushStrength);
            brushComputeShader.SetInt("_WeightMapChannel", weightMapChannel);
            brushComputeShader.SetVector("_UV", new Vector4(uv.x, uv.y, 0, 0));

            // 计算线程组
            int threadGroupX = Mathf.CeilToInt(texWidth / 8.0f);
            int threadGroupY = Mathf.CeilToInt(texHeight / 8.0f);
            brushComputeShader.Dispatch(0, threadGroupX, threadGroupY, 1);
            
            // 读取 RenderTexture 回 Texture2D
            AsyncGPUReadback.Request(weightMap, 0, TextureFormat.ARGB32, request =>
            {
                if (request.hasError)
                {
                    Debug.LogError("GPU Readback 失败");
                    return;
                }

                // 更新 Texture2D
                weightTexture2D.SetPixelData(request.GetData<byte>(), 0);
                weightTexture2D.Apply();
            });

            // 释放 RenderTexture
            weightMap.Release();
        }
        
        public void InitializeRT()
        {
            Texture2D sourceTexture = weightMaps[weightMapIndex];
            int texWidth = sourceTexture.width;
            int texHeight = sourceTexture.height;
            
            // 新创建的Texture2D都需要线性
            savedWeightMap = new Texture2D(texWidth, texHeight, TextureFormat.RGBA32, false, true);

            // 创建透明的 paintRT
            paintRT = new RenderTexture(texWidth, texHeight, 0, RenderTextureFormat.ARGB32);
            paintRT.enableRandomWrite = true;
            paintRT.Create();
            
            // 暂存每帧混合的结果
            finalWeightRT = new RenderTexture(texWidth, texHeight, 0, RenderTextureFormat.ARGB32);
            finalWeightRT.enableRandomWrite = true;
            finalWeightRT.Create();
        }
        
        public void ClearRT()
        {
            // 释放内存
            DestroyImmediate(savedWeightMap);
            // 释放显存
            paintRT.Release();
            finalWeightRT.Release();
        }
        
        private void OnMouseDown()
        {
            if (weightMaps.Count == 0) return;
            if (savedWeightMap == null || paintRT == null || finalWeightRT == null) InitializeRT();

            // 备份当前 weightMap
            Texture2D sourceTexture = weightMaps[weightMapIndex];
            Graphics.CopyTexture(sourceTexture, savedWeightMap);

            // 初始化 paintRT 为透明
            RenderTexture activeRT = RenderTexture.active;
            RenderTexture.active = paintRT;
            GL.Clear(true, true, Color.clear);
            RenderTexture.active = activeRT;
        }
        
        private void OnMouseDrag(Vector2 uv)
        {
            if (weightMaps.Count == 0) return;
            
            int texWidth = paintRT.width;
            int texHeight = paintRT.height;
            int threadGroupX = Mathf.CeilToInt(texWidth / 8.0f);
            int threadGroupY = Mathf.CeilToInt(texHeight / 8.0f);
            
            // ================ 绘制到 paintRT ================ 
            int paintKernel = brushComputeShader.FindKernel("DrawPaintRT");
            
            brushComputeShader.SetTexture(paintKernel, "_PaintRT", paintRT);
            brushComputeShader.SetInt("_TexWidth", texWidth);
            brushComputeShader.SetInt("_TexHeight", texHeight);
            brushComputeShader.SetFloat("_BrushSize", brushSize * brushScale);
            brushComputeShader.SetFloat("_BrushStrength", brushStrength);
            brushComputeShader.SetVector("_UV", new Vector4(uv.x, uv.y, 0, 0));

            brushComputeShader.Dispatch(paintKernel, threadGroupX, threadGroupY, 1);
            
            // ================  混合weightMap RT ================ 
            int blendKernel = brushComputeShader.FindKernel("BlendWeightMaps");

            brushComputeShader.SetTexture(blendKernel, "_SavedWeightMap", savedWeightMap);
            brushComputeShader.SetTexture(blendKernel, "_PaintMap", paintRT);
            brushComputeShader.SetTexture(blendKernel, "_FinalWeightMap", finalWeightRT);
            brushComputeShader.SetInt("_WeightMapChannel", weightMapChannel);
            
            brushComputeShader.Dispatch(blendKernel, threadGroupX, threadGroupY, 1);

            // 读取回 Texture2D  TextureFormat.RGBA32!!
            AsyncGPUReadback.Request(finalWeightRT, 0, TextureFormat.RGBA32, request =>
            {
                if (request.hasError)
                {
                    Debug.LogError("GPU Readback 失败");
                    return;
                }
                weightMaps[weightMapIndex].SetPixelData(request.GetData<byte>(), 0);
                weightMaps[weightMapIndex].Apply();     // 将CPU 纹理中所做的更改复制到 GPU
            });
        }

        public void SaveTerrainTexturesToTexture2DArray()
        {
            string path = CONTROL_MAP_PATH + "Terrain_Albedo.asset";
            TextureArrayGenerator.CreateAndSaveTextureArray(terrainTextures, path);
        }
    }
}
