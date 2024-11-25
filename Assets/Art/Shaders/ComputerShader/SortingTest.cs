
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
        
        // 创建Buffer
        _cubeBuffer =
            new GraphicsBuffer(GraphicsBuffer.Target.Structured, count, Marshal.SizeOf<float>());
    }

    public void OnClearCubes()
    {
        for (int x = 0; x < objects.Count; x++)
        {
            Destroy(objects[x]);
        }
        objects.Clear();
        objects = null;
        data = null;
        _cubeBuffer.Dispose();
    }
    
    private void OnDisable()
    {
        _cubeBuffer.Dispose();
    }

    public void OnRandomizeCubes()
    {
        List<int> randSort = new List<int>();
        int dataCount = data.Length;
        for (int i = 0; i < dataCount; i++)
        {
            randSort.Add(i);
        }

        for (int i = 0; i < dataCount; i++)
        {
            int temp = Random.Range(0, (dataCount - i));
            data[i] = (float)randSort[temp] / dataCount;
            objects[i].transform.position = new Vector3(data[i], 0, 0);
            randSort.Remove(randSort[temp]);
        }
    }

    //All in GPU,排序数超于32会排序出错
    public void OnSortCubes()
    {
        _cubeBuffer.SetData(data);
        computeShader.SetBuffer(0, "cubes", _cubeBuffer);
        computeShader.SetInt("cubeCount", count);
        computeShader.GetKernelThreadGroupSizes(0, out var x, out var y, out var z);
        
        int Gx = Mathf.CeilToInt(count / (float)x);
        computeShader.Dispatch(0, Gx,1,1);
        
        _cubeBuffer.GetData(data);
        
        for (int i = 0; i < objects.Count; i++)
        {
            GameObject obj = objects[i];
            obj.transform.position = new Vector3(data[i], 0, 0);
        }
    }
    public void OnSortCubesCPU()
    {
        _cubeBuffer.SetData(data);
        int dataCount = data.Length;
        
        int kernel = computeShader.FindKernel("CSMain2");
        computeShader.SetBuffer(kernel, "cubes", _cubeBuffer);
        computeShader.SetInt("cubeCount", dataCount);
        computeShader.GetKernelThreadGroupSizes(kernel, out var x, out var y, out var z);
        
        int Gx = Mathf.CeilToInt(dataCount / (float)x);

        // 在CPU中计算循环的批次，然后统一给GPU进行一次比较和替换
        for (uint k = 2; k <= dataCount; k *= 2)
        {
            for (uint j = k / 2; j > 0; j /= 2)
            {
                computeShader.SetInt("bitonicK", (int)k);
                computeShader.SetInt("bitonicJ", (int)j);
                computeShader.Dispatch(kernel, Gx,1,1);
            }
        }

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
                OnSortCubesCPU();
            }
            if (GUI.Button(new Rect(0, 200, 100, 50), "ClearCubes"))
            {
                OnClearCubes();
            }
        }
    }
}
