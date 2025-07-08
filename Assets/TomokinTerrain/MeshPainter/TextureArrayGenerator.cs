using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;

namespace Tomokin
{
    public class TextureArrayGenerator
    {
        public static void CreateAndSaveTextureArray(List<Texture2D> terrainTextures, string path, int size)
        {
            Texture2DArray texture2DArray =  CreateTextureArray(terrainTextures, size, size);
            SaveTextureArray(texture2DArray, path);
        }

        public static Texture2DArray CreateTextureArray(List<Texture2D> terrainTextures, int width, int height)
        {
            if (terrainTextures == null || terrainTextures.Count == 0)
            {
                Debug.LogError("Texture list is empty!");
                return null;
            }

            // 获取第一个Texture2D的宽、高、格式
            // int width = terrainTextures[0].width;
            // int height = terrainTextures[0].height;
            TextureFormat format = TextureFormat.RGBA32;

            // 创建Texture2DArray
            Texture2DArray textureArray = new Texture2DArray(width, height, terrainTextures.Count, format, false);
            textureArray.wrapMode = TextureWrapMode.Repeat;  // 设置Wrap模式
            textureArray.filterMode = FilterMode.Bilinear;   // 设置过滤模式
            textureArray.anisoLevel = 4;                     // 设置各向异性过滤

            // 逐个拷贝Texture2D到Texture2DArray
            for (int i = 0; i < terrainTextures.Count; i++)
            {
                Texture2D sourceTex = terrainTextures[i];
                if (sourceTex == null)
                {
                    Debug.LogWarning($"Texture at index {i} is null, using a black texture.");
                    sourceTex = new Texture2D(1, 1, format, false);
                    sourceTex.SetPixel(0, 0, Color.black);
                    sourceTex.Apply();
                }
                
                // 手动解压 贴图 到 RGBA32
                Texture2D tempTexture = new Texture2D(width, height, format, false);
                // Debug.LogError($"Texture {i} has a different size! Rescale required.");
                RenderTexture rt = RenderTexture.GetTemporary(width, height, 0);
            
                Graphics.Blit(sourceTex, rt);
                RenderTexture.active = rt;
                tempTexture.ReadPixels(new Rect(0, 0, width, height), 0, 0);
                tempTexture.Apply();
                RenderTexture.active = null;
                RenderTexture.ReleaseTemporary(rt);

                // 拷贝到Texture2DArray
                Graphics.CopyTexture(tempTexture, 0, 0, textureArray, i, 0);
                
                // 如果是缩放后的临时贴图，需要销毁
                if (tempTexture != sourceTex)
                {
                    Object.DestroyImmediate(tempTexture);
                }
            }

            return textureArray;
        }

        public static void SaveTextureArray(Texture2DArray textureArray, string path)
        {
            if (textureArray == null)
            {
                Debug.LogError("Texture2DArray is null. Cannot save.");
                return;
            }

            textureArray.name = Path.GetFileNameWithoutExtension(path);

            // 确保路径存在
            string directory = Path.GetDirectoryName(path);
            if (!Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            // 保存为 Unity Asset
            // 尝试加载现有资源
            Texture2DArray existingAsset = AssetDatabase.LoadAssetAtPath<Texture2DArray>(path);

            if (existingAsset != null)
            {
                // 用新数据覆盖旧资源，保留 GUID 和引用
                EditorUtility.CopySerialized(textureArray, existingAsset);
                EditorUtility.SetDirty(existingAsset);
            }
            else
            {
                // 资源不存在，则创建新资源
                AssetDatabase.CreateAsset(textureArray, path);
            }

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            Debug.Log($"Texture2DArray saved at: {path}");
        }
    }

}
