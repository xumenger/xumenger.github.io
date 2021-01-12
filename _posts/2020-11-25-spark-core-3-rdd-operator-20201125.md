---
layout: post
title: Spark 计算框架：RDD 转换算子
categories: 大数据之kafka 大数据之spark
tags: scala java 大数据 kafka spark MacOS 环境搭建 Scala Maven Hadoop SQL 算子 数据分析 groupBy filter distinct coalesce shuffle 数据倾斜 分区 分组 聚合 关系型数据库 
---

---

>单值算子

## map算子

将处理的数据逐条进行映射转换，可以是类型的转换，也可以是值的转换

```scala
val dataRDD: RDD[Int] = sparkContext.makeRDD(List(1,2,3,4))
val dataRDD1: RDD[Int] = dataRDD.map(
    num => {
        num * 2
    } 
)
val dataRDD2: RDD[String] = dataRDD1.map(
    num => {
        "" + num
    }
)
```

## mapPartitions算子

将待处理的数据以分区为单位发送到计算节点进行处理，这里的处理是指可以进行任意的处理

```scala
val dataRDD1: RDD[Int] = dataRDD.mapPartitions(
    datas => {
        datas.filter(_==2)
    } 
)
```

map 算子是分区内一个数据一个数据的执行，类似于串行操作。而mapPartitions 算子是以分区为单位进行批处理操作

map 算子主要目的将数据源中的数据进行转换和改变。但是不会减少或增多数据。MapPartitions 算子需要传递一个迭代器，返回一个迭代器，没有要求的元素的个数保持不变，所以可以增加或减少数据

map 算子因为类似于串行操作，所以性能比较低，而是mapPartitions 算子类似于批处理，所以性能较高。但是mapPartitions 算子会长时间占用内存，那么这样会导致内存可能不够用，出现内存溢出的错误。所以在内存有限的情况下，不推荐使用。使用map 操作

## mapPartitionsWithIndex算子

将待处理的数据以分区为单位发送到计算节点进行处理，这里的处理是指可以进行任意的处理，在处理时同时可以获取当前分区索引

```scala
val dataRDD1 = dataRDD.mapPartitionsWithIndex( 
    (index, datas) => {
        datas.map(index, _)
    }
)
```

## flatMap算子

将处理的数据进行扁平化后再进行映射处理，也叫做扁平映射

```scala
val dataRDD = sparkContext.makeRDD(List(
    List(1,2),List(3,4)
),1)

val dataRDD1 = dataRDD.flatMap(
    list => list
)
```

## glom算子

将同一个分区的数据直接转换为相同类型的内存数组进行处理，分区不变

```scala
val dataRDD = sparkContext.makeRDD(List(
    1,2,3,4
),1)

val dataRDD1:RDD[Array[Int]] = dataRDD.glom()
```

## groupBy算子

将数据根据指定的规则进行分组, 分区默认不变，但是数据会被打乱重新组合，我们将这样的操作称之为 shuffle。极限情况下，数据可能被分在同一个分区中一个组的数据在一个分区中，但是并不是说一个分区中只有一个组

```scala
val dataRDD = sparkContext.makeRDD(List(1,2,3,4),2)

val dataRDD1 = dataRDD.groupBy(
    _%2
)
```

比如可以用来从服务器日志数据 apache.log 中获取每个时间段访问量

## filter算子

将数据根据指定的规则进行筛选过滤，符合规则的数据保留，不符合规则的数据丢弃。当数据进行筛选过滤后，分区不变，但是分区内的数据可能不均衡，生产环境下，可能会出现数据倾斜

计算规则是对每个分区做计算的：按照一定条件过滤，可能存在分区1剩下1条，分区2剩下10000条，这个称为数据倾斜

使用filter从服务器日志数据apache.log 中获取2015年5月17日的请求路径

```scala
val rdd = sc.textFile("datas/apache.log")
rdd.filter(
    line => {
        val datas = line.split(" ")
        val time = datas(3)
        time.startsWith("17/05/2015")
    }
).collect().foreach(println)
```

可以用sample算子来协助解决数据倾斜

```scala
val dataRDD = sparkContext.makeRDD(List(
    1,2,3,4
),1)

// 抽取数据不放回（伯努利算法）
// 伯努利算法：又叫 0、1 分布。例如扔硬币，要么正面，要么反面。
// 具体实现：根据种子和随机算法算出一个数和第二个参数设置几率比较，小于第二个参数要，大于不要
// 第一个参数：抽取的数据是否放回，false：不放回
// 第二个参数：抽取的几率，范围在[0,1]之间,0：全不取；1：全取；
// 第三个参数：随机数种子
val dataRDD1 = dataRDD.sample(false, 0.5)

// 抽取数据放回（泊松算法）
// 第一个参数：抽取的数据是否放回，true：放回；false：不放回
// 第二个参数：重复数据的几率，范围大于等于 0.表示每一个元素被期望抽取到的次数
// 第三个参数：随机数种子
val dataRDD2 = dataRDD.sample(true, 2)
```

