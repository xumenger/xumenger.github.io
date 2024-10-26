---
layout: post
title: Unity
categories: 游戏开发
tags: 游戏 2D 
---

git push origin main 突然出现报错

![](../media/image/2024-10-26/01.png)

![](../media/image/2024-10-26/02.png)

进行如下修改：

修改~/.gitconfig，添加如下内容：

```
[url "git@github.com:"]
    insteadOf = https://github.com
```

修改vim ~/.ssh/config，添加如下内容：

```
Host github.com
  HostName ssh.github.com
  Port 443
```

然后执行下面的命令，将SSH 连接的端口更改为443

```
ssh -T -p 443 git@ssh.github.com
```

预期显示如下成功的结果：

```
Hi xumenger! You've successfully authenticated, but GitHub does not provide shell access.
```