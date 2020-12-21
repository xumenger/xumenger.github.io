---
layout: post
title: Spark 计算框架：RDD 算子应用案例
categories: 大数据之kafka 大数据之spark
tags: scala java 大数据 kafka spark MacOS 环境搭建 Scala Maven Hadoop SQL 算子 数据分析 groupBy filter distinct coalesce shuffle 数据倾斜 分区 分组 聚合 关系型数据库 行动算子 转换算子 尚硅谷 
---

>同样，本文是[尚硅谷2021迎新版大数据Spark从入门到精通](https://www.bilibili.com/video/BV11A411L7CK)的学习笔记。尚硅谷牛逼！

>[https://www.bilibili.com/video/BV11A411L7CK?p=110](https://www.bilibili.com/video/BV11A411L7CK?p=110)

通过一些典型的案例了解各种算子的适用场景，同时帮助更进一步理解这些算子的实现原理！

按理基于的数据是这样的格式，主要包括用户的4 种行为：搜索、点击、下单、支付。一条数据只能是这4 种行为中的一种！

![](../media/image/2020-11-25-7/01.png)

用户访问动作表

```scala
//用户访问动作表
case class UserVisitAction(
    date: String,                  //用户点击行为的日期
    user_id: Long,                 //用户的 ID
    session_id: String,            //Session 的 ID
    page_id: Long,                 //某个页面的 ID
    action_time: String,           //动作的时间点
    search_keyword: String,        //用户搜索的关键词
    click_category_id: Long,       //某一个商品品类的 ID
    click_product_id: Long,        //某一个商品的 ID
    order_category_ids: String,    //一次订单中所有品类的 ID 集合
    order_product_ids: String,     //一次订单中所有商品的 ID 集合
    pay_category_ids: String,      //一次支付中所有品类的 ID 集合
    pay_product_ids: String,       //一次支付中所有商品的 ID 集合
    city_id: Long                  //城市 id
)
```

分析Top 10 热门数据

## 版本一

```scala
import org.apache.spark.rdd.RDD
import org.apache.spark.{SparkConf, SparkContext}

object HotCategoryTop10Analysis {

    def main(args: Array[String]): Unit = {

        // Top10热门品类
        val sparConf = new SparkConf().setMaster("local[*]").setAppName("HotCategoryTop10Analysis")
        val sc = new SparkContext(sparConf)

        // 1. 读取原始日志数据
        val actionRDD = sc.textFile("datas/user_visit_action.txt")

        // 2. 统计品类的点击数量：（品类ID，点击数量）
        val clickActionRDD = actionRDD.filter(
            action => {
                val datas = action.split("_")
                datas(6) != "-1"
            }
        )

        val clickCountRDD: RDD[(String, Int)] = clickActionRDD.map(
            action => {
                val datas = action.split("_")
                (datas(6), 1)
            }
        ).reduceByKey(_ + _)

        // 3. 统计品类的下单数量：（品类ID，下单数量）
        val orderActionRDD = actionRDD.filter(
            action => {
                val datas = action.split("_")
                datas(8) != "null"
            }
        )

        // orderid => 1,2,3
        // 【(1,1)，(2,1)，(3,1)】
        val orderCountRDD = orderActionRDD.flatMap(
            action => {
                val datas = action.split("_")
                val cid = datas(8)
                val cids = cid.split(",")
                cids.map(id=>(id, 1))
            }
        ).reduceByKey(_+_)

        // 4. 统计品类的支付数量：（品类ID，支付数量）
        val payActionRDD = actionRDD.filter(
            action => {
                val datas = action.split("_")
                datas(10) != "null"
            }
        )

        // orderid => 1,2,3
        // 【(1,1)，(2,1)，(3,1)】
        val payCountRDD = payActionRDD.flatMap(
            action => {
                val datas = action.split("_")
                val cid = datas(10)
                val cids = cid.split(",")
                cids.map(id=>(id, 1))
            }
        ).reduceByKey(_+_)

        // 5. 将品类进行排序，并且取前10名
        //    点击数量排序，下单数量排序，支付数量排序
        //    元组排序：先比较第一个，再比较第二个，再比较第三个，依此类推
        //    ( 品类ID, ( 点击数量, 下单数量, 支付数量 ) )
        //
        //  cogroup = connect + group
        val cogroupRDD: RDD[(String, (Iterable[Int], Iterable[Int], Iterable[Int]))] =
            clickCountRDD.cogroup(orderCountRDD, payCountRDD)
        val analysisRDD = cogroupRDD.mapValues{
            case ( clickIter, orderIter, payIter ) => {

                var clickCnt = 0
                val iter1 = clickIter.iterator
                if ( iter1.hasNext ) {
                    clickCnt = iter1.next()
                }
                var orderCnt = 0
                val iter2 = orderIter.iterator
                if ( iter2.hasNext ) {
                    orderCnt = iter2.next()
                }
                var payCnt = 0
                val iter3 = payIter.iterator
                if ( iter3.hasNext ) {
                    payCnt = iter3.next()
                }

                ( clickCnt, orderCnt, payCnt )
            }
        }

        val resultRDD = analysisRDD.sortBy(_._2, false).take(10)

        // 6. 将结果采集到控制台打印出来
        resultRDD.foreach(println)

        sc.stop()
    }
}
```

## 版本二

```scala
import org.apache.spark.rdd.RDD
import org.apache.spark.{SparkConf, SparkContext}

object HotCategoryTop10Analysis {

    def main(args: Array[String]): Unit = {

        // Top10热门品类
        val sparConf = new SparkConf().setMaster("local[*]").setAppName("HotCategoryTop10Analysis")
        val sc = new SparkContext(sparConf)

        // Q : actionRDD重复使用
        // Q : cogroup性能可能较低

        // 1. 读取原始日志数据
        val actionRDD = sc.textFile("datas/user_visit_action.txt")
        actionRDD.cache()

        // 2. 统计品类的点击数量：（品类ID，点击数量）
        val clickActionRDD = actionRDD.filter(
            action => {
                val datas = action.split("_")
                datas(6) != "-1"
            }
        )

        val clickCountRDD: RDD[(String, Int)] = clickActionRDD.map(
            action => {
                val datas = action.split("_")
                (datas(6), 1)
            }
        ).reduceByKey(_ + _)

        // 3. 统计品类的下单数量：（品类ID，下单数量）
        val orderActionRDD = actionRDD.filter(
            action => {
                val datas = action.split("_")
                datas(8) != "null"
            }
        )

        // orderid => 1,2,3
        // 【(1,1)，(2,1)，(3,1)】
        val orderCountRDD = orderActionRDD.flatMap(
            action => {
                val datas = action.split("_")
                val cid = datas(8)
                val cids = cid.split(",")
                cids.map(id=>(id, 1))
            }
        ).reduceByKey(_+_)

        // 4. 统计品类的支付数量：（品类ID，支付数量）
        val payActionRDD = actionRDD.filter(
            action => {
                val datas = action.split("_")
                datas(10) != "null"
            }
        )

        // orderid => 1,2,3
        // 【(1,1)，(2,1)，(3,1)】
        val payCountRDD = payActionRDD.flatMap(
            action => {
                val datas = action.split("_")
                val cid = datas(10)
                val cids = cid.split(",")
                cids.map(id=>(id, 1))
            }
        ).reduceByKey(_+_)

        // (品类ID, 点击数量) => (品类ID, (点击数量, 0, 0))
        // (品类ID, 下单数量) => (品类ID, (0, 下单数量, 0))
        //                    => (品类ID, (点击数量, 下单数量, 0))
        // (品类ID, 支付数量) => (品类ID, (0, 0, 支付数量))
        //                    => (品类ID, (点击数量, 下单数量, 支付数量))
        // ( 品类ID, ( 点击数量, 下单数量, 支付数量 ) )

        // 5. 将品类进行排序，并且取前10名
        //    点击数量排序，下单数量排序，支付数量排序
        //    元组排序：先比较第一个，再比较第二个，再比较第三个，依此类推
        //    ( 品类ID, ( 点击数量, 下单数量, 支付数量 ) )
        //
        val rdd1 = clickCountRDD.map{
            case ( cid, cnt ) => {
                (cid, (cnt, 0, 0))
            }
        }
        val rdd2 = orderCountRDD.map{
            case ( cid, cnt ) => {
                (cid, (0, cnt, 0))
            }
        }
        val rdd3 = payCountRDD.map{
            case ( cid, cnt ) => {
                (cid, (0, 0, cnt))
            }
        }

        // 将三个数据源合并在一起，统一进行聚合计算
        val soruceRDD: RDD[(String, (Int, Int, Int))] = rdd1.union(rdd2).union(rdd3)

        val analysisRDD = soruceRDD.reduceByKey(
            ( t1, t2 ) => {
                ( t1._1+t2._1, t1._2 + t2._2, t1._3 + t2._3 )
            }
        )

        val resultRDD = analysisRDD.sortBy(_._2, false).take(10)

        // 6. 将结果采集到控制台打印出来
        resultRDD.foreach(println)

        sc.stop()
    }
}
```

## 版本三

```scala
import org.apache.spark.rdd.RDD
import org.apache.spark.{SparkConf, SparkContext}

object HotCategoryTop10Analysis {

    def main(args: Array[String]): Unit = {

        // Top10热门品类
        val sparConf = new SparkConf().setMaster("local[*]").setAppName("HotCategoryTop10Analysis")
        val sc = new SparkContext(sparConf)

        // Q : 存在大量的shuffle操作（reduceByKey）
        // reduceByKey 聚合算子，spark会提供优化，缓存

        // 1. 读取原始日志数据
        val actionRDD = sc.textFile("datas/user_visit_action.txt")

        // 2. 将数据转换结构
        //    点击的场合 : ( 品类ID，( 1, 0, 0 ) )
        //    下单的场合 : ( 品类ID，( 0, 1, 0 ) )
        //    支付的场合 : ( 品类ID，( 0, 0, 1 ) )
        val flatRDD: RDD[(String, (Int, Int, Int))] = actionRDD.flatMap(
            action => {
                val datas = action.split("_")
                if (datas(6) != "-1") {
                    // 点击的场合
                    List((datas(6), (1, 0, 0)))
                } else if (datas(8) != "null") {
                    // 下单的场合
                    val ids = datas(8).split(",")
                    ids.map(id => (id, (0, 1, 0)))
                } else if (datas(10) != "null") {
                    // 支付的场合
                    val ids = datas(10).split(",")
                    ids.map(id => (id, (0, 0, 1)))
                } else {
                    Nil
                }
            }
        )

        // 3. 将相同的品类ID的数据进行分组聚合
        //    ( 品类ID，( 点击数量, 下单数量, 支付数量 ) )
        val analysisRDD = flatRDD.reduceByKey(
            (t1, t2) => {
                ( t1._1+t2._1, t1._2 + t2._2, t1._3 + t2._3 )
            }
        )

        // 4. 将统计结果根据数量进行降序处理，取前10名
        val resultRDD = analysisRDD.sortBy(_._2, false).take(10)

        // 5. 将结果采集到控制台打印出来
        resultRDD.foreach(println)

        sc.stop()
    }
}
```

## 版本四

```scala
import org.apache.spark.rdd.RDD
import org.apache.spark.util.AccumulatorV2
import org.apache.spark.{SparkConf, SparkContext}

import scala.collection.mutable

object HotCategoryTop10Analysis {

    def main(args: Array[String]): Unit = {

        // Top10热门品类
        val sparConf = new SparkConf().setMaster("local[*]").setAppName("HotCategoryTop10Analysis")
        val sc = new SparkContext(sparConf)

        // 1. 读取原始日志数据
        val actionRDD = sc.textFile("datas/user_visit_action.txt")

        val acc = new HotCategoryAccumulator
        sc.register(acc, "hotCategory")

        // 2. 将数据转换结构
        actionRDD.foreach(
            action => {
                val datas = action.split("_")
                if (datas(6) != "-1") {
                    // 点击的场合
                    acc.add((datas(6), "click"))
                } else if (datas(8) != "null") {
                    // 下单的场合
                    val ids = datas(8).split(",")
                    ids.foreach(
                        id => {
                            acc.add( (id, "order") )
                        }
                    )
                } else if (datas(10) != "null") {
                    // 支付的场合
                    val ids = datas(10).split(",")
                    ids.foreach(
                        id => {
                            acc.add( (id, "pay") )
                        }
                    )
                }
            }
        )

        val accVal: mutable.Map[String, HotCategory] = acc.value
        val categories: mutable.Iterable[HotCategory] = accVal.map(_._2)

        val sort = categories.toList.sortWith(
            (left, right) => {
                if ( left.clickCnt > right.clickCnt ) {
                    true
                } else if (left.clickCnt == right.clickCnt) {
                    if ( left.orderCnt > right.orderCnt ) {
                        true
                    } else if (left.orderCnt == right.orderCnt) {
                        left.payCnt > right.payCnt
                    } else {
                        false
                    }
                } else {
                    false
                }
            }
        )

        // 5. 将结果采集到控制台打印出来
        sort.take(10).foreach(println)

        sc.stop()
    }
    case class HotCategory( cid:String, var clickCnt : Int, var orderCnt : Int, var payCnt : Int )
    /**
      * 自定义累加器
      * 1. 继承AccumulatorV2，定义泛型
      *    IN : ( 品类ID, 行为类型 )
      *    OUT : mutable.Map[String, HotCategory]
      * 2. 重写方法（6）
      */
    class HotCategoryAccumulator extends AccumulatorV2[(String, String), mutable.Map[String, HotCategory]]{

        private val hcMap = mutable.Map[String, HotCategory]()

        override def isZero: Boolean = {
            hcMap.isEmpty
        }

        override def copy(): AccumulatorV2[(String, String), mutable.Map[String, HotCategory]] = {
            new HotCategoryAccumulator()
        }

        override def reset(): Unit = {
            hcMap.clear()
        }

        override def add(v: (String, String)): Unit = {
            val cid = v._1
            val actionType = v._2
            val category: HotCategory = hcMap.getOrElse(cid, HotCategory(cid, 0,0,0))
            if ( actionType == "click" ) {
                category.clickCnt += 1
            } else if (actionType == "order") {
                category.orderCnt += 1
            } else if (actionType == "pay") {
                category.payCnt += 1
            }
            hcMap.update(cid, category)
        }

        override def merge(other: AccumulatorV2[(String, String), mutable.Map[String, HotCategory]]): Unit = {
            val map1 = this.hcMap
            val map2 = other.value

            map2.foreach{
                case ( cid, hc ) => {
                    val category: HotCategory = map1.getOrElse(cid, HotCategory(cid, 0,0,0))
                    category.clickCnt += hc.clickCnt
                    category.orderCnt += hc.orderCnt
                    category.payCnt += hc.payCnt
                    map1.update(cid, category)
                }
            }
        }

        override def value: mutable.Map[String, HotCategory] = hcMap
    }
}
```

## 页面单跳转率统计

```scala
import org.apache.spark.rdd.RDD
import org.apache.spark.{SparkConf, SparkContext}

object PageflowAnalysis {

    def main(args: Array[String]): Unit = {

        // 页面单跳转率统计
        val sparConf = new SparkConf().setMaster("local[*]").setAppName("PageflowAnalysis")
        val sc = new SparkContext(sparConf)

        val actionRDD = sc.textFile("datas/user_visit_action.txt")

        val actionDataRDD = actionRDD.map(
            action => {
                val datas = action.split("_")
                UserVisitAction(
                    datas(0),
                    datas(1).toLong,
                    datas(2),
                    datas(3).toLong,
                    datas(4),
                    datas(5),
                    datas(6).toLong,
                    datas(7).toLong,
                    datas(8),
                    datas(9),
                    datas(10),
                    datas(11),
                    datas(12).toLong
                )
            }
        )
        actionDataRDD.cache()

        // TODO 对指定的页面连续跳转进行统计
        // 1-2,2-3,3-4,4-5,5-6,6-7
        val ids = List[Long](1,2,3,4,5,6,7)
        val okflowIds: List[(Long, Long)] = ids.zip(ids.tail)

        // TODO 计算分母
        val pageidToCountMap: Map[Long, Long] = actionDataRDD.filter(
            action => {
                ids.init.contains(action.page_id)
            }
        ).map(
            action => {
                (action.page_id, 1L)
            }
        ).reduceByKey(_ + _).collect().toMap

        // TODO 计算分子

        // 根据session进行分组
        val sessionRDD: RDD[(String, Iterable[UserVisitAction])] = actionDataRDD.groupBy(_.session_id)

        // 分组后，根据访问时间进行排序（升序）
        val mvRDD: RDD[(String, List[((Long, Long), Int)])] = sessionRDD.mapValues(
            iter => {
                val sortList: List[UserVisitAction] = iter.toList.sortBy(_.action_time)

                // 【1，2，3，4】
                // 【1，2】，【2，3】，【3，4】
                // 【1-2，2-3，3-4】
                // Sliding : 滑窗
                // 【1，2，3，4】
                // 【2，3，4】
                // zip : 拉链
                val flowIds: List[Long] = sortList.map(_.page_id)
                val pageflowIds: List[(Long, Long)] = flowIds.zip(flowIds.tail)

                // 将不合法的页面跳转进行过滤
                pageflowIds.filter(
                    t => {
                        okflowIds.contains(t)
                    }
                ).map(
                    t => {
                        (t, 1)
                    }
                )
            }
        )
        // ((1,2),1)
        val flatRDD: RDD[((Long, Long), Int)] = mvRDD.map(_._2).flatMap(list=>list)
        // ((1,2),1) => ((1,2),sum)
        val dataRDD = flatRDD.reduceByKey(_+_)

        // TODO 计算单跳转换率
        // 分子除以分母
        dataRDD.foreach{
            case ( (pageid1, pageid2), sum ) => {
                val lon: Long = pageidToCountMap.getOrElse(pageid1, 0L)

                println(s"页面${pageid1}跳转到页面${pageid2}单跳转换率为:" + ( sum.toDouble/lon ))
            }
        }


        sc.stop()
    }

    //用户访问动作表
    case class UserVisitAction(
              date: String,//用户点击行为的日期
              user_id: Long,//用户的ID
              session_id: String,//Session的ID
              page_id: Long,//某个页面的ID
              action_time: String,//动作的时间点
              search_keyword: String,//用户搜索的关键词
              click_category_id: Long,//某一个商品品类的ID
              click_product_id: Long,//某一个商品的ID
              order_category_ids: String,//一次订单中所有品类的ID集合
              order_product_ids: String,//一次订单中所有商品的ID集合
              pay_category_ids: String,//一次支付中所有品类的ID集合
              pay_product_ids: String,//一次支付中所有商品的ID集合
              city_id: Long
      )//城市 id
}
```