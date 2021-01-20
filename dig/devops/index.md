---
title: 系统运维
layout: page
comments: no
---

## 基础命令

包含基础的字符串搜索、文件搜索、进程监控、内存监控、CPU 监控、IO 监控、网络监控……

```shell
## 查看进程信息


## 内存分析


## 网络分析


## CPU 分析


## IO 分析


## JVM 调优/分析

```

## 中间件命令

```shell
## 启动MySQL 服务
mysql.server start


## 启动Hadoop 服务
cd /Users/xumenger/Desktop/library/hadoop-2.10.1/hadoop-2.10.1/sbin
./start-all.sh


## 启动HBase 服务
cd /Users/xumenger/Desktop/library/hbase-2.3.3/hbase-2.3.3/bin
./start-hbase.sh

## 打开HBase 客户端
cd /Users/xumenger/Desktop/library/hbase-2.3.3/hbase-2.3.3/bin
./hbase shell


## 启动Hive 服务
cd /Users/xumenger/Desktop/library/apache-hive-2.3.8-bin/bin
./hive --service metastore &

# 打开Hive 客户端
cd /Users/xumenger/Desktop/library/apache-hive-2.3.8-bin/bin
./hive 


## 启动Kafka 服务



## 启动ElasticSearch 服务



## 启动Kibana

```

## 中间件监控

HDFS Web 端，查看HDFS 中的文件 [http://localhost:50070/explorer.html](http://localhost:50070/explorer.html)

Spark Web 端，查看特定的Spark Job 信息 [http://localhost:4040/jobs/](http://localhost:4040/jobs/)
