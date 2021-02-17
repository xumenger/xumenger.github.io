---
layout: post
title: Shader 动画：应用于DOTS 应用
categories: 游戏开发之unity 
tags: Unity C# Shader 动画 游戏 渲染 调优 DOTS Animation Animator 
---

之前研究了DOTS，看到使用了ECS、C# Job、Burst 之后，性能简直起飞，上一篇中看到使用Shader 优化动画之后，性能也是起飞，那两者结合起来，岂不是“芜湖起飞”！！！

>[Unity DOTS 技术：HybridECS](http://www.xumenger.com/unity-dots-ecs-20201128/)

>[Unity DOTS 技术：C# Job System](http://www.xumenger.com/unity-dots-csharp-job-20201129/)

>[Unity DOTS 技术：Burst Compiler](http://www.xumenger.com/unity-dots-burst-20201130/)

>[Unity DOTS 技术：Physics](http://www.xumenger.com/unity-dots-physics-20201201/)

本文将这两种性能优化的大杀器结合在一起，看一下运行起来后的性能指标是什么样的？很多操作会重复之前文章中已经说过的，不过这里为了全流程展示，就再来一遍

## AnimMapBaker 准备

在Project 资源管理器中，分别为Mini Legion Footman PBR HP Polyart/Meshes/Footman_Default、Mini Legion Footman PBR HP Polyart/Animations/Footman_Attack02

![](../media/image/2021-01-17/01.png)

为了动画循环播放，将Animation/Footman_Attack02 设置为循环播放

![](../media/image/2021-01-17/02.png)

新建一个测试场景，接着将Mini Legion Footman PBR HP Polyart/Meshes 下的角色模型Footman_Default 放到场景中，并且添加PBR 材质

![](../media/image/2021-01-17/03.png)

并且为Footman_Default 添加Animation 组件，将其设置为Footman_Attack02

![](../media/image/2021-01-17/04.png)

然后使用AnimMapBaker 烘培出一个基于GPU 的动画预制件

![](../media/image/2021-01-17/05.png)

## DOTS 工作流

