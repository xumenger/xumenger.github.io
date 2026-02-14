---
layout: post
title: Unity 提升画质小技巧
categories: 游戏开发之unity 好好玩游戏 
tags: 游戏 Unity 调优 资产 阴影 HDR 后处理 软阴影 URP 环境光 抗锯齿 
---

## URP 配置中的阴影渲染

在URP 渲染管线下，对于URP 的配置【Shadows】

【Max Distance】，比如值为50，表示在摄像机看到的50 米之外的物体，不渲染Shadow，如果场景中有非常多的东西，如果在非常远的距离仍然渲染影子的话，是非常消耗性能的

【Cascade Count】，渲染级别，比如设置为2，那么对应下面就会有【Split 1】选项

【Split 1】，比如设置为10，那么物体距离摄像机0-10 米的话，则是实阴影，超过10 则是比较虚的阴影。实阴影渲染的视觉效果更好，但是也更耗性能

【Normal Blas】，有时候会看到阴影中有很多缝隙，可以通过将该值设为0，得到一个实的阴影；值越高，阴影越虚

勾选【Soft Shadows】表示开启软阴影

## URP 配置中的灯光设置

在URP 渲染管线下，还有一个配置【Lighting】

【Main Light】->【Shadow Resolution】，值越低，影子的效果越差，但性能更好；反之则影子的效果越好，但更耗性能

## URP 配置中的抗锯齿

URP 渲染管线，勾选开启【Quality】->【HDR】，在Post Processing 的时候会用到

【Quality】->【Anti Aliasing(MSAA)】，抗锯齿，级别越高，效果越好，对应性能开销更大

另外在Main Camera 的【Rendering】选项中也可以通过【Anti-aliasing】开启抗锯齿

## Unity 光照设置

【Window】->【Rendering】->【Lighting】->【Scene】->【New Lightinbg Settings】就会对应在Project 工程目录下创建一个灯光设置文件

在这里可以配置光照贴图的渲染，比如选择使用CPU 还是GPU、是否自动渲染（不推荐，否则每次动场景都会渲染光照贴图）

## 场景颜色异常

有的时候，看到场景渲染出来的颜色比较怪，有可能是因为【Window】->【Rendering】->【Lighting】->【Environment】的设置问题

其中有一个【Environment Lighting】环境光的设置，【Source】设置环境光光源，默认是SkyBox，那么场景颜色就会被SkyBox 影响，可以根据实际情况保持是SkyBox，或者设置为其他值

## 雾效

【Window】->【Rendering】->【Lighting】->【Environment】->【Other Settings】->【Fog】可以开启雾效

【Color】设置雾的颜色

【Start】、【End】设置雾的能见度

## 后处理效果

URP 版本中，后处理是默认的功能，不需要安装插件。在Hierarchy 中可以创建，【Volume】下有多个选项

* Global Volume：全局后处理效果
* Box Vloume：指定区域后处理效果
* Sphere Vloume：指定区域后处理效果
* Convex Mesh Vloume：指定区域后处理效果

Box Vloume，比如可以实现人物走到某个区域的时候，触发该区域变成黑白等效果！

比如创建了Global Volume 之后，还需要在Project 中创建Volume Profile，为这个Global Volume 指定这个Volume Profile

然后就可以通过【Add Override】->【Post Processing】->【Bloom】等配置项去配置各种后处理效果！

当然除了默认的Post Processing，也可以自定义你想要的后处理效果！

设置之后可能发现没有任何效果，因为需要去Main Camera 的【Rendering】选项中勾选启动【Post Processing】

【Add Override】->【Post Processing】->【ToneMapping】，可以让画面有一些更深度的显示，通常电影级别的话Mode 选择ACES，设置好之后，会发现颜色变得更深邃了，也就是深色更深、亮度更亮了，画质就会有很好的提升

