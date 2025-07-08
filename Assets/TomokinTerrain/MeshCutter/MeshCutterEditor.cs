using System;
using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;

namespace Tomokin
{
    public class MeshCutterEditor : EditorWindow
    {
        private string rootPath = "Art/TerrainBake/";
        private string levelPath;
        private GameObject targetObject;
        // private int numSplits = 3;
        private float splitSize = 10.0f;

        // private List<Mesh> subMeshes;
        private string terrainMeshPath;
        private Vector3 centerOffset;

        private int resolution = 512;
        private int resolutionSelectedIndex = 1;
        private static string[] resolutionOptions = new string[] { "256", "512", "1024" };
        private static int[] resolutionOptionsValue = new int[] { 256, 512, 1024 };

        private static ShaderStyle selectedShaderStyle = ShaderStyle.StyleTerrain;
        private enum ShaderStyle
        {
            Style16M,       // "16M"
            StyleTerrain    // "Terrain"
        }

        // private List<GameObject> appliedObjects;

        private Material materialGL;
        private List<Color> colors;
        private float alphaGL = 0.2f;

        private bool isBaked;
        private bool bakeNormal;
        private bool bakeMask;

        private string _path
        {
            get => rootPath + levelPath + "/";
        }

        private string oldPath;
        
        private List<SubmeshInfo> _submeshInfos;
        class SubmeshInfo
        {
            public Mesh mesh;
            public GameObject gameObject;
            public Vector2 newO;
            public float maxLength;

            public SubmeshInfo(Mesh mesh)
            {
                this.mesh = mesh;
                this.gameObject = null;
                this.newO = Vector2.zero;
                this.maxLength = 0f;
            }
            public SubmeshInfo(Mesh mesh, GameObject meshObject)
            {
                this.mesh = mesh;
                this.gameObject = meshObject;
                this.newO = Vector2.zero;
                this.maxLength = 0f;
            }
        }

        [MenuItem("Tools/地形切割工具")]
        public static void ShowWindow()
        {
            GetWindow<MeshCutterEditor>("地形切割工具");
        }

        private void OnEnable()
        {
            colors = new List<Color>()
            {
                new Color(1f,0.6f,0.6f,0.5f),
                new Color(0.6f,1f,0.6f,0.5f),
                new Color(0.6f,0.6f,1f,0.5f),
                new Color(0.6f,1f,1f,0.5f),
                new Color(1f,1f,0.6f,0.5f),
                new Color(1f,0.6f,1f,0.5f),
                new Color(0.6f,0.6f,0.6f,0.5f)
            };
            // 使用内置的材质
            Shader shader = Shader.Find("Hidden/Internal-Colored");
            // Unity has a built-in shader that is useful for drawing
            // simple colored things.
            materialGL = new Material(shader);
            materialGL.hideFlags = HideFlags.HideAndDontSave;

            // Turn on alpha blending
            materialGL.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
            materialGL.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            // Turn on add blending
            // materialGL.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
            // materialGL.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.One);
            // Turn backface culling off
            materialGL.SetInt("_Cull", (int)UnityEngine.Rendering.CullMode.Off);
            // Turn off depth writes
            materialGL.SetInt("_ZWrite", 0);
            materialGL.SetInt("_ZTest", 0);

            isBaked = false;
            _submeshInfos = new List<SubmeshInfo>();
        }

