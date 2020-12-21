---
layout: post
title: Spark 计算框架：RDD 行动算子
categories: 大数据之kafka 大数据之spark
tags: scala java 大数据 kafka spark MacOS 环境搭建 Scala Maven Hadoop SQL 算子 数据分析 groupBy filter distinct coalesce shuffle 数据倾斜 分区 分组 聚合 关系型数据库 行动算子 转换算子 Driver Executor 闭包 序列化 
---

上一篇中讲到的转换算子都是得到新的RDD，而行动算子触发作业的执行！

collect() 就是一个典型的行动算，collect 算子会将不同分区的数据按照分区顺序采集到Driver 端内存中，形成数组。先看一下collect() 的代码实现

```scala
/**
 * Return an array that contains all of the elements in this RDD.
 *
 * @note This method should only be used if the resulting array is expected to be small, as
 * all the data is loaded into the driver's memory.
 */
def collect(): Array[T] = withScope {
  val results = sc.runJob(this, (iter: Iterator[T]) => iter.toArray)
  Array.concat(results: _*)
}


/**
 * Run a job on all partitions in an RDD and return the results in an array.
 *
 * @param rdd target RDD to run tasks on
 * @param func a function to run on each partition of the RDD
 * @return in-memory collection with a result of the job (each collection element will contain
 * a result from one partition)
 */
def runJob[T, U: ClassTag](rdd: RDD[T], func: Iterator[T] => U): Array[U] = {
  runJob(rdd, func, 0 until rdd.partitions.length)
}


/**
 * Run a function on a given set of partitions in an RDD and return the results as an array.
 *
 * @param rdd target RDD to run tasks on
 * @param func a function to run on each partition of the RDD
 * @param partitions set of partitions to run on; some jobs may not want to compute on all
 * partitions of the target RDD, e.g. for operations like `first()`
 * @return in-memory collection with a result of the job (each collection element will contain
 * a result from one partition)
 */
def runJob[T, U: ClassTag](
    rdd: RDD[T],
    func: Iterator[T] => U,
    partitions: Seq[Int]): Array[U] = {
  val cleanedFunc = clean(func)
  runJob(rdd, (ctx: TaskContext, it: Iterator[T]) => cleanedFunc(it), partitions)
}


/**
 * Run a function on a given set of partitions in an RDD and return the results as an array.
 * The function that is run against each partition additionally takes `TaskContext` argument.
 *
 * @param rdd target RDD to run tasks on
 * @param func a function to run on each partition of the RDD
 * @param partitions set of partitions to run on; some jobs may not want to compute on all
 * partitions of the target RDD, e.g. for operations like `first()`
 * @return in-memory collection with a result of the job (each collection element will contain
 * a result from one partition)
 */
def runJob[T, U: ClassTag](
    rdd: RDD[T],
    func: (TaskContext, Iterator[T]) => U,
    partitions: Seq[Int]): Array[U] = {
  val results = new Array[U](partitions.size)
  runJob[T, U](rdd, func, partitions, (index, res) => results(index) = res)
  results
}


/**
 * Run a function on a given set of partitions in an RDD and pass the results to the given
 * handler function. This is the main entry point for all actions in Spark.
 *
 * @param rdd target RDD to run tasks on
 * @param func a function to run on each partition of the RDD
 * @param partitions set of partitions to run on; some jobs may not want to compute on all
 * partitions of the target RDD, e.g. for operations like `first()`
 * @param resultHandler callback to pass each result to
 */
def runJob[T, U: ClassTag](
    rdd: RDD[T],
    func: (TaskContext, Iterator[T]) => U,
    partitions: Seq[Int],
    resultHandler: (Int, U) => Unit): Unit = {
  if (stopped.get()) {
    throw new IllegalStateException("SparkContext has been shutdown")
  }
  val callSite = getCallSite
  val cleanedFunc = clean(func)
  logInfo("Starting job: " + callSite.shortForm)
  if (conf.getBoolean("spark.logLineage", false)) {
    logInfo("RDD's recursive dependencies:\n" + rdd.toDebugString)
  }

  // 最后触发有向无环图调度器的执行
  dagScheduler.runJob(rdd, cleanedFunc, partitions, callSite, resultHandler, localProperties.get)
  progressBar.foreach(_.finishAll())
  rdd.doCheckpoint()
}
```

最后触发**有向无环图**调度器的执行！！

## reduce算子

聚合功能。聚集 RDD 中的所有元素，先聚合分区内数据，再聚合分区间数据

```scala
val rdd: RDD[Int] = sc.makeRDD(List(1,2,3,4))

// 聚合数据
val reduceResult: Int = rdd.reduce(_+_)
```

## count算子

返回 RDD 中元素的个数

```scala
val rdd: RDD[Int] = sc.makeRDD(List(1,2,3,4))

// 返回 RDD 中元素的个数
val countResult: Long = rdd.count()
```

## first算子

返回 RDD 中的第一个元素

