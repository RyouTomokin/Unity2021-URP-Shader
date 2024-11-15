using System;
using System.Runtime.InteropServices;
using Unity.Collections;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.VFX;
using Random = Unity.Mathematics.Random;

[RequireComponent(typeof(VisualEffect))]
public class BoidTest : MonoBehaviour
{
    [VFXType(VFXTypeAttribute.Usage.GraphicsBuffer)]
    public struct BoidState
    {
        public Vector3 Velocity;
        public Vector3 Position;
        
        public Vector3 Integral;     
        public Vector3 PreviousError;
    }
    
    [Serializable]
    public class PID_Control
    {
        public float kP = 1;
        public float kI = 0;
        public float kD = 1;
    }
    
    public ComputeShader BoidComputeShader;
    
    VisualEffect _boidVisualEffect;
    private GraphicsBuffer _boidBuffer;
    
    int _kernelIndex;
    public int boidCount = 16;
    public float maxVelocity = 10;
    public float maxAcceleration= 10;
    public Transform TargetObject;

    public PID_Control pid_Control;

    private void OnEnable()
    {
        // 创建Buffer
        _boidBuffer =
            new GraphicsBuffer(GraphicsBuffer.Target.Structured, boidCount, Marshal.SizeOf<BoidState>());
        
        // 创建数组，也是Buffer的原始数据
        // BoidState[] boidArray = new BoidState[1];
        var boidArray =
            new NativeArray<BoidState>(boidCount, Allocator.Temp, NativeArrayOptions.UninitializedMemory);
        
        for (var i = 0; i < boidArray.Length; i++)
        {
            var random = new Random((uint)i + 1);
            boidArray[i] = new BoidState
            {
                Velocity = random.NextFloat3(-1, 1),
                Position = random.NextFloat3(-1, 1),
                Integral = Vector3.zero,
                PreviousError = Vector3.zero,
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
        _boidVisualEffect.SetInt("BoildCount", boidCount);
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
        BoidComputeShader.SetFloat("deltaTime", Time.deltaTime);
        BoidComputeShader.SetFloat("maxVelocity", maxVelocity);
        BoidComputeShader.SetFloat("maxAcceleration", maxAcceleration);
        BoidComputeShader.SetFloat("kP", pid_Control.kP);
        BoidComputeShader.SetFloat("kI", pid_Control.kI);
        BoidComputeShader.SetFloat("kD", pid_Control.kD);
        BoidComputeShader.SetVector("targetPos", boidTarget);
        
        BoidComputeShader.GetKernelThreadGroupSizes(_kernelIndex, out var x, out var y, out var z);
        BoidComputeShader.Dispatch(_kernelIndex, (int) (boidCount / x), 1, 1);
    }
}