        private HashSet<Action<SceneView>> _hash = new();
        private void OnGUI()
        {
            // ================================================================
            EditorGUILayout.BeginVertical("box");
            GUILayout.Label("基本设置", EditorStyles.boldLabel);
            rootPath = EditorGUILayout.TextField("根目录", rootPath);
            levelPath = EditorGUILayout.TextField("关卡名", levelPath);
            targetObject = (GameObject)EditorGUILayout.ObjectField("切割的模型", targetObject, typeof(GameObject), true);
            // numSplits = EditorGUILayout.IntField("Number of Splits", numSplits);
            EditorGUILayout.EndVertical();

            GUILayout.Space(10);
            GUILayout.Box("", GUILayout.ExpandWidth(true), GUILayout.Height(2));
            GUILayout.Space(10);
            // ================================================================
            EditorGUILayout.BeginVertical("box");
            GUILayout.Label("模型切割", EditorStyles.boldLabel);
            splitSize = EditorGUILayout.FloatField("切割的尺寸", splitSize);
            centerOffset = EditorGUILayout.Vector3Field("中心偏移", centerOffset);

            if (targetObject == null)
            {
                Debug.LogWarning("请添加需要切割模型");
                if (_hash.Contains(OnSceneGUI))
                {
                    _hash.Remove(OnSceneGUI);
                    SceneView.duringSceneGui -= OnSceneGUI;
                    SceneView.RepaintAll();
                }
            }

            if (GUILayout.Button("绘制预览") && !_hash.Contains(OnSceneGUI))
            {
                _hash.Add(OnSceneGUI);
                SceneView.duringSceneGui += OnSceneGUI;
                SceneView.RepaintAll();
            }

            if (GUILayout.Button("清除预览") && _hash.Contains(OnSceneGUI))
            {
                _hash.Remove(OnSceneGUI);
                SceneView.duringSceneGui -= OnSceneGUI;
                SceneView.RepaintAll();
            }
            alphaGL = EditorGUILayout.FloatField("预览半透明", alphaGL);

            if (GUILayout.Button("切分模型"))
            {
                if (_path != oldPath)
                {
                    _submeshInfos.Clear();
                }
                ExecuteMeshSplit();
            }
            EditorGUILayout.EndVertical();

            GUILayout.Space(10);
            GUILayout.Box("", GUILayout.ExpandWidth(true), GUILayout.Height(2));
            GUILayout.Space(10);
            // ================================================================
            EditorGUILayout.BeginVertical("box");
            GUILayout.Label("切割数据", EditorStyles.boldLabel);

            if (GUILayout.Button("应用切割好的模型"))
            {
                ApplyMeshSplit();
            }

            if (GUILayout.Button("还原切割"))
            {
                ReductionMeshSplit();
            }

            if (GUILayout.Button("清除切割数据和保存的Mesh"))
            {
                ClearMeshSplit();
            }

            if (GUILayout.Button("获取已分割好的Mesh"))
            {
                _submeshInfos.Clear();
                GetSubMeshFromScene();
            }
            EditorGUILayout.EndVertical();

            GUILayout.Space(10);
            GUILayout.Box("", GUILayout.ExpandWidth(true), GUILayout.Height(2));
            GUILayout.Space(10);
            // ================================================================
            EditorGUILayout.BeginVertical("box");
            GUILayout.Label("烘焙纹理", EditorStyles.boldLabel);

            resolutionSelectedIndex = EditorGUILayout.Popup("烘焙贴图分辨率", resolutionSelectedIndex, resolutionOptions);
            resolution = resolutionOptionsValue[resolutionSelectedIndex];

            selectedShaderStyle  = (ShaderStyle)EditorGUILayout.EnumPopup("选择 Shader 类型", selectedShaderStyle);
            
            // 在按钮上方添加一排复选框
            EditorGUILayout.BeginHorizontal();

            bakeNormal = GUILayout.Toggle(bakeNormal, "烘焙法线", GUILayout.Width(100));
            bakeMask = GUILayout.Toggle(bakeMask, "烘焙光滑金属", GUILayout.Width(100));

            EditorGUILayout.EndHorizontal();

            if (GUILayout.Button("烘焙贴图并修改Mesh UV"))
            {
                BakeTerrainTexture();
            }

            if (GUILayout.Button("平滑Mesh法线"))
            {
                SmoothMeshNormal();
            }
            
            if (GUILayout.Button("一键切割并烘焙"))
            {
                ClearMeshSplit();
                ExecuteMeshSplit();
                ApplyMeshSplit();
                BakeTerrainTexture();
            }
            EditorGUILayout.EndVertical();
        }

        private void ExecuteMeshSplit()
        {
            if (targetObject == null)
            {
                Debug.LogError("No target object selected!");
                return;
            }

            MeshFilter meshFilter = targetObject.GetComponent<MeshFilter>();
            if (meshFilter == null)
            {
                Debug.LogError("Target object does not have a MeshFilter component!");
                return;
            }

            // Get the original mesh
            Mesh originalMesh = meshFilter.sharedMesh;
            if (originalMesh == null)
            {
                Debug.LogError("No mesh found on the target object!");
                return;
            }
            // 如果模型已经应用，重新切割需要把应用的模型先删掉再重新应用
            bool isApplied = _submeshInfos.Count > 0 && _submeshInfos[0].gameObject != null;

            if(oldPath == _path) ClearMeshSplit();
            List<Mesh> meshList = new List<Mesh>();
            _submeshInfos = new List<SubmeshInfo>();

            MeshCutterUtility.SplitMeshToGrid(targetObject, originalMesh, ref meshList, splitSize, centerOffset);

            MeshCutterUtility.SaveMeshs(ref meshList, _path);
            oldPath = _path;

            foreach (var mesh in meshList)
            {
                _submeshInfos.Add(new SubmeshInfo(mesh));
            }

            if (isApplied)
            {
                ApplyMeshSplit();
            }

            Debug.Log("模型切割完成!");
        }

