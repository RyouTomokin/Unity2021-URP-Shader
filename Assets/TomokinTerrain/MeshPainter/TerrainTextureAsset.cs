using System;
using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;

namespace Tomokin
{
#if UNITY_EDITOR
    [CreateAssetMenu(fileName = "NewTerrainTextureData", menuName = "TerrainTextureAsset", order = 1001)]
    public class TerrainTextureAsset : ScriptableObject
    {
        public List<TerrainTexture> terrainTextures;
        [HideInInspector]public string assetName = "New";
    }
    
    [Serializable]
    public class TerrainTexture
    {
        public Texture2D albedoMap;
        public Texture2D normalMap;
        public Texture2D maskMap;
        public float tilling;
        public Vector2 offset;

        public TerrainTexture(Texture2D albedo = null)
        {
            this.albedoMap = albedo;
            this.normalMap = null;
            this.maskMap = null;
            this.tilling = 1;
            this.offset = Vector2.zero;
        }
    }
    
    public static class TerrainTextureSaver
    {
        public static void SaveTerrainTextures(List<TerrainTexture> textures, string path)
        {
            TerrainTextureAsset asset = ScriptableObject.CreateInstance<TerrainTextureAsset>();
            asset.terrainTextures = textures;

            AssetDatabase.CreateAsset(asset, path);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();

            Debug.Log($"Terrain texture data saved at {path}");
        }
    }
#endif
}