## distinct算子

```scala
val dataRDD = sparkContext.makeRDD(List(
    1,2,3,4,1,2
),1)

val dataRDD1 = dataRDD.distinct()

val dataRDD2 = dataRDD.distinct(2)
```

Scala 中集合的distinct 去重是使用HashSet 实现的。而在Spark 中，数据分布在不同的分区中，如何实现去重？

```scala
  /**
   * Return a new RDD containing the distinct elements in this RDD.
   */
  def distinct(numPartitions: Int)(implicit ord: Ordering[T] = null): RDD[T] = withScope {
    def removeDuplicatesInPartition(partition: Iterator[T]): Iterator[T] = {
      // Create an instance of external append only map which ignores values.
      val map = new ExternalAppendOnlyMap[T, Null, Null](
        createCombiner = _ => null,
        mergeValue = (a, b) => a,
        mergeCombiners = (a, b) => a)
      map.insertAll(partition.map(_ -> null))
      map.iterator.map(_._1)
    }
    partitioner match {
      case Some(_) if numPartitions == partitions.length =>
        mapPartitions(removeDuplicatesInPartition, preservesPartitioning = true)
      case _ => map(x => (x, null)).reduceByKey((x, _) => x, numPartitions).map(_._1)
    }
  }
```

分布式的处理方式来实现去重。通过这个算子帮助理解单机模式下实现逻辑是如何设计算法与数据结构的；对比分布式计算模型下是如何设计算法与数据结构的！！！

## coalesce算子

根据数据量缩减分区，用于大数据集过滤后，提高小数据集的执行效率

当Spark 程序中，存在过多的小任务时，可以通过coalesce 算子，收缩合并分区，减少分区的个数，减小任务调度成本

```scala
val dataRDD = sparkContext.makeRDD(List(
    1,2,3,4,1,2
),6)

val dataRDD1 = dataRDD.coalesce(2)
```

但这个算子缩减分区可能导致数据不均衡，如果想要数据均衡，则进行shuffle 处理，即该算子的第二个参数设置为true

比如可能发现分区太少了，每个分区的数据量太大，就想要扩大分区，使每个分区中的数据量稍微少一些。分区数变多后，也可以增强并行计算的能力

coalesce 算子也可以扩大分区，此时shuffle 参数必须指定为true！要打乱数据然后重新组合！

扩大分区也有一个专门的算子：repartition，其底层就是调用coalesce

```scala
  /**
   * Return a new RDD that has exactly numPartitions partitions.
   *
   * Can increase or decrease the level of parallelism in this RDD. Internally, this uses
   * a shuffle to redistribute data.
   *
   * If you are decreasing the number of partitions in this RDD, consider using `coalesce`,
   * which can avoid performing a shuffle.
   */
  def repartition(numPartitions: Int)(implicit ord: Ordering[T] = null): RDD[T] = withScope {
    coalesce(numPartitions, shuffle = true)
  }
```

## sortBy算子

```scala
val rdd = sc.makeRDD(List(("1", 1), ("2", 2), ("22", 3), (4", 4)))

// 按照键值降序排序
val newRDD = rdd.sortBy(t => t._1, false)

newRDD.saveAsTextFile("output")
```

排序前后，分区数不变，但因为做了排序，数据可能从原来的分区放到其他的分区，底层会有shuffle 操作

----

>双值算子

## 集合运算

intersection 对源 RDD 和参数 RDD 求交集后返回一个新的 RDD

union 对源 RDD 和参数 RDD 求并集后返回一个新的 RDD

subtract 以一个 RDD 元素为主，去除两个 RDD 中重复元素，将其他元素保留下来。求差集

```scala
val rdd1 = sc.makeRDD(List(1, 2, 3, 4))
val rdd2 = sc.makeRDD(List(3, 4, 5, 6))

// 交集
val rdd3 = rdd1.intersection(rdd2)
println(rdd3.collect().mkString(","))

// 并集
val rdd4 = rdd1.union(rdd2)
println(rdd4.collect().mkString(","))

// 差集
val rdd5 = rdd1.subtract(rdd2)
println(rdd5.collect().mkString(","))

// 前面三个如果两个RDD 的数据类型不一致，编译报错！
// 拉链算子，可以处理两个数据类型不一致的RDD，但是要求两个RDD 的分区数一致！每一个分区的数据量也要一致！
val rdd6 = rdd1.zip(rdd2)
println(rdd6.collect().mkString(","))
// (1,3),(2,4),(3,5),(4,6)
```

## zip 算子

