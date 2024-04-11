# 我使用的一些小渲染功能

## Base Shader
### 基础
>PBR_Base
基础的光照，额外添加法线向上的纹理层和世界空间的颜色渐变

>PBR_MatFog
基础的光照，额外添加材质内的云海烟雾效果

>PBR_Secondary
基础的光照，额外一套纹理贴图

>PBR_Transparent
基础的光照，专门为半透做了简化

>Decal
基础的贴花，最好用于Box上

### NPR
>NPR_Role
基础PBR混合NPR的卡通效果

>NPR_Advanced
在Role上添加了Fresnel描边和溶解效果，也可半透明

### 特效
>EffectTemplate
特效Shader的基础模版，用于复制后制作新Shader

>Distort
带有溶解和扭曲效果，非常常用的功能

### 库
>Shader Library
通用的顶点着色器、通用的函数或者特殊功能

### GUI
>Shader GUI
有些功能或开关或一些便利的操作使用GUI去完成
因为GUI的原因，通过脚本替换材质可能导致某些效果并未生效，打开材质的编辑界面即可自动刷新

## Renderer Feature
>RoomStencil
主要文件为RenderFeature文件、Volume文件和Shader文件
需要StencilMask的Shader去协助写入Stencil

**RenderFeature文件核心功能：**
1. 暂存颜色
2. 清空画布
3. 绘制Stencil遮罩
4. 遮罩模糊
5. 遮罩覆盖颜色
   
使得Stencil区域才能正常渲染，其他区域为黑色被遮罩的效果
![StencilMask_Room](https://github.com/RyouTomokin/Unity2021-URP-Shader/assets/55241756/6ec873eb-f5dc-4e46-a47b-f5adc4e70148)

**主要解决的问题：相机堆栈导致的Stencil数据无法正确使用，最终导致效果错误**
