using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;

namespace Tomokin
{
    public class TextureArrayGenerator
    {
        public static void CreateAndSaveTextureArray(List<Texture2D> terrainTextures, string path)
        {
            Texture2DArray texture2DArray =  CreateTextureArray(terrainTextures);
            SaveTextureArray(texture2DArray, path);
        }
        
        public static Texture2DArray CreateTextureArray(List<Texture2D> terrainTextures)
        {
            if (terrainTextures == null || terrainTextures.Count == 0)
            {
                Debug.LogError("Texture list is empty!");
                return null;
            }

            // 获取第一个Texture2D的宽、高、格式
            int width = terrainTextures[0].width;
            int height = terrainTextures[0].height;
            TextureFormat format = terrainTextures[0].format;

            // 创建Texture2DArray
            Texture2DArray textureArray = new Texture2DArray(width, height, terrainTextures.Count, format, false);
            textureArray.wrapMode = TextureWrapMode.Repeat;  // 设置Wrap模式
            textureArray.filterMode = FilterMode.Bilinear;   // 设置过滤模式
            textureArray.anisoLevel = 4;                     // 设置各向异性过滤

            // 逐个拷贝Texture2D到Texture2DArray
            for (int i = 0; i < terrainTextures.Count; i++)
            {
                if (terrainTextures[i].width != width || terrainTextures[i].height != height)
                {
                    Debug.LogError($"Texture {i} has a different size! Rescale required.");
                    continue;
                }

                Graphics.CopyTexture(terrainTextures[i], 0, 0, textureArray, i, 0);
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

            // 确保路径存在
            string directory = Path.GetDirectoryName(path);
            if (!Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            // 保存为 Unity Asset
            AssetDatabase.CreateAsset(textureArray, path);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            Debug.Log($"Texture2DArray saved at: {path}"); 
        }
    }

}