```scala
val rdd: RDD[Int] = sc.makeRDD(List(1,2,3,4))

// 返回 RDD 中元素的个数
val firstResult: Int = rdd.first()
println(firstResult)
```

## take算子

返回一个由 RDD 的前 n 个元素组成的数组

```scala
val rdd: RDD[Int] = sc.makeRDD(List(1,2,3,4))

// 返回 RDD 中元素的个数
val takeResult: Array[Int] = rdd.take(2)
println(takeResult.mkString(","))
```

## takeOrdered算子

返回该 RDD 排序后的前 n 个元素组成的数组

```scala
val rdd: RDD[Int] = sc.makeRDD(List(1,3,2,4))

// 返回该 RDD 排序后的前 n 个元素组成的数组
val result: Array[Int] = rdd.takeOrdered(2)
```

## [aggregate算子](https://www.bilibili.com/video/BV11A411L7CK?p=84)

分区的数据通过初始值和分区内的数据进行聚合，然后再和初始值进行分区间的数据聚合

```scala
val rdd: RDD[Int] = sc.makeRDD(List(1, 2, 3, 4), 8)

// 将该 RDD 所有元素相加得到结果
//val result: Int = rdd.aggregate(0)(_ + _, _ + _)
val result: Int = rdd.aggregate(10)(_ + _, _ + _)
```

和aggregateByKey 的区别？首先aggregate 是行动算子，而aggregateByKey 是转换算子。还有一个主要的区别...

## flod算子

折叠操作，aggregate 的简化版操作

```scala
val rdd: RDD[Int] = sc.makeRDD(List(1, 2, 3, 4))

val foldResult: Int = rdd.fold(0)(_+_)
```

## countByKey 算子

统计每种 key 的个数

```scala
val rdd: RDD[(Int, String)] = sc.makeRDD(List((1, "a"), (1, "a"), (1, "a"), (2, "b"), (3, "c"), (3, "c")))

// 统计每种 key 的个数
val result: collection.Map[Int, Long] = rdd.countByKey()
```

## save相关算子

将数据保存到不同格式的文件中

```scala
// 保存成 Text 文件
rdd.saveAsTextFile("output")

// 序列化成对象保存到文件
rdd.saveAsObjectFile("output1")

// 保存成 Sequencefile 文件
rdd.map((_,1)).saveAsSequenceFile("output2")
```

## 实现wordCount 的各种方式

```scala
import org.apache.spark.rdd.RDD
import org.apache.spark.{SparkConf, SparkContext}

import scala.collection.mutable

object SparkWordCount {
    def main(args: Array[String]): Unit = {

        val sparConf = new SparkConf().setMaster("local").setAppName("WordCount")
        val sc = new SparkContext(sparConf)

        wordcount91011(sc)

        sc.stop()

    }

    // groupBy
    def wordcount1(sc : SparkContext): Unit = {
        val rdd = sc.makeRDD(List("Hello Scala", "Hello Spark"))
        val words = rdd.flatMap(_.split(" "))
        val group: RDD[(String, Iterable[String])] = words.groupBy(word=>word)
        val wordCount: RDD[(String, Int)] = group.mapValues(iter=>iter.size)
    }

    // groupByKey
    def wordcount2(sc : SparkContext): Unit = {
        val rdd = sc.makeRDD(List("Hello Scala", "Hello Spark"))
        val words = rdd.flatMap(_.split(" "))
        val wordOne = words.map((_,1))
        val group: RDD[(String, Iterable[Int])] = wordOne.groupByKey()
        val wordCount: RDD[(String, Int)] = group.mapValues(iter=>iter.size)
    }

    // reduceByKey
    def wordcount3(sc : SparkContext): Unit = {
        val rdd = sc.makeRDD(List("Hello Scala", "Hello Spark"))
        val words = rdd.flatMap(_.split(" "))
        val wordOne = words.map((_,1))
        val wordCount: RDD[(String, Int)] = wordOne.reduceByKey(_+_)
    }

    // aggregateByKey
    def wordcount4(sc : SparkContext): Unit = {
        val rdd = sc.makeRDD(List("Hello Scala", "Hello Spark"))
        val words = rdd.flatMap(_.split(" "))
        val wordOne = words.map((_,1))
        val wordCount: RDD[(String, Int)] = wordOne.aggregateByKey(0)(_+_, _+_)
    }

    // foldByKey
    def wordcount5(sc : SparkContext): Unit = {
        val rdd = sc.makeRDD(List("Hello Scala", "Hello Spark"))
        val words = rdd.flatMap(_.split(" "))
        val wordOne = words.map((_,1))
        val wordCount: RDD[(String, Int)] = wordOne.foldByKey(0)(_+_)
    }

    // combineByKey
    def wordcount6(sc : SparkContext): Unit = {
        val rdd = sc.makeRDD(List("Hello Scala", "Hello Spark"))
        val words = rdd.flatMap(_.split(" "))
        val wordOne = words.map((_,1))
        val wordCount: RDD[(String, Int)] = wordOne.combineByKey(
            v=>v,
            (x:Int, y) => x + y,
            (x:Int, y:Int) => x + y
        )
    }

    // countByKey
    def wordcount7(sc : SparkContext): Unit = {
        val rdd = sc.makeRDD(List("Hello Scala", "Hello Spark"))
        val words = rdd.flatMap(_.split(" "))
        val wordOne = words.map((_,1))
        val wordCount: collection.Map[String, Long] = wordOne.countByKey()
    }

    // countByValue
    def wordcount8(sc : SparkContext): Unit = {
        val rdd = sc.makeRDD(List("Hello Scala", "Hello Spark"))
        val words = rdd.flatMap(_.split(" "))
        val wordCount: collection.Map[String, Long] = words.countByValue()
    }

    // reduce, aggregate, fold
    def wordcount91011(sc : SparkContext): Unit = {
        val rdd = sc.makeRDD(List("Hello Scala", "Hello Spark"))
        val words = rdd.flatMap(_.split(" "))

        // 【（word, count）,(word, count)】
        // word => Map[(word,1)]
        val mapWord = words.map(
            word => {
                mutable.Map[String, Long]((word,1))
            }
        )

       val wordCount = mapWord.reduce(
            (map1, map2) => {
                map2.foreach{
                    case (word, count) => {
                        val newCount = map1.getOrElse(word, 0L) + count
                        map1.update(word, newCount)
                    }
                }
                map1
            }
        )

        println(wordCount)
    }

}
```

