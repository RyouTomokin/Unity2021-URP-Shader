using System;
using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;

namespace Tomokin
{
    public class MeshNormalSmooth : EditorWindow
    {
        // 位置容差处理（格点化）
        private static Vector3 Quantize(Vector3 v, float tolerance)
        {
            return new Vector3(
                Mathf.Round(v.x / tolerance) * tolerance,
                Mathf.Round(v.y / tolerance) * tolerance,
                Mathf.Round(v.z / tolerance) * tolerance
            );
        }

        // 自定义 Vector3 相似方向判断器（用于 HashSet 判断法线是否相同）
        private class NormalComparer : IEqualityComparer<Vector3>
        {
            private float _tolerance;

            public NormalComparer(float tolerance)
            {
                _tolerance = tolerance;
            }

            public bool Equals(Vector3 a, Vector3 b)
            {
                return Vector3.Angle(a, b) <= _tolerance * 180f;
            }

            public int GetHashCode(Vector3 obj)
            {
                Vector3 q = Quantize(obj.normalized, _tolerance);
                return q.GetHashCode();
            }
        }

        /// <summary>
        /// 对给定 Mesh 平滑法线（按位置容差聚合，唯一方向平均）
        /// </summary>
        public static void SmoothNormals(Mesh mesh, float positionTolerance = 0.0001f, float normalTolerance = 0.001f)
        {
            if (mesh == null)
            {
                Debug.LogError("Mesh is null.");
                return;
            }

            Vector3[] vertices = mesh.vertices;
            Vector3[] normals = mesh.normals;
            if (vertices == null || normals == null || vertices.Length != normals.Length)
            {
                Debug.LogError("Mesh data is invalid.");
                return;
            }

            var pointMap = new Dictionary<Vector3, List<int>>();

            // 1. 聚合位置相近点
            for (int i = 0; i < vertices.Length; i++)
            {
                Vector3 key = Quantize(vertices[i], positionTolerance);
                if (!pointMap.TryGetValue(key, out var list))
                {
                    list = new List<int>();
                    pointMap[key] = list;
                }
                list.Add(i);
            }

            Vector3[] smoothedNormals = new Vector3[normals.Length];
            var comparer = new NormalComparer(normalTolerance);

            // 2. 遍历每组位置相同点
            foreach (var pair in pointMap)
            {
                List<int> indices = pair.Value;

                // 收集唯一方向的法线（去重）
                var uniqueNormals = new HashSet<Vector3>(comparer);
                foreach (int idx in indices)
                {
                    uniqueNormals.Add(normals[idx].normalized);
                }

                // 平均
                Vector3 normalSum = Vector3.zero;
                foreach (var n in uniqueNormals)
                {
                    normalSum += n;
                }
                Vector3 average = normalSum.normalized;

                foreach (int idx in indices)
                {
                    smoothedNormals[idx] = average;
                }
            }

            mesh.normals = smoothedNormals;
        }
    }
}