---
layout: post
title: 大数据应用：Hive on MapReduce 简单性能测试
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

>[Hive性能调优工具](https://zhuanlan.zhihu.com/p/334438403)

## analyze 表信息分析

analyze 语句可以收集一些详细的统计信息，比如表的行数、文件数、数据的大小等信息。这些统计信息作为元数据存储在hive 的元数据库中

收集表的统计信息(非分区表)，当指定NOSCAN关键字时，会忽略扫描文件内容，仅仅统计文件的数量与大小，速度会比较快

```sql
ANALYZE TABLE 表名 COMPUTE STATISTICS; 
ANALYZE TABLE 表名 COMPUTE STATISTICS NOSCAN;
```

收集分区表的统计信息

```sql
ANALYZE TABLE 表名 PARTITION(分区1，分区2) COMPUTE STATISTICS;
```

收集指定分区信息

```sql
ANALYZE TABLE 表名 PARTITION(分区1='xxx'，分区2='yyy') COMPUTE STATISTICS;
```

收集表的某个字段的统计信息

```sql
ANALYZE TABLE 表名 COMPUTE STATISTICS FOR COLUMNS 字段名 ; 
```

## explain 执行计划分析

在hive 命令行中可以通过explain 命令分析SQL 的执行计划（和MySQL 的explain 类似！）

```sql
hive > explain select benchtest1.id, benchtest1.status, benchtest1.ext from benchtest1, benchtest2 where benchtest1.id = benchtest2.id and benchtest1.status != benchtest2.status;
OK
STAGE DEPENDENCIES:
  Stage-4 is a root stage
  Stage-3 depends on stages: Stage-4
  Stage-0 depends on stages: Stage-3

STAGE PLANS:
  Stage: Stage-4
    Map Reduce Local Work
      Alias -> Map Local Tables:
        $hdt$_0:benchtest1 
          Fetch Operator
            limit: -1
      Alias -> Map Local Operator Tree:
        $hdt$_0:benchtest1 
          TableScan
            alias: benchtest1
            Statistics: Num rows: 4 Data size: 1206 Basic stats: COMPLETE Column stats: NONE
            Filter Operator
              predicate: id is not null (type: boolean)
              Statistics: Num rows: 4 Data size: 1206 Basic stats: COMPLETE Column stats: NONE
              Select Operator
                expressions: id (type: string), status (type: string), ext (type: string)
                outputColumnNames: _col0, _col1, _col2
                Statistics: Num rows: 4 Data size: 1206 Basic stats: COMPLETE Column stats: NONE
                HashTable Sink Operator
                  keys:
                    0 _col0 (type: string)
                    1 _col0 (type: string)

  Stage: Stage-3
    Map Reduce
      Map Operator Tree:
          TableScan
            alias: benchtest2
            Statistics: Num rows: 1 Data size: 0 Basic stats: PARTIAL Column stats: NONE
            Filter Operator
              predicate: id is not null (type: boolean)
              Statistics: Num rows: 1 Data size: 0 Basic stats: PARTIAL Column stats: NONE
              Select Operator
                expressions: id (type: string), status (type: string)
                outputColumnNames: _col0, _col1
                Statistics: Num rows: 1 Data size: 0 Basic stats: PARTIAL Column stats: NONE
                Map Join Operator
                  condition map:
                       Inner Join 0 to 1
                  keys:
                    0 _col0 (type: string)
                    1 _col0 (type: string)
                  outputColumnNames: _col0, _col1, _col2, _col4
                  Statistics: Num rows: 4 Data size: 1326 Basic stats: COMPLETE Column stats: NONE
                  Filter Operator
                    predicate: (_col1 <> _col4) (type: boolean)
                    Statistics: Num rows: 4 Data size: 1326 Basic stats: COMPLETE Column stats: NONE
                    Select Operator
                      expressions: _col0 (type: string), _col1 (type: string), _col2 (type: string)
                      outputColumnNames: _col0, _col1, _col2
                      Statistics: Num rows: 4 Data size: 1326 Basic stats: COMPLETE Column stats: NONE
                      File Output Operator
                        compressed: false
                        Statistics: Num rows: 4 Data size: 1326 Basic stats: COMPLETE Column stats: NONE
                        table:
                            input format: org.apache.hadoop.mapred.SequenceFileInputFormat
                            output format: org.apache.hadoop.hive.ql.io.HiveSequenceFileOutputFormat
                            serde: org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe
      Local Work:
        Map Reduce Local Work

  Stage: Stage-0
    Fetch Operator
      limit: -1
      Processor Tree:
        ListSink
```

>如果使用Spark 作为执行引擎呢，SQL 的执行性能会快多少？

>[https://amplab.cs.berkeley.edu/benchmark/](https://amplab.cs.berkeley.edu/benchmark/)
