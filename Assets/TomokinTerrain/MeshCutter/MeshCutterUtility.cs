using UnityEngine;
using System.Collections.Generic;
using UnityEditor;
using System.IO;
using System.Linq;

namespace Tomokin
{
    public class MeshCutterUtility
    {
        private static MeshCutter meshCutter;
        private static GameObject targetObject;

        private static List<GameObject> baseObjects;

        public static void SplitMeshToGrid(GameObject ogObject, Mesh originalMesh, ref List<Mesh> subMeshes,
            float splitSize, Vector3 splitOffset = new())
        {
            targetObject = ogObject;
            Vector3 meshSize = originalMesh.bounds.size;
            Vector3 meshCenter = originalMesh.bounds.center + splitOffset;

            // 从X轴的负方向向正方向切割多次
            int numSplitesX = Mathf.CeilToInt(meshSize.x / splitSize);
            float minX = meshCenter.x - (meshSize.x / 2);
            Mesh tempMesh = new Mesh();
            CopyMesh(tempMesh, originalMesh);
            List<Mesh> subMeshes_X = new List<Mesh> { };
            // 多切割一次，把最后一个Mesh生成新Mesh资产
            for (int i = 1; i <= numSplitesX; i++)
            {
                float slicePosition = minX + (i * splitSize);
                // Debug.Log("切割X位置:"+ slicePosition);
                Plane slicePlane = new Plane(Vector3.right, new Vector3(slicePosition, 0, 0));
                SliceMeshToTwoParts(ref tempMesh, slicePlane, i, ref subMeshes_X);
            }

            // 从Z轴的负方向向正方向切割多次
            foreach (Mesh m in subMeshes_X)
            {
                // Vector3 mSize = m.bounds.size;
                // Vector3 mCenter = m.bounds.center;
                int numSplitesZ = Mathf.CeilToInt(meshSize.z / splitSize);
                float minZ = meshCenter.z - (meshSize.z / 2);
                Mesh tMesh = m;
                for (int i = 1; i <= numSplitesZ; i++)
                {
                    float slicePosition = minZ + (i * splitSize);
                    // Debug.Log("切割Z位置:"+ slicePosition);
                    Plane slicePlane = new Plane(Vector3.forward, new Vector3(0, 0, slicePosition));
                    SliceMeshToTwoParts(ref tMesh, slicePlane, i, ref subMeshes);
                }
            }
        }

        private static void SliceMeshToTwoParts(ref Mesh mesh, Plane slicePlane, int iteration,
            ref List<Mesh> subMeshes)
        {
            // Debug.Log(mesh.name + "  i=" + iteration);
            if (!(mesh.vertices.Length > 0))
                return;
            meshCutter = new MeshCutter(8192);
            // 切割后，并没有生成新Mesh的情况
            if (!meshCutter.SliceMesh(mesh, ref slicePlane))
            {
                // 如果Plane的正方向没有顶点
                if (slicePlane.GetDistanceToPoint(mesh.vertices[0]) < 0)
                {
                    Mesh copyMesh = new Mesh();
                    CopyMesh(copyMesh, mesh);
                    copyMesh.name = mesh.name + "_" + iteration.ToString("D2");
                    subMeshes.Add(copyMesh);
                    mesh.Clear();
                }

                return;
            }

            Mesh newmesh = new Mesh();
            newmesh.name = mesh.name + "_" + iteration.ToString("D2");
            // 把面片正面朝向的mesh作为原始的mesh，背面朝向的为新mesh
            ReplaceMesh(mesh, meshCutter.PositiveMesh);
            ReplaceMesh(newmesh, meshCutter.NegativeMesh);


            // // 存储Mesh
            // string path = $"Art/TerrainBake/";
            // SaveMesh(newmesh, path);
            //
            // // 创建新GameObject在场景中
            // GameObject newObject = new GameObject();
            // newObject.transform.SetPositionAndRotation(targetObject.transform.position, targetObject.transform.rotation);
            // MeshFilter newMeshFilter = newObject.AddComponent<MeshFilter>();
            // MeshRenderer newMeshRenderer = newObject.AddComponent<MeshRenderer>();
            // newMeshFilter.mesh = newmesh;
            // newMeshRenderer.material = targetObject.GetComponent<MeshRenderer>().sharedMaterial;


            subMeshes.Add(newmesh);
        }

        /// <summary>
        /// Replace the mesh with tempMesh.
        /// </summary>
        static void ReplaceMesh(Mesh mesh, TempMesh tempMesh, MeshCollider collider = null)
        {
            mesh.Clear();
            mesh.SetVertices(tempMesh.vertices);
            mesh.SetTriangles(tempMesh.triangles, 0);
            mesh.SetNormals(tempMesh.normals);
            mesh.SetUVs(0, tempMesh.uvs);

            //mesh.RecalculateNormals();
            mesh.RecalculateTangents();

            if (collider != null && collider.enabled)
            {
                collider.sharedMesh = mesh;
                collider.convex = true;
            }

            mesh.RecalculateBounds();
        }

