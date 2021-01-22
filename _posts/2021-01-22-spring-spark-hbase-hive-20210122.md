---
layout: post
title: Hive 应用：Hive 性能分析
categories: 大数据之hadoop 大数据之hbase 大数据之hive 大数据之spark
tags: Java 大数据 Hadoop HDFS Hive 数据仓库 分布式 HBase Spring SQL SparkSQL
---

Hive 默认是将SQL 编译为MapReduce 任务然后执行的，那么这里简单测试在百万级别的数据量的情况下，Hive 聚合统计、单笔查询的性能

## 测试数据构造

编写一个简单的Java 程序，往Hive 中添加500 万条数据

```java

```

## 关联查询测试



## 单条查询测试



>如果使用Spark 作为执行引擎呢，SQL 的执行性能会快多少？