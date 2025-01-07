using System;
using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using UnityEngine.Profiling;
using System.IO;

public class MeshCutterEditor : EditorWindow
{
    private String rootPath = "Art/TerrainBake/";
    private String levelPath;
    private GameObject targetObject;
    // private int numSplits = 3;
    private float splitSize = 10.0f;
    
    private List<Mesh> subMeshes;
    private string terrainMeshPath;
    private Vector3 centerOffset;

    private int resolution = 512;
    private int resolutionSelectedIndex = 1;
    private static string[] resolutionOptions = new string[] { "256", "512", "1024" };
    private static int[] resolutionOptionsValue = new int[] { 256, 512, 1024};

    private List<GameObject> appliedObjects;

    private Material GL_Material;
    private List<Color> colors;
    private float GL_Alpha = 0.2f;

    private bool isBaked;

    private string _path
    {
        get => rootPath + levelPath + "/";
    }

    [MenuItem("Tools/Mesh Cutter")]
    public static void ShowWindow()
    {
        GetWindow<MeshCutterEditor>("Mesh Cutter");
    }
    
    private void OnEnable()
    {
        colors= new List<Color>()
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
        GL_Material = new Material(shader);
        GL_Material.hideFlags = HideFlags.HideAndDontSave;
            
        // Turn on alpha blending
        GL_Material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
        GL_Material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
        // Turn on add blending
        // GL_Material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
        // GL_Material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.One);
        // Turn backface culling off
        GL_Material.SetInt("_Cull", (int)UnityEngine.Rendering.CullMode.Off);
        // Turn off depth writes
        GL_Material.SetInt("_ZWrite", 0);
        GL_Material.SetInt("_ZTest", 0);
        
        isBaked = false;
    }

    private HashSet<Action<SceneView>> _hash = new();
    private void OnGUI()
    {
        rootPath = EditorGUILayout.TextField("根目录", rootPath);
        levelPath = EditorGUILayout.TextField("关卡名", levelPath);
        targetObject = (GameObject)EditorGUILayout.ObjectField("Target Object", targetObject, typeof(GameObject), true);
        // numSplits = EditorGUILayout.IntField("Number of Splits", numSplits);
        splitSize = EditorGUILayout.FloatField("切割的尺寸", splitSize);
        centerOffset = EditorGUILayout.Vector3Field("中心偏移", centerOffset);
        
        
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
        GL_Alpha = EditorGUILayout.FloatField("预览半透明", GL_Alpha);
        
        if (GUILayout.Button("切分模型"))
        {
            ExecuteMeshSplit();
        }
        
        if (GUILayout.Button("应用切割好的模型"))
        {
            // TODO 烘焙好的模型，应用的方法需要修改
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

        resolutionSelectedIndex = EditorGUILayout.Popup("烘焙贴图分辨率", resolutionSelectedIndex, resolutionOptions);
        resolution = resolutionOptionsValue[resolutionSelectedIndex];
        
        if (GUILayout.Button("烘焙贴图并修改Mesh UV"))
        {
            BakeTerrainTexture();
        }
        
        if (GUILayout.Button("一键切割并烘焙"))
        {
            ClearMeshSplit();
            ExecuteMeshSplit();
            ApplyMeshSplit();
            BakeTerrainTexture();
        }
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
        bool isApplied = false;
        if (appliedObjects != null)
        {
            if (appliedObjects.Count > 0)
            {
                isApplied = true;
                ReductionMeshSplit();
            }
        }

        subMeshes = new List<Mesh> { };
        MeshCutterUtility.DeleteAssetsInDirectory(_path);

        MeshCutterUtility.SplitMeshToGrid(targetObject, originalMesh, ref subMeshes, splitSize, centerOffset);

        MeshCutterUtility.SaveMeshs(ref subMeshes, _path);

        if (isApplied)
        {
            ApplyMeshSplit();
            isApplied = false;
        }

        Debug.Log("模型切割完成!");
    }

    private void ApplyMeshSplit()
    {
        if (subMeshes == null)
        {
            Debug.LogError("请先切分模型");
            return;
        }
        else if (subMeshes.Count == 0)
        {
            Debug.LogError("请先切分模型");
            return;
        }
        if (appliedObjects != null)
        {
            if (appliedObjects.Count > 0)
                ReductionMeshSplit();
        }
        MeshCutterUtility.CreatNewObjects(targetObject, ref subMeshes, out appliedObjects, _path, isBaked);
        targetObject.SetActive(false);
    }
    
    private void ReductionMeshSplit()
    {
        targetObject.SetActive(true);
        if (appliedObjects == null)
        {
            return;
        }
        foreach (var obj in appliedObjects)
        {
            DestroyImmediate(obj);
        }
        appliedObjects.Clear();
    }

    private void ClearMeshSplit()
    {
        ReductionMeshSplit();
        subMeshes.Clear();
        MeshCutterUtility.DeleteAssetsInDirectory(_path);
        isBaked = false;
    }
    
    // 重新映射UV，并把Mesh的UV修改
    public void UV_Remapping(Mesh mesh, out float maxLength, out Vector2 newO)
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
        if (subMeshes == null || appliedObjects == null)
        {
            Debug.LogError("请先切分模型");
            return;
        }
        else if (subMeshes.Count == 0)
        {
            Debug.LogError("请先切分模型");
            return;
        }

        Material terrainMaterial = targetObject.GetComponent<MeshRenderer>().sharedMaterial;

        for (int i = 0; i < appliedObjects.Count; i++)
        {
            var obj = appliedObjects[i];
            var mesh = subMeshes[i];
            float maxLength;
            Vector2 newO;
            // TODO 记录UV的修改，创建一个类单独记录Mesh Objects UV偏移 组件的信息
            UV_Remapping(mesh, out maxLength, out newO);
            // TODO 烘焙颜色和法线贴图
            TerrainBakeMaterialGen(obj, terrainMaterial, newO, maxLength, resolution, _path);
            
            terrainMaterial.SetVector("_BaseMap_ST", new Vector4(1, 1, 0, 0));
        }

        isBaked = true;
    }
    