        private void ApplyMeshSplit()
        {
            if (_submeshInfos.Count == 0)
            {
                Debug.LogError("请先切分模型");
                return;
            }
            if (_submeshInfos[0].gameObject != null)
            {
                ReductionMeshSplit();
            }

            List<Mesh> meshList =
                _submeshInfos.FindAll(submesh => submesh.mesh != null).ConvertAll(submesh => submesh.mesh);
            List<GameObject> objectList;
            MeshCutterUtility.CreatNewObjects(targetObject, ref meshList, out objectList, _path, isBaked);
            for (int i = 0; i < _submeshInfos.Count; i++)
            {
                _submeshInfos[i].gameObject = objectList[i];
            }
            targetObject.SetActive(false);
        }

        private void ReductionMeshSplit()
        {
            targetObject.SetActive(true);
            if (_submeshInfos.Count <= 0 || _submeshInfos[0].gameObject == null)
            {
                return;
            }
            foreach (var submeshInfo in _submeshInfos)
            {
                DestroyImmediate(submeshInfo.gameObject);
            }
        }

        private void ClearMeshSplit()
        {
            ReductionMeshSplit();
            _submeshInfos.Clear();
            MeshCutterUtility.DeleteAssetsInDirectory(_path);
            isBaked = false;
        }

        private void GetSubMeshFromScene()
        {
            if (Selection.activeGameObject == null)
            {
                if (targetObject == null)
                {
                    Debug.LogWarning("请先选中一个 GameObject！");
                    return;
                }
            }
            else
            {
                targetObject = Selection.activeGameObject;
            }

            _submeshInfos = new List<SubmeshInfo>();
            // Transform parent = targetObject.transform;
            // 创建新的对象存储修改后的地形
            // targetObject = Instantiate(targetObject, targetObject.transform.position, targetObject.transform.rotation);
            // FindMeshes(parent);

            FindMeshes(targetObject.transform);
        }

        private void FindMeshes(Transform parent)
        {
            List<Mesh> meshList = new List<Mesh>();
            bool hasAdded = false;
            foreach (Transform child in parent)
            {
                MeshFilter meshFilter = child.GetComponent<MeshFilter>();

                // 给父级添加材质
                MeshRenderer meshRenderer = child.GetComponent<MeshRenderer>();
                if (meshRenderer != null && !hasAdded)
                {
                    MeshRenderer targetRenderer = targetObject.GetComponent<MeshRenderer>();
                    if (targetRenderer == null)
                    {
                        targetRenderer = targetObject.AddComponent<MeshRenderer>();
                    }
                    targetRenderer.sharedMaterials = meshRenderer.sharedMaterials;
                    hasAdded = true;
                }

                string path = $"Assets/{_path}";

                // 确保路径存在
                if (!Directory.Exists(path))
                {
                    Directory.CreateDirectory(path);
                }

                // 保存mesh到目标路径
                if (meshFilter != null && meshFilter.sharedMesh != null)
                {
                    Mesh originalMesh = meshFilter.sharedMesh;
                    string meshPath = Path.Combine(path, originalMesh.name + ".asset");
                    Mesh newMesh = AssetDatabase.LoadAssetAtPath<Mesh>(meshPath);
                    if (newMesh == null)
                    {
                        newMesh = Instantiate(originalMesh);
                        newMesh.name = originalMesh.name;
                        AssetDatabase.CreateAsset(newMesh, meshPath);
                        AssetDatabase.SaveAssets();
                        // Debug.Log($"[Mesh 复制完成] {meshPath}");
                    }
                    // 给子Mesh创建新对象
                    // GameObject _newObject = Instantiate(child.gameObject, child.position, child.rotation);
                    // _newObject.transform.SetParent(parent);
                    meshList.Add(newMesh);
                    _submeshInfos.Add(new SubmeshInfo(newMesh, child.gameObject));
                    meshFilter.sharedMesh = newMesh;

                    // // 复制材质并保存
                    // if (meshRenderer != null && meshRenderer.sharedMaterial != null)
                    // {
                    //     Material originalMat = meshRenderer.sharedMaterial;
                    //
                    //     string matPath = Path.Combine(path, child.name + ".mat");
                    //     Material newMat = AssetDatabase.LoadAssetAtPath<Material>(matPath);
                    //     if (newMat == null)
                    //     {
                    //         newMat = new Material(originalMat);
                    //         newMat.name = child.name;
                    //         AssetDatabase.CreateAsset(newMat, matPath);
                    //         AssetDatabase.SaveAssets();
                    //     }
                    //     // 赋值新材质
                    //     meshRenderer.sharedMaterial = newMat;
                    //
                    //     Debug.Log($"[材质已创建] {matPath}");
                    // }
                    // else
                    // {
                    //     Debug.LogWarning($"[No Material] {child.name} 没有 Material");
                    // }
                }
                else
                {
                    Debug.LogWarning($"[No Mesh] {child.name} 没有 Mesh");
                }
            }
        }

