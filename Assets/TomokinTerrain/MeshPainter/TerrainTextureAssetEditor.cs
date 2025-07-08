using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEngine;

namespace Tomokin
{
#if UNITY_EDITOR
    [CustomEditor(typeof(TerrainTextureAsset))]
    public class TerrainTextureAssetEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            // 画默认Inspector内容
            DrawDefaultInspector();

            TerrainTextureAsset asset = (TerrainTextureAsset)target;
            string assetPath = AssetDatabase.GetAssetPath(asset);
            string directory = System.IO.Path.GetDirectoryName(assetPath) + "/";

            GUILayout.Space(10);

            if (GUILayout.Button("保存"))
            {
                EditorUtility.SetDirty(asset);
                AssetDatabase.SaveAssets();
            }

            asset.assetName = EditorGUILayout.TextField("导出的地形名", asset.assetName);
            if (GUILayout.Button("导出地形纹理"))
            {
                TextureFormat _textureFormat = TextureFormat.RGBA32;
                
                List<Texture2D> albedoTextures = asset.terrainTextures.Select(t => t.albedoMap).ToList();
                Texture2D defaultNormal = new Texture2D(1, 1, _textureFormat, false);
                List<Texture2D> normalTextures =
                    asset.terrainTextures.Select(t => t.normalMap != null ? t.normalMap : defaultNormal).ToList();
                Texture2D defaultMask = new Texture2D(1, 1, _textureFormat, false);
                List<Texture2D> maskTextures =
                    asset.terrainTextures.Select(t => t.maskMap != null ? t.maskMap : defaultMask).ToList();
                
                string albedoMapPath = directory + $"T_{asset.assetName}_D.asset";
                string normalMapPath = directory + $"T_{asset.assetName}_N.asset";
                string maskMapPath   = directory + $"T_{asset.assetName}_SM.asset";
                
                TextureArrayGenerator.CreateAndSaveTextureArray(albedoTextures, albedoMapPath, 1024);
                TextureArrayGenerator.CreateAndSaveTextureArray(normalTextures, normalMapPath, 1024);
                TextureArrayGenerator.CreateAndSaveTextureArray(maskTextures  , maskMapPath,   1024);
            }
        }
    }
#endif
}