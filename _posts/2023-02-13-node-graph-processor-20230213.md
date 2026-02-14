---
layout: post
title: Unity NodeGraphProcessor：运行时遍历节点
categories: 游戏开发之unity 好好玩游戏 
tags: 游戏 Unity GraphView 持久化 配置化 NodeGraphProcessor Odin 
---

基于上几篇的文章对于NodeGraphProcessor 使用的介绍，站在我的角度，可以把其分为这么几个状态

* 编辑时，UI界面对应在编辑器内存
	* BaseGraphView
	* DialogGraphGlobalOptionView
	* BaseNodeView
* 编辑时，将UI对应的配置进行持久化
	* BaseGraph
	* BaseNode
* 运行时，加载持久化ScriptableObject 到内存中处理
	* BaseGraph
	* BaseNode

怎么在运行时遍历NodeGraph 的节点，然后针对不同类型的节点做不同的处理？本文就简单总结一下

比如定义节点父类如下

```c#
public class DialogBaseNode : BaseNode
{ 
    // 设置节点是可以重命名的
    public override bool isRenamable => true;


    /// <summary>
    /// 谁在说话。HideInInspector
    /// 使用DialogBaseNodeView以下拉框方式显示和设置该值
    /// 
    /// </summary>
    [HideInInspector]
    public string talker;

    // ui配置
    public int uiId;

}
```

定义普通节点

```c#
[NodeMenuItem("Dialog/Common")]
public class DialogCommNode : DialogBaseNode
{
    public override string name => "普通对话";

    // 对话内容
    public string contentId;


    // allowMultiple = true，允许多个前置节点连入
    [Input(name = "In", allowMultiple = true)]
    public string input;


    // 文本内容ID，对应可实现多国语言
    [Output(name = "Out", allowMultiple = false)]
    public string output;

}
```

定义对话选择节点

```c#
/// <summary>
/// 选择映射关系
/// 
/// </summary>
[Serializable]
public class SelectMap
{
    public string contentId;   // 当前对话
    public string nextName;    // 当前对话对应下一个节点名
}
    

[NodeMenuItem("Dialog/Select")]
public class DialogSelectNode : DialogBaseNode
{
    public override string name => "选择对话";

    [SerializeField, HideInInspector]
    public List<SelectMap> selectMapList = new List<SelectMap>();
  
    [Input(name = "In", allowMultiple = true)]
    public string input;


    // 文本内容ID，对应可实现多国语言
    [Output(name = "Out", allowMultiple = true)]
    public string output;

}
```

在编辑器环境下，在NodeGraph 中编辑节点图，然后可以在运行的时候遍历

```c#
public class DialogExample : MonoBehaviour
{
    public DialogGraph dialogGraph;


    // Start is called before the first frame update
    void Start()
    {
        foreach (BaseNode node in dialogGraph.nodes)
        {
            if (node is DialogCommNode)
            {
            	DialogCommNode commNode = (DialogCommNode)node;

                Debug.Log("DialogCommNode: " + commNode.contentId);
            }
            else if (node is DialogSelectNode)
            {
                DialogSelectNode selectNode = (DialogSelectNode)node;
                Debug.Log("DialogSelectNode: " + selectNode.contentId);
            }
        }
    }
}
```