        // 重新映射UV，并把Mesh的UV修改
        public void UVRemapping(Mesh mesh, out float maxLength, out Vector2 newO)
        {
            float minX = float.MaxValue;
            float minY = float.MaxValue;
            float maxX = float.MinValue;
            float maxY = float.MinValue;

            foreach (var uv in mesh.uv)
            {
                minX = Mathf.Min(uv.x, minX);
                minY = Mathf.Min(uv.y, minY);
                maxX = Mathf.Max(uv.x, maxX);
                maxY = Mathf.Max(uv.y, maxY);
            }

            float w = maxX - minX;
            float h = maxY - minY;

            maxLength = Mathf.Max(w, h);

            newO = new Vector2(minX, minY);

            // 更新UV数据
            Vector2[] newUVs = new Vector2[mesh.uv.Length];

            for (int i = 0; i < newUVs.Length; i++)
            {
                Vector2 oriUV = mesh.uv[i];
                Vector2 newUV = (oriUV - newO) / maxLength;

                newUVs[i] = newUV;
            }

            mesh.uv = newUVs;
        }

        private void BakeTerrainTexture()
        {
            if (_submeshInfos.Count <= 0)
            {
                Debug.LogError("请先切分模型");
                return;
            }

            Material terrainMaterial = targetObject.GetComponent<MeshRenderer>().sharedMaterial;

            for (int i = 0; i < _submeshInfos.Count; i++)
            {
                var obj = _submeshInfos[i].gameObject;
                var mesh = _submeshInfos[i].mesh;
                float maxLength;
                Vector2 newO;
                if (_submeshInfos[i].maxLength == 0)
                    UVRemapping(mesh, out _submeshInfos[i].maxLength, out _submeshInfos[i].newO);
                
                TerrainBakeMaterialGen(_submeshInfos[i], terrainMaterial, resolution, _path, bakeNormal, bakeMask);
            }

            isBaked = true;
        }
        
        private void SmoothMeshNormal()
        {
            if (_submeshInfos.Count <= 0)
            {
                Debug.LogError("没有切割的模型数据");
                return;
            }
            
            for (int i = 0; i < _submeshInfos.Count; i++)
            {
                var obj = _submeshInfos[i].gameObject;
                var mesh = _submeshInfos[i].mesh;
                if (mesh == null) continue;

                MeshNormalSmooth.SmoothNormals(mesh);

                Debug.Log($"[{obj.name}] 平滑法线完成（使用工具类）");
            }
        }

        static void TerrainBakeMaterialGen(SubmeshInfo sub, Material bakeMat, int size, string path, bool bakeNormal = true, bool bakeMask = true)
        {
            TerrainBakeMaterialGen(sub.gameObject, bakeMat, sub.newO, sub.maxLength, size, path, bakeNormal, bakeMask);
        }

