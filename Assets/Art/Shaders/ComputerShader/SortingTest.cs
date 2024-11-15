
using System.Runtime.InteropServices;
using System.Collections.Generic;
using UnityEngine;
// using Random = System.Random;

public class SortingTest : MonoBehaviour
{
    public ComputeShader computeShader;
    
    public Mesh mesh;
    public Material material;
    public int count = 50;
    private float width;
    
    private List<GameObject> objects;
    private GraphicsBuffer _cubeBuffer;

    private float[] data;
    
    public void CreateCubes()
    {
        //TODO:在指定目录下生成
        objects = new List<GameObject>();
        data = new float[count];

        for (int x = 0; x < count; x++)
        {
            CreateCube(x);
        }
    }
    
    public void CreateCube(int x)
    {
        width = 1.0f / count;
        GameObject cube = new GameObject("Cube " + x, typeof(MeshFilter), typeof(MeshRenderer));
        cube.GetComponent<MeshFilter>().mesh = mesh;
        cube.GetComponent<MeshRenderer>().material = material;
        cube.transform.position = new Vector3((float)x / count, 0, 0);
        cube.transform.localScale = new Vector3(width, (float)(x + 1) / count, width);

        objects.Add(cube);

        data[x] = (float)(x + 1) / count;
    }

    private void OnEnable()
    {
        // 创建Buffer
        _cubeBuffer =
            new GraphicsBuffer(GraphicsBuffer.Target.Structured, count, Marshal.SizeOf<float>());
        
        
    }

    private void OnDisable()
    {
        _cubeBuffer.Dispose();
    }

    public void OnRandomizeCubes()
    {
        List<int> randSort = new List<int>();
        for (int i = 0; i < count; i++)
        {
            randSort.Add(i);
        }

        for (int i = 0; i < count; i++)
        {
            int temp = Random.Range(0, (count - i));
            data[i] = (float)randSort[temp] / count;
            objects[i].transform.position = new Vector3(data[i], 0, 0);
            randSort.Remove(randSort[temp]);
        }
    }

    public void OnSortCubes()
    {
        _cubeBuffer.SetData(data);
        computeShader.SetBuffer(0, "cubes", _cubeBuffer);
        computeShader.SetInt("cubeCount", count);
        computeShader.GetKernelThreadGroupSizes(0, out var x, out var y, out var z);
        computeShader.Dispatch(0, 1,1,1);
        
        _cubeBuffer.GetData(data);
        
        for (int i = 0; i < objects.Count; i++)
        {
            GameObject obj = objects[i];
            obj.transform.position = new Vector3(data[i], 0, 0);
        }
    }
    
    private void OnGUI()
    {
        if (objects == null)
        {
            if (GUI.Button(new Rect(0, 100, 100, 50), "CreateSortCubes"))
            {
                CreateCubes();
            }
        }
        else
        {
            if (GUI.Button(new Rect(0, 100, 100, 50), "NoiseCubes"))
            {
                OnRandomizeCubes();
            }
            if (GUI.Button(new Rect(100, 100, 100, 50), "SortCubes"))
            {
                OnSortCubes();
            }
        }
    }
}
