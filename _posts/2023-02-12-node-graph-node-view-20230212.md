---
layout: post
title: Unity NodeGraphProcessor：BaseNodeView 定制节点UI
categories: 游戏开发之unity 好好玩游戏 
tags: 游戏 Unity GraphView 持久化 配置化 NodeGraphProcessor BaseNodeView UIElements VisualElement uss 
---

>[https://docs.unity.cn/cn/2020.3/Manual/UIElements.html](https://docs.unity.cn/cn/2020.3/Manual/UIElements.html)

>[https://docs.unity.cn/2020.3/Documentation/Manual/UIElements.html](https://docs.unity.cn/2020.3/Documentation/Manual/UIElements.html)

如[Unity NodeGraphProcessor：使用说明](http://www.xumenger.com/graph-view-20230204/) 展示的，只需要简单的实现BaseNode 子类，默认就会在UI 中显示Input、Output、相关属性等，但是如果我们想为节点做更复杂的UI 显示怎么实现？

需要实现BaseNodeView 的子类，并且将这些实现放到名字为Editor 的文件夹下面

比如我定义了一个节点

```c#

```

为其定制UI 显示效果

```c#

```

在节点图编辑器中可以看到其效果是这样的

![](../media/image/2023-02-12/01.png)

想要跟进一步指定颜色等样式，可以使用uss，对应可以参考[Unity NodeGraphProcessor：USS 样式](http://www.xumenger.com/uss-20230211/)