        static void TerrainBakeMaterialGen(GameObject terrain, Material bakeMat, Vector2 newO, float l, int size, string path, bool bakeNormal, bool bakeMask)
        {
            // 创建临时RT存储贴图数据
            RenderTexture renderTexture = new RenderTexture(size, size, 0);
            renderTexture.filterMode = FilterMode.Bilinear;
            renderTexture.useMipMap = false;
            
            RenderTexture normalRT = new RenderTexture(size, size, 0, RenderTextureFormat.ARGB32);
            normalRT.filterMode = FilterMode.Bilinear;
            normalRT.useMipMap = false;
            
            RenderTexture maskRT = new RenderTexture(size, size, 0, RenderTextureFormat.RG32);
            // maskRT.filterMode = FilterMode.Bilinear;
            // maskRT.useMipMap = false;

            // 修改烘焙的材质的UV Tiling
            switch (selectedShaderStyle)
            {
                case ShaderStyle.Style16M:
                    bakeMat.SetVector("_BakeTilling", new Vector4(l, l, newO.x, newO.y));    // Shader 16M
                    Graphics.Blit(null, renderTexture, bakeMat, 1); // Shader Base=0  Shader 16M=1
                    break;
                case ShaderStyle.StyleTerrain:
                    bakeMat.SetVector("_BaseMap_ST", new Vector4(l, l, newO.x, newO.y));    // Shader Base
                    
                    bakeMat.EnableKeyword("_BAKEMODECOLOR");
                    Graphics.Blit(null, renderTexture, bakeMat, 0); // Shader Base=0  Shader 16M=1
                    bakeMat.DisableKeyword("_BAKEMODECOLOR");
                    
                    bakeMat.EnableKeyword("_BAKEMODENORMAL");
                    Graphics.Blit(null, normalRT, bakeMat, 0); // Shader Base=0  Shader 16M=1
                    bakeMat.DisableKeyword("_BAKEMODENORMAL");
                    
                    bakeMat.EnableKeyword("_BAKEMODEMASK");
                    Graphics.Blit(null, maskRT, bakeMat, 0); // Shader Base=0  Shader 16M=1
                    bakeMat.DisableKeyword("_BAKEMODEMASK");
                    break;
                default:
                    Debug.LogWarning("未知的烘焙Shader:{selectedShader}");
                    throw new System.ArgumentOutOfRangeException(nameof(selectedShaderStyle), selectedShaderStyle,
                        "烘焙模式不在预期范围内");
            }

            // 创建PNG数据，存储RT的信息，再保存为贴图资产
            RenderTexture.active = renderTexture;
            string colorMapPath = $"/{path}T_{terrain.name}_D.png";
            Texture2D pngColor = new Texture2D(size, size, TextureFormat.ARGB32, false);
            pngColor.ReadPixels(new Rect(0, 0, size, size), 0, 0);
            // File.WriteAllBytes(Application.dataPath + $"/{path.Remove(0, "Assets".Length)}{terrain.name}.png", bytes);
            File.WriteAllBytes(Application.dataPath + colorMapPath, pngColor.EncodeToPNG());
            
            RenderTexture.active = normalRT;
            string normalMapPath = $"/{path}T_{terrain.name}_N.png";
            if (bakeNormal)
            {
                Texture2D pngNormal = new Texture2D(size, size, TextureFormat.ARGB32, false);
                pngNormal.ReadPixels(new Rect(0, 0, size, size), 0, 0);
                // File.WriteAllBytes(Application.dataPath + $"/{path.Remove(0, "Assets".Length)}{terrain.name}.png", bytes);
                File.WriteAllBytes(Application.dataPath + normalMapPath, pngNormal.EncodeToPNG());
            }

            RenderTexture.active = maskRT;
            string maskMapPath = $"/{path}T_{terrain.name}_SM.png";
            if (bakeMask)
            {
                Texture2D pngMask = new Texture2D(size, size, TextureFormat.ARGB32, false);
                pngMask.ReadPixels(new Rect(0, 0, size, size), 0, 0);
                // File.WriteAllBytes(Application.dataPath + $"/{path.Remove(0, "Assets".Length)}{terrain.name}.png", bytes);
                File.WriteAllBytes(Application.dataPath + maskMapPath, pngMask.EncodeToPNG());
            }

            AssetDatabase.Refresh();

            // 修改贴图的采样方式
            colorMapPath = $"Assets/{colorMapPath}";
            normalMapPath = $"Assets/{normalMapPath}";
            maskMapPath = $"Assets/{maskMapPath}";
            path = $"Assets/{path}";
            
            TextureImporter textureImporter = AssetImporter.GetAtPath(colorMapPath) as TextureImporter;
            textureImporter.wrapMode = TextureWrapMode.Clamp;
            textureImporter.SaveAndReimport();

            if (bakeNormal)
            {
                textureImporter = AssetImporter.GetAtPath(normalMapPath) as TextureImporter;
                textureImporter.textureType = TextureImporterType.NormalMap;
                textureImporter.wrapMode = TextureWrapMode.Clamp;
                textureImporter.sRGBTexture = false;
                textureImporter.SaveAndReimport();
            }

            if (bakeMask)
            {
                textureImporter = AssetImporter.GetAtPath(maskMapPath) as TextureImporter;
                textureImporter.wrapMode = TextureWrapMode.Clamp;
                textureImporter.sRGBTexture = false;
                textureImporter.SaveAndReimport();
            }

            AssetDatabase.Refresh();

            // 创建新的材质球，并赋予刚才的贴图
            Material finalMat = new Material(Shader.Find("KIIF/PBR_Base"));

            switch (selectedShaderStyle)
            {
                case ShaderStyle.Style16M:
                    finalMat.SetColor("_BaseColor", bakeMat.GetColor("_ColorAll"));        // Shader 16M
                    bakeMat.SetVector("_BakeTilling", new Vector4(1, 1, 0, 0));         // Shader 16M
                    break;
                case ShaderStyle.StyleTerrain:
                    finalMat.SetColor("_BaseColor",
                        bakeMat.HasProperty("_BaseColor") ? bakeMat.GetColor("_BaseColor") : Color.white);       // Shader Base
                    bakeMat.SetVector("_BaseMap_ST", new Vector4(1, 1, 0, 0));          // Shader Base
                    break;
            }

            finalMat.SetFloat("_Smoothness", 0);
            finalMat.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>(colorMapPath);
            if(bakeNormal) finalMat.SetTexture("_BumpMap",AssetDatabase.LoadAssetAtPath<Texture2D>(normalMapPath));
            if (bakeMask) finalMat.SetTexture("_SMAEMap", AssetDatabase.LoadAssetAtPath<Texture2D>(maskMapPath));

            AssetDatabase.CreateAsset(finalMat, $"{path}{terrain.name}.mat");

            terrain.GetComponent<MeshRenderer>().sharedMaterial =
                AssetDatabase.LoadAssetAtPath<Material>($"{path}{terrain.name}.mat");

            //清理PNG数据
            Texture2D.DestroyImmediate(pngColor);
            // Texture2D.DestroyImmediate(pngNormal);
            // Texture2D.DestroyImmediate(pngMask);
        }