## [foreach算子](https://www.bilibili.com/video/BV11A411L7CK?p=89)

分布式遍历 RDD 中的每一个元素，调用指定函数

```scala
val rdd = sc.makeRDD(List(1,2,3,4), 2)

// 先采集再循环
// collect 算子会将不同分区的数据按照分区顺序采集到Driver 端内存中，形成数组
// 这个println 是在Driver 端执行的操作
println("rdd.collect().foreach(println)");
rdd.collect().foreach(println)

// 没有顺序的概念，这个println 其实是在Executor 端执行的操作
// 分布式执行相关逻辑，因为是分布式执行所以是没有办法控制顺序！
println("rdd.foreach(println)")
rdd.foreach(println)
```

为什么称为算子？因为RDD 的方法（算子）和Scala 集合对象的方法不一样。集合对象的方法都是在同一个节点的内存中完成的。而RDD 的方法是可以将计算逻辑发送到Executor 分布式执行的！！

为了区分，所以称RDD 的方法为算子！

RDD 的方法外部的操作都是在Driver 端执行的，而方法内部的逻辑代码都是在Executor 端执行的

```scala
// 这个println 方法是RDD.foreach() 算子的外部操作，在Driver 执行
println("rdd.foreach(println)")

// 这个println 方法是RDD.foreach() 算子的内部操作，在Executor 执行
rdd.foreach(println)
```

## [闭包与序列化](https://www.bilibili.com/video/BV11A411L7CK?p=89)

从计算的角度, 算子以外的代码都是在Driver 端执行, 算子里面的代码都是在Executor 端执行。那么在Scala 的函数式编程中，就会导致算子内经常会用到算子外的数据，这样就形成了闭包的效果，如果使用的算子外的数据无法序列化，就意味着无法传值给Executor 端执行，就会发生错误，所以需要在执行任务计算前，检测闭包内的对象是否可以进行序列化，这个操作我们称之为闭包检测

从计算的角度, 算子以外的代码都是在 Driver 端执行, 算子里面的代码都是在 Executor端执行，比如

```scala
object serializable02_function {
 
    def main(args: Array[String]): Unit = {
        //1.创建 SparkConf 并设置 App 名称
        val conf: SparkConf = new SparkConf().setAppName("SparkCoreTest").setMaster("local[*]")

        //2.创建 SparkContext，该对象是提交 Spark App 的入口
        val sc: SparkContext = new SparkContext(conf)

        //3.创建一个 RDD
        val rdd: RDD[String] = sc.makeRDD(Array("hello world", "hello spark", "hive", "atguigu"))

        //3.1 创建一个 Search 对象
        val search = new Search("hello")

        //3.2 函数传递，打印：ERROR Task not serializable
        search.getMatch1(rdd).collect().foreach(println)

        //3.3 属性传递，打印：ERROR Task not serializable
        search.getMatch2(rdd).collect().foreach(println)

        //4.关闭连接
        sc.stop()
    } 
}

class Search(query:String) extends Serializable {
    def isMatch(s: String): Boolean = {
        s.contains(query)
    }

    // 函数序列化案例
    def getMatch1 (rdd: RDD[String]): RDD[String] = {
        //rdd.filter(this.isMatch)
        rdd.filter(isMatch)
    }

    // 属性序列化案例
    def getMatch2(rdd: RDD[String]): RDD[String] = {
        //rdd.filter(x => x.contains(this.query))
        rdd.filter(x => x.contains(query))
        //val q = query
        //rdd.filter(x => x.contains(q))
    } 
}
```
