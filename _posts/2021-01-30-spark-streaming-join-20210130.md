---
layout: post
title: 源码面前了无秘密【Spark】：Spark Streaming join 算子报错
categories: 源码面前了无秘密  
tags: Java Spark SparkStreaming 流处理 join 算子 流式运算 
---

>[https://spark.apache.org/streaming/](https://spark.apache.org/streaming/)

>[http://spark.apache.org/docs/latest/streaming-programming-guide.html](http://spark.apache.org/docs/latest/streaming-programming-guide.html)

最开始是编写了一个SparkStreaming 应用对接两个Kafka 集群Topic，TopicA中是交易的一部分信息，TopicB中是交易的另一部分信息，主键是交易流水，然后在一个时间窗内的两个DStream 按流水号进行join，希望获取完整的交易信息，但是运行起来后，没有拿到关联的结果
 
然后通过编写一个简单的SparkStreaming 程序复现了一下问题
 
```scala
import org.apache.spark.streaming.Seconds
import org.apache.spark.streaming.StreamingContext
import org.apache.spark.SparkConf
import org.apache.spark.rdd.RDD
import scala.collection.mutable.Queue
import org.apache.spark.streaming.dstream.DStream
import java.io.FileWriter
 
object DStreamJoinExample 
{
  def main(args: Array[String]) 
  {
    val sparkConf = new SparkConf().setMaster("local[*]").setAppName("JoinExample")
    val ssc = new StreamingContext(sparkConf, Seconds(20))
    
    // 创建RDD队列
    val rddQueue = new Queue[RDD[String]]()
    
    // 创建QueueInputDStream
    val inputStream : DStream[String] = ssc.queueStream(rddQueue, oneAtATime = false)
    
    // 处理队列中的RDD数据
    val newStream1 : DStream[(String, String)] = inputStream.map(r => {
      (r, "newStream1")
    })
    val newStream2 : DStream[(String, String)] = inputStream.map(r => {
      (r, "newStream2")
    })
    
    // join运算
    val joinStream : DStream[(String, (String, String))] = newStream1.join(newStream1)
    joinStream.foreachRDD(rdd => {
      rdd.foreachPartition(iterator => {
        val array = iterator.toArray
        for (record <- array) {
          println(record)
        }
      })
    })
    
    // 启动任务
    ssc.start()
    
    // 循环往队列中放入RDD
    for (i <- 1 to 1) {
      rddQueue += ssc.sparkContext.makeRDD(List("str" + i, "abc" + i), 1)
      Thread.sleep(100)
    }
    
    ssc.awaitTermination()
  }
}
```
 
同样没有拿到预期的结果，看不出头绪，难道是DStream 的join() 算子和RDD 的算子不同？试着编写一个RDD 的join() 算子的Demo
 
```scala
import org.apache.spark.SparkConf
import org.apache.spark.SparkContext
import org.apache.spark.rdd.RDD
 
object RDDJoinExample 
{
  def main(args: Array[String]) 
  {  
    // 创建Spark 运行配置对象，连接
    val sparkConf = new SparkConf().setMaster("local[*]").setAppName("RDDjoinExample")
    val sparkContext = new SparkContext(sparkConf)
    
    val rdd1: RDD[(Int, String)] = sparkContext.makeRDD(Array((1, "abc1"), (2, "xyz1")), 1)
    val rdd2: RDD[(Int, String)] = sparkContext.makeRDD(Array((1, "abc2"), (2, "xyz2")), 1)
 
    rdd1.join(rdd2).collect().foreach(println)
 
    sparkContext.stop()
  }
}
```
 
同样的，这里也没有拿到预期的结果，仔细看一下标准输出，发现是有报错的，其中重要的异常信息包括这些
 
```
21/02/01 19:08:15 WARN TaskSetManager: Lost task 0.0 in stage 2.0 (TID 2, localhost, executor driver): java.lang.NoSuchMethodError: net.jpountz.lz4.LZ4BlockInputStream.<init>(Ljava/io/InputStream;Z)V
        at org.apache.spark.io.LZ4CompressionCodec.compressedInputStream(CompressionCodec.scala:122)
        at org.apache.spark.serializer.SerializerManager.wrapForCompression(SerializerManager.scala:163)
        at org.apache.spark.serializer.SerializerManager.wrapStream(SerializerManager.scala:124)
        at org.apache.spark.shuffle.BlockStoreShuffleReader$$anonfun$3.apply(BlockStoreShuffleReader.scala:50)
        at org.apache.spark.shuffle.BlockStoreShuffleReader$$anonfun$3.apply(BlockStoreShuffleReader.scala:50)
        at org.apache.spark.storage.ShuffleBlockFetcherIterator.next(ShuffleBlockFetcherIterator.scala:426)
        at org.apache.spark.storage.ShuffleBlockFetcherIterator.next(ShuffleBlockFetcherIterator.scala:62)
        at scala.collection.Iterator$$anon$12.nextCur(Iterator.scala:435)
        at scala.collection.Iterator$$anon$12.hasNext(Iterator.scala:441)
        at scala.collection.Iterator$$anon$11.hasNext(Iterator.scala:409)
        at org.apache.spark.util.CompletionIterator.hasNext(CompletionIterator.scala:30)
        at org.apache.spark.InterruptibleIterator.hasNext(InterruptibleIterator.scala:37)
        at scala.collection.Iterator$$anon$11.hasNext(Iterator.scala:409)
        at org.apache.spark.util.collection.ExternalAppendOnlyMap.insertAll(ExternalAppendOnlyMap.scala:153)
        at org.apache.spark.rdd.CoGroupedRDD$$anonfun$compute$4.apply(CoGroupedRDD.scala:154)
        at org.apache.spark.rdd.CoGroupedRDD$$anonfun$compute$4.apply(CoGroupedRDD.scala:153)
        at scala.collection.TraversableLike$WithFilter$$anonfun$foreach$1.apply(TraversableLike.scala:733)
        at scala.collection.mutable.ResizableArray$class.foreach(ResizableArray.scala:59)
        at scala.collection.mutable.ArrayBuffer.foreach(ArrayBuffer.scala:48)
        at scala.collection.TraversableLike$WithFilter.foreach(TraversableLike.scala:732)
        at org.apache.spark.rdd.CoGroupedRDD.compute(CoGroupedRDD.scala:153)
        at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:324)
        at org.apache.spark.rdd.RDD.iterator(RDD.scala:288)
        at org.apache.spark.rdd.MapPartitionsRDD.compute(MapPartitionsRDD.scala:49)
        at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:324)
        at org.apache.spark.rdd.RDD.iterator(RDD.scala:288)
        at org.apache.spark.rdd.MapPartitionsRDD.compute(MapPartitionsRDD.scala:49)
        at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:324)
        at org.apache.spark.rdd.RDD.iterator(RDD.scala:288)
        at org.apache.spark.scheduler.ResultTask.runTask(ResultTask.scala:87)
        at org.apache.spark.scheduler.Task.run(Task.scala:109)
        at org.apache.spark.executor.Executor$TaskRunner.run(Executor.scala:345)
        at java.util.concurrent.ThreadPoolExecutor.runWorker(Unknown Source)
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(Unknown Source)
        at java.lang.Thread.run(Unknown Source)
 
21/02/01 19:08:15 ERROR TaskSetManager: Task 0 in stage 2.0 failed 1 times; aborting job
21/02/01 19:08:15 INFO TaskSchedulerImpl: Removed TaskSet 2.0, whose tasks have all completed, from pool 
21/02/01 19:08:15 INFO TaskSchedulerImpl: Cancelling stage 2
21/02/01 19:08:15 INFO DAGScheduler: ResultStage 2 (collect at RDDjoinExample.scala:17) failed in 0.084 s due to Job aborted due to stage failure: Task 0 in stage 2.0 failed 1 times, most recent failure: Lost task 0.0 in stage 2.0 (TID 2, localhost, executor driver): java.lang.NoSuchMethodError: net.jpountz.lz4.LZ4BlockInputStream.<init>(Ljava/io/InputStream;Z)V
        at org.apache.spark.io.LZ4CompressionCodec.compressedInputStream(CompressionCodec.scala:122)
        at org.apache.spark.serializer.SerializerManager.wrapForCompression(SerializerManager.scala:163)
        at org.apache.spark.serializer.SerializerManager.wrapStream(SerializerManager.scala:124)
        at org.apache.spark.shuffle.BlockStoreShuffleReader$$anonfun$3.apply(BlockStoreShuffleReader.scala:50)
        at org.apache.spark.shuffle.BlockStoreShuffleReader$$anonfun$3.apply(BlockStoreShuffleReader.scala:50)
        at org.apache.spark.storage.ShuffleBlockFetcherIterator.next(ShuffleBlockFetcherIterator.scala:426)
        at org.apache.spark.storage.ShuffleBlockFetcherIterator.next(ShuffleBlockFetcherIterator.scala:62)
        at scala.collection.Iterator$$anon$12.nextCur(Iterator.scala:435)
        at scala.collection.Iterator$$anon$12.hasNext(Iterator.scala:441)
        at scala.collection.Iterator$$anon$11.hasNext(Iterator.scala:409)
        at org.apache.spark.util.CompletionIterator.hasNext(CompletionIterator.scala:30)
        at org.apache.spark.InterruptibleIterator.hasNext(InterruptibleIterator.scala:37)
        at scala.collection.Iterator$$anon$11.hasNext(Iterator.scala:409)
        at org.apache.spark.util.collection.ExternalAppendOnlyMap.insertAll(ExternalAppendOnlyMap.scala:153)
        at org.apache.spark.rdd.CoGroupedRDD$$anonfun$compute$4.apply(CoGroupedRDD.scala:154)
        at org.apache.spark.rdd.CoGroupedRDD$$anonfun$compute$4.apply(CoGroupedRDD.scala:153)
        at scala.collection.TraversableLike$WithFilter$$anonfun$foreach$1.apply(TraversableLike.scala:733)
        at scala.collection.mutable.ResizableArray$class.foreach(ResizableArray.scala:59)
        at scala.collection.mutable.ArrayBuffer.foreach(ArrayBuffer.scala:48)
        at scala.collection.TraversableLike$WithFilter.foreach(TraversableLike.scala:732)
        at org.apache.spark.rdd.CoGroupedRDD.compute(CoGroupedRDD.scala:153)
        at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:324)
        at org.apache.spark.rdd.RDD.iterator(RDD.scala:288)
        at org.apache.spark.rdd.MapPartitionsRDD.compute(MapPartitionsRDD.scala:49)
        at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:324)
        at org.apache.spark.rdd.RDD.iterator(RDD.scala:288)
        at org.apache.spark.rdd.MapPartitionsRDD.compute(MapPartitionsRDD.scala:49)
        at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:324)
        at org.apache.spark.rdd.RDD.iterator(RDD.scala:288)
        at org.apache.spark.scheduler.ResultTask.runTask(ResultTask.scala:87)
        at org.apache.spark.scheduler.Task.run(Task.scala:109)
        at org.apache.spark.executor.Executor$TaskRunner.run(Executor.scala:345)
        at java.util.concurrent.ThreadPoolExecutor.runWorker(Unknown Source)
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(Unknown Source)
        at java.lang.Thread.run(Unknown Source)
 
Driver stacktrace:
21/02/01 19:08:15 INFO DAGScheduler: Job 0 failed: collect at RDDjoinExample.scala:17, took 0.565251 s
Exception in thread "main" org.apache.spark.SparkException: Job aborted due to stage failure: Task 0 in stage 2.0 failed 1 times, most recent failure: Lost task 0.0 in stage 2.0 (TID 2, localhost, executor driver): java.lang.NoSuchMethodError: net.jpountz.lz4.LZ4BlockInputStream.<init>(Ljava/io/InputStream;Z)V
        at org.apache.spark.io.LZ4CompressionCodec.compressedInputStream(CompressionCodec.scala:122)
        at org.apache.spark.serializer.SerializerManager.wrapForCompression(SerializerManager.scala:163)
        at org.apache.spark.serializer.SerializerManager.wrapStream(SerializerManager.scala:124)
        at org.apache.spark.shuffle.BlockStoreShuffleReader$$anonfun$3.apply(BlockStoreShuffleReader.scala:50)
        at org.apache.spark.shuffle.BlockStoreShuffleReader$$anonfun$3.apply(BlockStoreShuffleReader.scala:50)
        at org.apache.spark.storage.ShuffleBlockFetcherIterator.next(ShuffleBlockFetcherIterator.scala:426)
        at org.apache.spark.storage.ShuffleBlockFetcherIterator.next(ShuffleBlockFetcherIterator.scala:62)
        at scala.collection.Iterator$$anon$12.nextCur(Iterator.scala:435)
        at scala.collection.Iterator$$anon$12.hasNext(Iterator.scala:441)
        at scala.collection.Iterator$$anon$11.hasNext(Iterator.scala:409)
        at org.apache.spark.util.CompletionIterator.hasNext(CompletionIterator.scala:30)
        at org.apache.spark.InterruptibleIterator.hasNext(InterruptibleIterator.scala:37)
        at scala.collection.Iterator$$anon$11.hasNext(Iterator.scala:409)
        at org.apache.spark.util.collection.ExternalAppendOnlyMap.insertAll(ExternalAppendOnlyMap.scala:153)
        at org.apache.spark.rdd.CoGroupedRDD$$anonfun$compute$4.apply(CoGroupedRDD.scala:154)
        at org.apache.spark.rdd.CoGroupedRDD$$anonfun$compute$4.apply(CoGroupedRDD.scala:153)
        at scala.collection.TraversableLike$WithFilter$$anonfun$foreach$1.apply(TraversableLike.scala:733)
        at scala.collection.mutable.ResizableArray$class.foreach(ResizableArray.scala:59)
        at scala.collection.mutable.ArrayBuffer.foreach(ArrayBuffer.scala:48)
        at scala.collection.TraversableLike$WithFilter.foreach(TraversableLike.scala:732)
        at org.apache.spark.rdd.CoGroupedRDD.compute(CoGroupedRDD.scala:153)
        at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:324)
        at org.apache.spark.rdd.RDD.iterator(RDD.scala:288)
        at org.apache.spark.rdd.MapPartitionsRDD.compute(MapPartitionsRDD.scala:49)
        at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:324)
        at org.apache.spark.rdd.RDD.iterator(RDD.scala:288)
        at org.apache.spark.rdd.MapPartitionsRDD.compute(MapPartitionsRDD.scala:49)
        at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:324)
        at org.apache.spark.rdd.RDD.iterator(RDD.scala:288)
        at org.apache.spark.scheduler.ResultTask.runTask(ResultTask.scala:87)
        at org.apache.spark.scheduler.Task.run(Task.scala:109)
        at org.apache.spark.executor.Executor$TaskRunner.run(Executor.scala:345)
        at java.util.concurrent.ThreadPoolExecutor.runWorker(Unknown Source)
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(Unknown Source)
        at java.lang.Thread.run(Unknown Source)
 
Driver stacktrace:
        at org.apache.spark.scheduler.DAGScheduler.org$apache$spark$scheduler$DAGScheduler$$failJobAndIndependentStages(DAGScheduler.scala:1651)
        at org.apache.spark.scheduler.DAGScheduler$$anonfun$abortStage$1.apply(DAGScheduler.scala:1639)
        at org.apache.spark.scheduler.DAGScheduler$$anonfun$abortStage$1.apply(DAGScheduler.scala:1638)
        at scala.collection.mutable.ResizableArray$class.foreach(ResizableArray.scala:59)
        at scala.collection.mutable.ArrayBuffer.foreach(ArrayBuffer.scala:48)
        at org.apache.spark.scheduler.DAGScheduler.abortStage(DAGScheduler.scala:1638)
        at org.apache.spark.scheduler.DAGScheduler$$anonfun$handleTaskSetFailed$1.apply(DAGScheduler.scala:831)
        at org.apache.spark.scheduler.DAGScheduler$$anonfun$handleTaskSetFailed$1.apply(DAGScheduler.scala:831)
        at scala.Option.foreach(Option.scala:257)
        at org.apache.spark.scheduler.DAGScheduler.handleTaskSetFailed(DAGScheduler.scala:831)
        at org.apache.spark.scheduler.DAGSchedulerEventProcessLoop.doOnReceive(DAGScheduler.scala:1872)
        at org.apache.spark.scheduler.DAGSchedulerEventProcessLoop.onReceive(DAGScheduler.scala:1821)
        at org.apache.spark.scheduler.DAGSchedulerEventProcessLoop.onReceive(DAGScheduler.scala:1810)
        at org.apache.spark.util.EventLoop$$anon$1.run(EventLoop.scala:48)
        at org.apache.spark.scheduler.DAGScheduler.runJob(DAGScheduler.scala:642)
        at org.apache.spark.SparkContext.runJob(SparkContext.scala:2034)
        at org.apache.spark.SparkContext.runJob(SparkContext.scala:2055)
        at org.apache.spark.SparkContext.runJob(SparkContext.scala:2074)
        at org.apache.spark.SparkContext.runJob(SparkContext.scala:2099)
        at org.apache.spark.rdd.RDD$$anonfun$collect$1.apply(RDD.scala:945)
        at org.apache.spark.rdd.RDDOperationScope$.withScope(RDDOperationScope.scala:151)
        at org.apache.spark.rdd.RDDOperationScope$.withScope(RDDOperationScope.scala:112)
        at org.apache.spark.rdd.RDD.withScope(RDD.scala:363)
        at org.apache.spark.rdd.RDD.collect(RDD.scala:944)
        at com.xum.SparkExample.demo003.RDDjoin.RDDjoinExample$.main(RDDjoinExample.scala:17)
        at com.xum.SparkExample.demo003.RDDjoin.RDDjoinExample.main(RDDjoinExample.scala)
Caused by: java.lang.NoSuchMethodError: net.jpountz.lz4.LZ4BlockInputStream.<init>(Ljava/io/InputStream;Z)V
        at org.apache.spark.io.LZ4CompressionCodec.compressedInputStream(CompressionCodec.scala:122)
        at org.apache.spark.serializer.SerializerManager.wrapForCompression(SerializerManager.scala:163)
        at org.apache.spark.serializer.SerializerManager.wrapStream(SerializerManager.scala:124)
        at org.apache.spark.shuffle.BlockStoreShuffleReader$$anonfun$3.apply(BlockStoreShuffleReader.scala:50)
        at org.apache.spark.shuffle.BlockStoreShuffleReader$$anonfun$3.apply(BlockStoreShuffleReader.scala:50)
        at org.apache.spark.storage.ShuffleBlockFetcherIterator.next(ShuffleBlockFetcherIterator.scala:426)
        at org.apache.spark.storage.ShuffleBlockFetcherIterator.next(ShuffleBlockFetcherIterator.scala:62)
        at scala.collection.Iterator$$anon$12.nextCur(Iterator.scala:435)
        at scala.collection.Iterator$$anon$12.hasNext(Iterator.scala:441)
        at scala.collection.Iterator$$anon$11.hasNext(Iterator.scala:409)
        at org.apache.spark.util.CompletionIterator.hasNext(CompletionIterator.scala:30)
        at org.apache.spark.InterruptibleIterator.hasNext(InterruptibleIterator.scala:37)
        at scala.collection.Iterator$$anon$11.hasNext(Iterator.scala:409)
        at org.apache.spark.util.collection.ExternalAppendOnlyMap.insertAll(ExternalAppendOnlyMap.scala:153)
        at org.apache.spark.rdd.CoGroupedRDD$$anonfun$compute$4.apply(CoGroupedRDD.scala:154)
        at org.apache.spark.rdd.CoGroupedRDD$$anonfun$compute$4.apply(CoGroupedRDD.scala:153)
        at scala.collection.TraversableLike$WithFilter$$anonfun$foreach$1.apply(TraversableLike.scala:733)
        at scala.collection.mutable.ResizableArray$class.foreach(ResizableArray.scala:59)
        at scala.collection.mutable.ArrayBuffer.foreach(ArrayBuffer.scala:48)
        at scala.collection.TraversableLike$WithFilter.foreach(TraversableLike.scala:732)
        at org.apache.spark.rdd.CoGroupedRDD.compute(CoGroupedRDD.scala:153)
        at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:324)
        at org.apache.spark.rdd.RDD.iterator(RDD.scala:288)
        at org.apache.spark.rdd.MapPartitionsRDD.compute(MapPartitionsRDD.scala:49)
        at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:324)
        at org.apache.spark.rdd.RDD.iterator(RDD.scala:288)
        at org.apache.spark.rdd.MapPartitionsRDD.compute(MapPartitionsRDD.scala:49)
        at org.apache.spark.rdd.RDD.computeOrReadCheckpoint(RDD.scala:324)
        at org.apache.spark.rdd.RDD.iterator(RDD.scala:288)
        at org.apache.spark.scheduler.ResultTask.runTask(ResultTask.scala:87)
        at org.apache.spark.scheduler.Task.run(Task.scala:109)
        at org.apache.spark.executor.Executor$TaskRunner.run(Executor.scala:345)
        at java.util.concurrent.ThreadPoolExecutor.runWorker(Unknown Source)
        at java.util.concurrent.ThreadPoolExecutor$Worker.run(Unknown Source)
        at java.lang.Thread.run(Unknown Source)
```

再重新执行对接Kafka 的SparkStreaming 应用，以及上面的那个为了尝试复现问题的SparkStreaming 应用，果然也都有相同的异常输出，接下来针对这个输出去反向分析源码、定位原因，希望以此可以对Spark 的体系结构进行初步的梳理
 
## 先把问题解决掉

spark2.3 用到了lz4-1.3.0.jar，kafka0.9.0.1 用到了lz4-1.2.0.jar，而程序运行时使用的是lz4-1.3.0.jar
 
2.lz4-1.3.0.jar 包中net.jpountz.util.Utils 类中没有checkRange，该方法位于net.jpountz.util.SafeUtils 和net.jpountz.util.UnsafeUtils
 
```xml
<dependency>
  <groupId>org.apache.spark</groupId>
  <artifactId>spark-streaming-kafka-0-8_2.11</artifactId>
  <version>2.3.2</version>
</dependency>
<dependency>
  <groupId>org.apache.spark</groupId>
  <artifactId>spark-streaming_2.11</artifactId>
  <version>2.3.2</version>
</dependency>
<dependency>
  <groupId>org.apache.spark</groupId>
  <artifactId>spark-core_2.11</artifactId>
  <version>2.3.2</version>
</dependency>
<dependency>
  <groupId>net.jpountz.lz4</groupId>
  <artifactId>lz4</artifactId>
  <version>1.3.0</version>
</dependency>
```

## RDD join() 算子案例展示

两个RDD 中数据数量一致，且有一一对应的键值

```scala
val rdd1: RDD[(Int, String)] = sparkContext.makeRDD(Array((1, "abc1"), (2, "xyz1")), 1)
val rdd2: RDD[(Int, String)] = sparkContext.makeRDD(Array((1, "abc2"), (2, "xyz2")), 1)
 
rdd1.join(rdd2).collect().foreach(println)
```

输出结果如下

```
(1,(abc1,abc2))
(2,(xyz1,xyz2))
```

第一个RDD 中的数据比第二个RDD 中的数据多
 
```scala
val rdd1: RDD[(Int, String)] = sparkContext.makeRDD(Array((1, "abc1"), (2, "xyz1"), (3, "ijk1")), 1)
val rdd2: RDD[(Int, String)] = sparkContext.makeRDD(Array((1, "abc2"), (2, "xyz2")), 1)
 
rdd1.join(rdd2).collect().foreach(println)
```

输出结果如下

```
(1,(abc1,abc2))
(2,(xyz1,xyz2))
```

第一个RDD 中的数据比第一个RDD 中的数据多，且第一个RDD 中有重复的键值

```scala
val rdd1: RDD[(Int, String)] = sparkContext.makeRDD(Array((1, "abc1"), (2, "xyz1"), (1, "ijk1")), 1)
val rdd2: RDD[(Int, String)] = sparkContext.makeRDD(Array((1, "abc2"), (2, "xyz2")), 1)
 
rdd1.join(rdd2).collect().foreach(println)
```

输出结果如下

```
(1,(abc1,abc2))
(1,(ijk1,abc2))
(2,(xyz1,xyz2))
```