---
layout: post
title: 大模型实战 - 3：使用LangChain 进行大模型开发
categories: 人工智能与大模型
tags: ollama 大模型 提示词 LangChain Python
---

## 搭建Python 虚拟环境

Langchain 需要使用Python 编写程序，记得要先安装Python3，本人选择Python3.7

![](../media/image/2025-03-11/01.png)

创建Python虚拟环境，在虚拟环境中执行，可以避免各种软件包版本依赖问题

创建D:\LLM\Python\20250311_LangChain，作为虚拟文件夹

```shell
> cd D:\LLM\Python\
> python3 -m venv 20250311_LangChain
> .\20250311_LangChain\Scripts\activate
```

![](../media/image/2025-03-11/02.png)

接着在虚拟环境中安装langchain、langchain_community

```shell
pip3 install langchain
pip3 install langchain_community
```

## LangChain 对接Ollama