        private void OnSceneGUI(SceneView sceneView)
        {
            // 设置材质
            materialGL.SetPass(0);
            // 开始绘制
            GL.PushMatrix();
            GL.MultMatrix(Handles.matrix);
            Matrix4x4 transformMatrix = targetObject.transform.localToWorldMatrix;
            GL.MultMatrix(transformMatrix);
            GL.Begin(GL.QUADS);

            Mesh ogMesh = targetObject.GetComponent<MeshFilter>().sharedMesh;

            Vector3 meshSize = ogMesh.bounds.size;
            Vector3 meshCenter = ogMesh.bounds.center + centerOffset;

            int numSplitesX = Mathf.CeilToInt(meshSize.x / splitSize);
            int numSplitesZ = Mathf.CeilToInt(meshSize.z / splitSize);
            float minX = meshCenter.x - (meshSize.x / 2);
            float minZ = meshCenter.z - (meshSize.z / 2);
            // float maxX = meshCenter.x + (meshSize.x / 2);
            // float maxZ = meshCenter.z + (meshSize.z / 2);

            // 设置原点的Quad的顶点位置
            Vector3 v0, v1, v2, v3;
            v0 = new Vector3(minX, 0, minZ);
            v1 = new Vector3(minX + splitSize, 0, minZ);
            v2 = new Vector3(minX + splitSize, 0, minZ + splitSize);
            v3 = new Vector3(minX, 0, minZ + splitSize);

            // 把Quad偏移并绘制
            for (int x = 0; x < numSplitesX; x++)
            {
                for (int z = 0; z < numSplitesZ; z++)
                {
                    // Debug.Log("X = " + x + "  Z= " + z);
                    int i = (x + z * 2) % colors.Count;
                    float offsetX = x * splitSize;
                    float offsetZ = z * splitSize;
                    Vector3 offset = new Vector3(offsetX, 0, offsetZ);
                    DrawQuad(v0 + offset,
                             v1 + offset,
                             v2 + offset,
                             v3 + offset,
                             colors[i]);
                }
            }

            GL.End();
            GL.PopMatrix();

            // 确保 Scene 视图刷新
            sceneView.Repaint();
        }

        private void DrawQuad(Vector3 v0, Vector3 v1, Vector3 v2, Vector3 v3, Color color)
        {
            color.a = alphaGL;
            GL.Color(color);
            GL.Vertex(v0);
            GL.Vertex(v1);
            GL.Vertex(v2);
            GL.Vertex(v3);
        }
    }
}