    static void TerrainBakeMaterialGen(GameObject terrain, Material bakeMat, Vector2 newO, float l, int size, string path)
    {
        // 创建临时RT存储贴图数据
        RenderTexture renderTexture = new RenderTexture(size, size, 0);
        renderTexture.filterMode = FilterMode.Bilinear;
        renderTexture.useMipMap = false;

        // 修改烘焙的材质的UV Tiling
        bakeMat.SetVector("_BaseMap_ST", new Vector4(l, l, newO.x, newO.y));
        Graphics.Blit(null, renderTexture, bakeMat, 0);

        // 创建PNG数据，存储RT的信息，再保存为贴图资产
        Texture2D png = new Texture2D(renderTexture.width, renderTexture.height, TextureFormat.ARGB32, false);
        png.ReadPixels(new Rect(0, 0, renderTexture.width, renderTexture.height), 0, 0);

        byte[] bytes = png.EncodeToPNG();

        // File.WriteAllBytes(Application.dataPath + $"/{path.Remove(0, "Assets".Length)}{terrain.name}.png", bytes);
        File.WriteAllBytes(Application.dataPath + $"/{path}{terrain.name}.png", bytes);

        AssetDatabase.Refresh();
        
        // 修改贴图的采样方式
        path = $"Assets/{path}";
        TextureImporter textureImporter = AssetImporter.GetAtPath($"{path}{terrain.name}.png") as TextureImporter;
        textureImporter.wrapMode = TextureWrapMode.Clamp;
        textureImporter.SaveAndReimport();

        AssetDatabase.Refresh();

        // 创建新的材质球，并赋予刚才的贴图
        Material finalMat = new Material(Shader.Find("KIIF/PBR_Base"));

        finalMat.SetFloat("_Smoothness", 0);
        finalMat.SetColor("_BaseColor", bakeMat.GetColor("_BaseColor"));

        finalMat.mainTexture = AssetDatabase.LoadAssetAtPath<Texture2D>($"{path}{terrain.name}.png");

        AssetDatabase.CreateAsset(finalMat, $"{path}{terrain.name}.mat");

        terrain.GetComponent<MeshRenderer>().sharedMaterial =
            AssetDatabase.LoadAssetAtPath<Material>($"{path}{terrain.name}.mat");

        //清理PNG数据
        Texture2D.DestroyImmediate(png);
        png = null;
    }

    private void OnSceneGUI(SceneView sceneView)
    {
        // 设置材质
        GL_Material.SetPass(0);
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
                int i = (x + z*2) % colors.Count;
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
        color.a = GL_Alpha;
        GL.Color(color);
        GL.Vertex(v0);
        GL.Vertex(v1);
        GL.Vertex(v2);
        GL.Vertex(v3);
    }
}