将两个 RDD 中的元素，以键值对的形式进行合并。其中，键值对中的 Key 为第 1 个 RDD中的元素，Value 为第 2 个 RDD 中的相同位置的元素

```scala
val dataRDD1 = sparkContext.makeRDD(List(1,2,3,4))
val dataRDD2 = sparkContext.makeRDD(List(3,4,5,6))
val dataRDD = dataRDD1.zip(dataRDD2)
```

思考一个问题：如果两个 RDD 数据类型不一致怎么办？

思考一个问题：如果两个 RDD 数据分区不一致怎么办？

思考一个问题：如果两个 RDD 分区数据数量不一致怎么办？

---

>键值对类型算子

## partitionBy算子处理键值对

将数据按照指定 Partitioner 重新进行分区。Spark 默认的分区器是 HashPartitioner

```scala
val rdd = sc.makeRDD(List(1, 2, 3, 4))

// 转换成tuple 类型
val mapRDD : RDD[(Int, Int)] = rdd.map((_, 1))

// 隐式转换：RDD => PairRDDFunctions
// 根据指定的分区规则，对数据进行重分区
val newRDD = rdd.partitionBy(new HashPartitioner(2))
```

partitionBy() 是PairRDDFunctions 中的一个方法，不是RDD 的算子！因为RDD 中有一个方法

```scala
  implicit def rddToPairRDDFunctions[K, V](rdd: RDD[(K, V)])
    (implicit kt: ClassTag[K], vt: ClassTag[V], ord: Ordering[K] = null): PairRDDFunctions[K, V] = {
    new PairRDDFunctions(rdd)
  }
```

>扩展内容：分区器！当然也可以自己实现一个分区器！

## reduceByKey算子

可以将数据按照相同的 Key 对 Value 进行聚合

```scala
val rdd = sc.makeRDD(List(("a", 1), ("a", 2), ("b", 4)))

// reduceByKey 相同key 的数据进行value 的聚合
val reduceDD = rdd.reduceByKey((x:Int, y:Int) => {x + y})
```

## groupByKey算子

将数据源的数据根据key 对value 进行分组

```scala
val rdd = sc.makeRDD(List(("a", 1), ("a", 2), ("b", 4)))

// groupByKey 相同key 的数据分在一个组中，形成一个对偶元组
// 对偶元组中的第一个元素是key，第二个元素是相同的key的value的集合
val groupRDD : RDD[(String, Iterable[Int])] = rdd.groupByKey()
```

![](../media/image/2020-11-25-3/01.png)

如果groupByKey 会导致数据打乱重组，存在shuffle 操作。这个图中例子刚好分区和分组都是两个，但是还是不要把分区和分组搞混了！

分区之间可以并行计算的依据就是数据之间没有关系，不需要互相依赖，可以按照自己的逻辑专心处理当前分区

但是如上图如果先使用groupByKey 对数据进行分组，然后再在分组的基础上使用map 进行聚合，那么当处理完其中一个分区后，还要等待另一个分区处理完才能进行map 聚合，因为假如按照键值聚合，另外一个分区中可能也有这个键值的数据，但是当分区很多、数据很多的时候，要花多长时间等待，这些都是不确定的！严重影响分布式计算！那么这个在等待的Executor 的内存在等待的时间里就可能越积越多！

所以在Spark 中对于shuffle 操作必须先落到磁盘，不能在内存中数据等待！显然就会因为磁盘IO 影响性能，所以shuffle 的性能肯定不高！

![](../media/image/2020-11-25-3/02.png)

在看reduceByKey 的原理，因为要把相同的key 放在一起，所以也一定会有shuffle！另外groupByKey 只有分组没有聚合，如果想要聚合，那么就需要将groupByKey 先分完组得到的RDD 再使用map 算子进行聚合，而reduceByKey 可以同时完成聚合

看起来groupByKey 分组后再map 聚合，和直接reduceByKey 聚合好像没有什么不同，都有shuffle。但其核心区别在于，groupByKey 后再map 聚合，那么必须先完成所有的分组，而reduceByKey 则是两两聚合，所以可以先在原来的RDD 中对各自分区中的数据先两两聚合。在落盘之前先通过两两聚合减少一部分数据（预聚合）！那么落盘的数据量就变少了，后续读取磁盘的数据量也少了，那么耗费在IO 上的时间就相对变少了

![](../media/image/2020-11-25-3/03.png)

但如果只需要分组，不需要聚合，那么就还只能使用groupByKey

## aggregateByKey算子

将数据根据不同的规则进行分区内计算和分区间计算

