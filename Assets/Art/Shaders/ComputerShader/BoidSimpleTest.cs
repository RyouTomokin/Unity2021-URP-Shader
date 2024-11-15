using System;
using System.Runtime.InteropServices;
using Unity.Collections;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.VFX;
using Random = Unity.Mathematics.Random;

[RequireComponent(typeof(VisualEffect))]
public class BoidSimpleTest : MonoBehaviour
{
    [VFXType(VFXTypeAttribute.Usage.GraphicsBuffer)]
    public struct BoidSimpleState
    {
        public Vector3 Position;
        public Vector3 Direction;
    }

    public ComputeShader BoidComputeShader;
    
    VisualEffect _boidVisualEffect;
    private GraphicsBuffer _boidBuffer;
    
    int _kernelIndex;
    public int   BoidCount         = 16;
    public float RotationSpeed     = 1;
    public float BoidSpeed         = 1;
    public float NeighbourDistance = 5;
    public Transform TargetObject;

    private void OnEnable()
    {
        // 创建Buffer
        _boidBuffer =
            new GraphicsBuffer(GraphicsBuffer.Target.Structured, BoidCount, Marshal.SizeOf<BoidSimpleState>());
        
        // 创建数组，也是Buffer的原始数据
        // BoidState[] boidArray = new BoidState[1];
        var boidArray =
            new NativeArray<BoidSimpleState>(BoidCount, Allocator.Temp, NativeArrayOptions.UninitializedMemory);
        
        for (var i = 0; i < boidArray.Length; i++)
        {
            var random = new Random((uint)i + 1);
            boidArray[i] = new BoidSimpleState
            {
                Position = random.NextFloat3(-1, 1),
                Direction = random.NextFloat3(-1, 1),
            };
        }
        // 给Buffer传入数据
        _boidBuffer.SetData(boidArray);
        boidArray.Dispose();
        
        // 给ComputeShader设置Buffer
        _kernelIndex = BoidComputeShader.FindKernel("CSMain");
        BoidComputeShader.SetBuffer(_kernelIndex, "boids", _boidBuffer);

        // 给VFX设置Buffer
        _boidVisualEffect = GetComponent<VisualEffect>();
        _boidVisualEffect.SetGraphicsBuffer("Boid", _boidBuffer);
        _boidVisualEffect.SetInt("BoildCount", BoidCount);
    }

    private void OnDisable()
    {
        _boidBuffer.Release();
    }

    private void Update()
    {
        UpdateBoids();
    }

    void UpdateBoids()
    {
        var boidTarget = TargetObject != null
            ? TargetObject.position
            : transform.position;
        boidTarget -= transform.position;   //如果粒子是Local空间
        BoidComputeShader.SetInt("BoidsCount", BoidCount);
        BoidComputeShader.SetFloat("DeltaTime", Time.deltaTime);
        BoidComputeShader.SetFloat("RotationSpeed", RotationSpeed);
        BoidComputeShader.SetFloat("BoidSpeed", BoidSpeed);
        BoidComputeShader.SetFloat("NeighbourDistance", NeighbourDistance);
        BoidComputeShader.SetVector("FlockPosition", boidTarget);
        
        BoidComputeShader.GetKernelThreadGroupSizes(_kernelIndex, out var x, out var y, out var z);
        BoidComputeShader.Dispatch(_kernelIndex, (int) Math.Ceiling((double) BoidCount / x), 1, 1);
    }
}
