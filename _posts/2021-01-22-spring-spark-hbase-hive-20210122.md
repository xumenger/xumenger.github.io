---
layout: post
title: Hive 应用：Hive on MapReduce 简单性能测试
categories: 大数据之hadoop 大数据之hbase 大数据之hive 大数据之spark
tags: Java 大数据 Hadoop HDFS Hive 数据仓库 分布式 HBase Spring SQL SparkSQL top CPU 
---

Hive 默认是将SQL 编译为MapReduce 任务然后执行的，那么这里简单测试在百万级别的数据量的情况下，Hive 聚合统计、单笔查询的性能

在单机上进行如下测试，正常情况下机器的内存、CPU 占用如下（top 命令查看）

![](../media/image/2021-01-22/01.png)

当前机器的剩余存储空间是42.45 G

![](../media/image/2021-01-22/02.png)

首先在Hive 的testbase 数据库下创建测试需要的数据库

```sql
use testbase;
create table benchtest1(id string, status string, ext string);
create table benchtest2(id string, status string, ext string);
```

insert into benchtest1 values ('1', 'S', 'something')

补充，可以用下面的SQL 删除数据，并保存表结构

```sql
truncate table benchtest1;
truncate table benchtest2;
```

然后使用Java 编写测试程序，构造100 万条测试数据

```java
package com.xum.demo14.hive.bench;

import java.util.List;
import java.util.Map;

import org.apache.tomcat.jdbc.pool.DataSource;
import org.springframework.jdbc.core.JdbcTemplate;

public class Application {

	public static void main(String args[])
	{
		DataSource dataSource = new DataSource();
        dataSource.setUrl("jdbc:hive2://localhost:10000/testbase");
        dataSource.setDriverClassName("org.apache.hive.jdbc.HiveDriver");
        dataSource.setUsername("");
        dataSource.setPassword("");
        
        JdbcTemplate jdbcTemplate = new JdbcTemplate(dataSource);
        
        // 一共构造total 条测试数据，第diff 条的的status 字段的值不一致
        int total = 10000;
        int diff = 500;
        
        Long mark1 = System.currentTimeMillis();
        System.err.println(String.format("准备%d 条测试数据 ==> benchtest1", total));
        for (int i = 1; i<= total; i++) {
        	String sql = "";
        	if (i != diff) {
        		sql = String.format("insert into benchtest1 values ('%d', 'S', 'something')", i);
        	} else {
        	    sql = String.format("insert into benchtest1 values ('%d', 'F', 'something')", i);
        	}
        	jdbcTemplate.update(sql);
        }
        Long mark2 = System.currentTimeMillis();
        System.err.println("一共耗时: " + (mark2 - mark1) + "ms");
	}
}
```

这种方案不考虑，每个insert 的耗时都要几秒钟的时间，如果想要构造几万、几十万、几百万条数据，用这种方式，要到天荒地老去了！

必须明确的是，把每条数据处理成insert 语句的方式，肯定是最低效的，不管是在MySQL 中，还是在分布式组件Hive 中。这种方式的资源消耗，更多的花在了连接、SQL 语句的解析、执行计划生成上，实际插入数据的开销还是相对较少的



执行的结果如下

![](../media/image/2021-01-22/03.png)

此时机器的磁盘剩余空间是

![](../media/image/2021-01-22/04.png)

>如果使用Spark 作为执行引擎呢，SQL 的执行性能会快多少？

>[https://amplab.cs.berkeley.edu/benchmark/](https://amplab.cs.berkeley.edu/benchmark/)