```scala
val rdd = sc.makeRDD(List(("a", 1), ("a", 2), ("b", 4)), 2)

// aggregateByKey 存在函数柯里化，有两个参数列表
// 第一个参数列表，需要传递一个参数，表示初始值
//             初始值主要用于当碰见第一个key 的时候，和value 进行两两聚合
// 第二个参数列表有两个参数
//             第一个参数表示分区内计算规则
//             第二个参数表示分区件计算规则
// 下面这个实现分区内求最大值，分区间相加
rdd.aggregateByKey(0)(
    (x, y) => math.max(x, y),
    (x, y) => x + y
).collect().foreach(println)


// 获取相同key 的数据的平均值
val newRDD : RDD[(String, (Int, Int))] = rdd.aggregateByKey( (0, 0) )(
    (t, v) => {
        (t._1 + v, t._2 + 1)
    },
    (t1, t2) => {
        (t1._1 + t2._1, t1._2 + t2._2)
    }
)

val resultRDD : RDD[(String, Int)] = newRDD.mapValues{
    case (num, cnt) => {
        num / cnt
    }
}

resultRDD.collect().foreach(println)
```

当分区内计算规则和分区间计算规则相同时，aggregateByKey 就可以简化为 foldByKey

```scala
val dataRDD1 = sparkContext.makeRDD(List(("a",1),("b",2),("c",3)))
val dataRDD2 = dataRDD1.foldByKey(0)(_+_)
```

## combineByKey

>https://www.bilibili.com/video/BV11A411L7CK?p=74

最通用的对 key-value 型 rdd 进行聚集操作的聚集函数（aggregation function）。类似于aggregate()，combineByKey()允许用户返回值的类型与输入不一致

将数据 List(("a", 88), ("b", 95), ("a", 91), ("b", 93), ("a", 95), ("b", 98))求每个 key 的平均值

```scala
val list: List[(String, Int)] = List(("a", 88), ("b", 95), ("a", 91), ("b", 93), ("a", 95), ("b", 98))

val input: RDD[(String, Int)] = sc.makeRDD(list, 2)

val combineRdd: RDD[(String, (Int, Int))] = input.combineByKey(
    (_, 1),
    (acc: (Int, Int), v) => (acc._1 + v, acc._2 + 1),
    (acc1: (Int, Int), acc2: (Int, Int)) => (acc1._1 + acc2._1, acc1._2 + acc2._2)
)
```

reduceByKey: 相同 key 的第一个数据不进行任何计算，分区内和分区间计算规则相同

foldByKey: 相同 key 的第一个数据和初始值进行分区内计算，分区内和分区间计算规则相同

aggregateByKey: 相同 key 的第一个数据和初始值进行分区内计算，分区内和分区间计算规则可以不相同

combineByKey: 当计算时，发现数据结构不满足要求时，可以让第一个数据转换结构。分区内和分区间计算规则不相同

## sortByKey算子

在一个(K,V)的 RDD 上调用，K 必须实现 Ordered 接口(特质)，返回一个按照 key 进行排序的RDD

```scala
val dataRDD1 = sparkContext.makeRDD(List(("a",1),("b",2),("c",3)))
val sortRDD1: RDD[(String, Int)] = dataRDD1.sortByKey(true)
val sortRDD1: RDD[(String, Int)] = dataRDD1.sortByKey(false)
```

## join算子

在类型为(K,V)和(K,W)的RDD 上调用，返回一个相同key 对应的所有元素连接在一起的(K,(V,W)) 的RDD

类似于关系型数据库SQL 中的join 连接

join 算子是内连接！

```scala
val rdd: RDD[(Int, String)] = sc.makeRDD(Array((1, "a"), (2, "b"), (3, "c")))
val rdd1: RDD[(Int, Int)] = sc.makeRDD(Array((1, 4), (2, 5), (3, 6)))
rdd.join(rdd1).collect().foreach(println)
```

## leftOuterJoin/rightOuterJoin

leftOuterJoin/rightOuterJoin 是外连接

```scala
val dataRDD1 = sparkContext.makeRDD(List(("a",1),("b",2),("c",3)))
val dataRDD2 = sparkContext.makeRDD(List(("a",1),("b",2),("c",3)))
val rdd: RDD[(String, (Int, Option[Int]))] = dataRDD1.leftOuterJoin(dataRDD2)
```

## cogroup算子

在类型为(K,V)和(K,W)的 RDD 上调用，返回一个(K,(Iterable<V>,Iterable<W>))类型的 RDD

```scala
val dataRDD1 = sparkContext.makeRDD(List(("a",1),("a",2),("c",3)))
val dataRDD2 = sparkContext.makeRDD(List(("a",1),("c",2),("c",3)))

val value: RDD[(String, (Iterable[Int], Iterable[Int]))] = 

dataRDD1.cogroup(dataRDD2)
```

---

## 简单总结

理解RDD 算子很核心的一个点在于理解分区！

RDD 的这些算子和关系型数据库中的SQL 的很多理念是类似的或者一致的！