        /// <summary>
        /// Copy the mesh with tempMesh.
        /// </summary>
        static void CopyMesh(Mesh mesh, Mesh tempMesh, MeshCollider collider = null)
        {
            mesh.Clear();
            mesh.name = tempMesh.name;
            mesh.SetVertices(tempMesh.vertices);
            mesh.SetTriangles(tempMesh.triangles, 0);
            mesh.SetNormals(tempMesh.normals);
            mesh.SetUVs(0, tempMesh.uv);

            //mesh.RecalculateNormals();
            mesh.RecalculateTangents();

            if (collider != null && collider.enabled)
            {
                collider.sharedMesh = mesh;
                collider.convex = true;
            }

            mesh.RecalculateBounds();
        }

        /// <summary>
        /// 存储Mesh资产到本地
        /// </summary>
        /// <param name="subMeshes"></param>
        /// <param name="path"></param>
        public static void SaveMeshs(ref List<Mesh> subMeshes, string path = "")
        {
            if (path == "")
                path = $"Art/TerrainBake/";
            
            if (!Directory.Exists(path))
            {
                Directory.CreateDirectory(path);
            }

            foreach (var sMesh in subMeshes)
            {
                SaveMesh(sMesh, path);
            }

            AssetDatabase.Refresh();
        }

        private static void SaveMesh(Mesh mesh, string path)
        {
            // 创建路径文件夹，如果不存在
            if (!Directory.Exists(Application.dataPath + "/" + path))
            {
                Directory.CreateDirectory(Application.dataPath + "/" + path);
            }

            path = $"Assets/{path}";

            // 检查是否已经存在一个 mesh 在路径，如果是则重写
            path = $"{path}{mesh.name}.asset";
            Mesh existingMesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
            if (existingMesh != null)
            {
                EditorUtility.CopySerialized(mesh, existingMesh);
                AssetDatabase.SaveAssets();
            }
            else
            {
                // 创建一个新的 mesh 资源
                AssetDatabase.CreateAsset(mesh, path);
            }

            AssetDatabase.SaveAssets();
        }

        // 删除指定目录下的所有资产
        public static void DeleteAssetsInDirectory(string directoryPath)
        {
            directoryPath = $"Assets/{directoryPath}";
            // 获取指定目录下的所有资产路径
            string[] assetPaths = AssetDatabase.FindAssets("", new[] { directoryPath });

            foreach (string assetPath in assetPaths)
            {
                // 获取资产的完整路径
                string fullPath = AssetDatabase.GUIDToAssetPath(assetPath);

                // 删除资产
                AssetDatabase.DeleteAsset(fullPath);
            }

            // 强制刷新数据库以应用更改
            AssetDatabase.Refresh();
        }

        /// <summary>
        /// 创建新GameObject在场景中
        /// </summary>
        /// <param name="subMeshes"></param>
        /// <param name="path"></param>
        public static void CreatNewObjects(GameObject ogObject, ref List<Mesh> subMeshes,
            out List<GameObject> newGameObjects, string path = "", bool isBaked = false)
        {
            targetObject = ogObject;
            newGameObjects = new List<GameObject>();
            if (path == "")
            {
                path = $"Assets/Art/TerrainBake/";
            }
            else
            {
                path = $"Assets/{path}";
            }

            Material material = targetObject.GetComponent<MeshRenderer>().sharedMaterial;
            foreach (var sMesh in subMeshes)
            {
                string originalMeshPath = $"{path}{sMesh.name}.asset";
                // 读取原始Mesh资源
                // Mesh originalMesh = AssetDatabase.LoadAssetAtPath<Mesh>(originalMeshPath);
                Mesh originalMesh = sMesh;
                if (originalMesh == null)
                {
                    Debug.LogError($"Mesh {sMesh.name} not found at path: {originalMeshPath}");
                    continue;
                }

                // 计算中心偏移
                Vector3 centerOffset = originalMesh.bounds.center;

                // 直接修改原始Mesh的顶点数据
                Vector3[] vertices = originalMesh.vertices;
                for (int i = 0; i < vertices.Length; i++)
                {
                    vertices[i] -= centerOffset; // 让几何中心对齐Pivot
                }
                originalMesh.vertices = vertices;
                originalMesh.RecalculateBounds();
                originalMesh.RecalculateNormals(); // 重新计算法线，防止光照错误

                // 标记Mesh已更改，并保存
                EditorUtility.SetDirty(originalMesh);
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();

                // ================================================================
                // 创建Object
                GameObject newObject = new GameObject();
                newObject.name = sMesh.name;
                newObject.transform.SetPositionAndRotation(targetObject.transform.position,
                    targetObject.transform.rotation);
                newObject.transform.position += targetObject.transform.TransformVector(centerOffset);
                newObject.transform.SetParent(targetObject.transform.parent, true);
                // 添加组件
                MeshFilter newMeshFilter = newObject.AddComponent<MeshFilter>();
                MeshRenderer newMeshRenderer = newObject.AddComponent<MeshRenderer>();
                // 赋予Mesh和材质
                newMeshFilter.sharedMesh = AssetDatabase.LoadAssetAtPath<Mesh>(originalMeshPath);
                newMeshRenderer.sharedMaterial = isBaked
                    ? AssetDatabase.LoadAssetAtPath<Material>($"{path}{sMesh.name}.mat")
                    : material;

                newGameObjects.Add(newObject);
            }
        }
    }
}