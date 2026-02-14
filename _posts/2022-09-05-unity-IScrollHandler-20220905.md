---
layout: post
title: Unity 鼠标滚轮事件
categories: 好好玩游戏 
tags: Unity 输入系统 玩家输入 输入 事件 UGUI IScrollHandler c# Unity2017 Unity2022 orthographic 正交投影 透视投影
---

UGUI 关于鼠标滚轮信息的获取有一个专门的接口IScrollHandler 用于接收滚轮事件。继承该事件之后便需要实现函数OnScroll()

通过Input获取滚轮信息的方式为Input.GetAxis("Mouse ScrollWheel")

滚轮上滑为正，下滑为负；且滚轮的每个小格卡顿，其数值信息表示为0.1，快速连续滚动时其数值会直接出现对应的数值，不会一格一格出现

比如实现用鼠标滚轮控制游戏画面的放大、缩小

```c#
public class MouseController : MonoBehaviour, IScrollHandler
{

    /**
     * 鼠标滚轮回调事件控制游戏画面放大、缩小
     * 
     */
    void IScrollHandler.OnScroll(PointerEventData eventData)
    {
        Debug.Log("OnScroll");

        // orthographic若值为true则为正交投影，反之为透视投影
        if (Camera.main.orthographic == true)
        {
            Camera.main.orthographicSize += Input.GetAxis("Mouse ScrollWheel") * 10;
        }
        else
        {
            Camera.main.fieldOfView += Input.GetAxis("Mouse ScrollWheel") * 10;
        }
    }
}
```

以上是针对Unity 2017.2 版本的实现方式，但是在Unity 2020.3 版本中不起作用（是否确实与版本有关，目前还未证明），暂时使用下面的代码

```c#
public class MouseController : MonoBehaviour
{

    void Update()
    {
        /**
         * 鼠标点击事件：0 左键；1 右键；2 中键
         */
        if (Input.GetMouseButtonDown(0))
        {
            Debug.Log("鼠标左键被按下");
        }

        /**
         * 判断鼠标滚轮，向上为正、向下为负
         * https://docs.unity3d.com/ScriptReference/Input-mouseScrollDelta.html
         */
        if (Input.mouseScrollDelta.y >= 0.01 || Input.mouseScrollDelta.y <= -0.01)
        {
            if (Camera.main.orthographic == true)
            {
                Camera.main.orthographicSize += Input.GetAxis("Mouse ScrollWheel") * 10;
            }
            else
            {
                Camera.main.fieldOfView += Input.GetAxis("Mouse ScrollWheel") * 10;
            }
        }
        
    }
}
```

## 参考资料

* https://docs.unity3d.com/2017.2/Documentation/ScriptReference/EventSystems.IScrollHandler.html
* https://docs.unity3d.com/2018.1/Documentation/ScriptReference/EventSystems.IScrollHandler.OnScroll.html
* https://docs.unity3d.com/ScriptReference/Input-mouseScrollDelta.html
