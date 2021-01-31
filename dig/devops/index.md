---
title: 系统运维
layout: page
comments: no
---

## 基础命令

包含基础的字符串搜索、文件搜索、进程监控、内存监控、CPU 监控、IO 监控、网络监控……

有问题找“男人”(man)

```shell
## 查看进程信息



## 查看当前机器开启了哪些端口？



## 查看指定端口是哪个进程在占用？


## 内存分析


## 网络分析


## CPU 分析


## IO 分析


## JVM 调优/分析

```

## 中间件命令

```shell
## 启动Hadoop 服务
cd /Users/xumenger/Desktop/library/hadoop-2.10.1/hadoop-2.10.1/sbin
./start-all.sh




## 启动HBase 服务，包含HBase 内置的ZooKeeper
cd /Users/xumenger/Desktop/library/hbase-2.3.3/hbase-2.3.3/bin
./start-hbase.sh

# 打开HBase 客户端
cd /Users/xumenger/Desktop/library/hbase-2.3.3/hbase-2.3.3/bin
./hbase shell




## 启动MySQL 服务
mysql.server start




## 启动Hive 服务
cd /Users/xumenger/Desktop/library/apache-hive-2.3.8-bin/bin
./hive --service metastore &

# 启动HiveServer2
./hive --service hiveserver2 &

# 打开Hive 客户端
cd /Users/xumenger/Desktop/library/apache-hive-2.3.8-bin/bin
./hive 




## 启动Kafka 服务
cd /Users/xumenger/Desktop/library/kafka/kafka_2.11-1.0.0/
./bin/kafka-server-start.sh ./config/server.properties

# 创建Topic，比如
./bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic SparkTopic1
./bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic SparkTopic2

# 生产者脚本，启动后可以随时通过输入生产消息（回车发送消息）
./bin/kafka-console-producer.sh --broker-list localhost:9092 --sync --topic SparkTopic1




## 启动Zookeeper，如果HBase 内置的zookeeper 已经启动，这里无法启动
cd /Users/xumenger/Desktop/library/zookeeper/zookeeper-3.4.12/bin
./zkServer.sh start

# 连接到Zookeeper 服务端
# 使用Zookeeper 自己的客户端
cd /Users/xumenger/Desktop/library/zookeeper/zookeeper-3.4.12/bin
./zkCli.sh

# 使用HBase 的Zookeeper 客户端
cd /Users/xumenger/Desktop/library/hbase-2.3.3/hbase-2.3.3/bin
./hbase zkcli




## 启动ElasticSearch 服务



## 启动Kibana


```

## 中间件监控

**HDFS Web UI**，查看HDFS 中的文件等信息 [http://localhost:50070/](http://localhost:50070/)

* Datanodes: 查看各个Datanode 节点的磁盘占用、块等信息
* Datanode Volume Failures
* Snapshot
* Startup Progress
* [http://localhost:50070/explorer.html](http://localhost:50070/explorer.html) 查看HDFS 中的文件信息

**Spark Web UI**，查看特定的Spark Job 信息 [http://localhost:4040/jobs/](http://localhost:4040/jobs/)

**HBase Web UI**，查看HBase Master 信息、HBase 表信息等 [http://localhost:16010/](http://localhost:16010/)

* Home: 查看基础的内存、存储、副本信息；查看表的信息
* Table Details: 查看详细的表信息
* Procedures & Locks
* HBCK Report
* Process Metrics: 查看HBase 集群的线程、GC 信息
* Local Logs: 查看HBase 集群的日志信息
* Log Level: 设置日志级别
* Debug Dump: 查看HBase 集群内部的线程Dump 信息
* Metrics Dump
* Profiler: 
* HBase Configuration: 查看HBase 的XML 配置信息

**HiveServer2 Web UI**，查看HiveServer2 日志等信息 [http://localhost:10002/](http://localhost:10002/)

* Home: 当前存活的会话、执行过的SQL 执行情况
* Local logs: 查看HiveServer2 的日志
* Metrics Dump
* Hive Configuration: 查看HiveServer2 的配置信息，hive-site.xml
* Stack Trace: 查看各线程的调用栈信息
* Llap Daemons
