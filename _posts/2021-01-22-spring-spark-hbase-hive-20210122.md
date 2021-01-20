---
layout: post
title: Hive 应用：Spring => SparkSQL => Hive => HBase
categories: 大数据之hadoop 大数据之hbase 大数据之hive 大数据之spark
tags: Java 大数据 Hadoop HDFS Hive 数据仓库 分布式 HBase Spring SQL SparkSQL
---

有这样一个需求场景，数据存储在HBase 中，希望所有针对数据的统计、处理不是直接传统地开发一个Spark 项目，而是在Spring 项目中调用Spark SQL 的方式实现聚合、统计的功能，这样的的话很多功能都可以基于Spring 来做了，比单独开发一个Spark 应用要可扩展性强一些

