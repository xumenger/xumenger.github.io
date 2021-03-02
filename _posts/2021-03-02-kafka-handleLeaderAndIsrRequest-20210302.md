---
layout: post
title: 源码面前了无秘密【Kafka】：基于一个报错初步分析KafkaApis.handleLeaderAndIsrRequest()
categories: 源码面前了无秘密  
tags: Java Kafka Scala JVM KafkaServer 消费者 消息队列 分布式 网络编程 网络 TCP IO多路复用 分布式选举 ISR 堆外内存 RandomAccessFile mmap
---

Windows 本地搭建Kafka 服务端，启动一个Zookeeper 服务程序，启动一个Kafka 服务端程序
 
```cmd
// 启动Zookeeper
D:
cd \bigdata\zookeeper-3.5.9_2181\bin
zkServer.cmd
 
// 启动KafkaServer 9092端口
D:
set JAVA_HOME=C:\Program Files (x86)\Java\jdk1.8.0_201\jre
set PATH=%JAVA_HOME%\bin;%PATH%
cd \bigdata\kafka_2.12-2.7.0_9092/bin/windows/
kafka-server-start.bat ../../config/server.properties
 
// 创建Topic
D:
cd bigdata\kafka_2.12-2.7.0_9092\bin\windows
 
set JAVA_HOME=C:\Program Files (x86)\Java\jdk1.8.0_201\jre
set PATH=%JAVA_HOME%\bin;%PATH%
 
kafka-topics.bat --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic TestTopic
```
 
启动后，开发一个简单的生产者程序，是可以正常消费的，但是运行一个简单的消费者程序，一直无法消费到消息，并且持续有下面这样的输出
 
```log
16:24:38.887 [main] DEBUG org.apache.kafka.clients.NetworkClient - [Consumer clientId=consumer-1, groupId=TestGroupId] Completed connection to node 2147483547. Fetching API versions.
16:24:38.887 [main] DEBUG org.apache.kafka.clients.NetworkClient - [Consumer clientId=consumer-1, groupId=TestGroupId] Initiating API versions fetch from node 2147483547.
16:24:38.889 [main] DEBUG org.apache.kafka.clients.NetworkClient - [Consumer clientId=consumer-1, groupId=TestGroupId] Recorded API versions for node 2147483547: (Produce(0): 0 to 8 [usable: 6], Fetch(1): 0 to 12 [usable: 8], ListOffsets(2): 0 to 5 [usable: 3], Metadata(3): 0 to 9 [usable: 6], LeaderAndIsr(4): 0 to 4 [usable: 1], StopReplica(5): 0 to 3 [usable: 0], UpdateMetadata(6): 0 to 6 [usable: 4], ControlledShutdown(7): 0 to 3 [usable: 1], OffsetCommit(8): 0 to 8 [usable: 4], OffsetFetch(9): 0 to 7 [usable: 4], FindCoordinator(10): 0 to 3 [usable: 2], JoinGroup(11): 0 to 7 [usable: 3], Heartbeat(12): 0 to 4 [usable: 2], LeaveGroup(13): 0 to 4 [usable: 2], SyncGroup(14): 0 to 5 [usable: 2], DescribeGroups(15): 0 to 5 [usable: 2], ListGroups(16): 0 to 4 [usable: 2], SaslHandshake(17): 0 to 1 [usable: 1], ApiVersions(18): 0 to 3 [usable: 2], CreateTopics(19): 0 to 6 [usable: 3], DeleteTopics(20): 0 to 5 [usable: 2], DeleteRecords(21): 0 to 2 [usable: 1], InitProducerId(22): 0 to 4 [usable: 1], OffsetForLeaderEpoch(23): 0 to 3 [usable: 1], AddPartitionsToTxn(24): 0 to 2 [usable: 1], AddOffsetsToTxn(25): 0 to 2 [usable: 1], EndTxn(26): 0 to 2 [usable: 1], WriteTxnMarkers(27): 0 [usable: 0], TxnOffsetCommit(28): 0 to 3 [usable: 1], DescribeAcls(29): 0 to 2 [usable: 1], CreateAcls(30): 0 to 2 [usable: 1], DeleteAcls(31): 0 to 2 [usable: 1], DescribeConfigs(32): 0 to 3 [usable: 2], AlterConfigs(33): 0 to 1 [usable: 1], AlterReplicaLogDirs(34): 0 to 1 [usable: 1], DescribeLogDirs(35): 0 to 2 [usable: 1], SaslAuthenticate(36): 0 to 2 [usable: 0], CreatePartitions(37): 0 to 3 [usable: 1], CreateDelegationToken(38): 0 to 2 [usable: 1], RenewDelegationToken(39): 0 to 2 [usable: 1], ExpireDelegationToken(40): 0 to 2 [usable: 1], DescribeDelegationToken(41): 0 to 2 [usable: 1], DeleteGroups(42): 0 to 2 [usable: 1], UNKNOWN(43): 0 to 2, UNKNOWN(44): 0 to 1, UNKNOWN(45): 0, UNKNOWN(46): 0, UNKNOWN(47): 0, UNKNOWN(48): 0, UNKNOWN(49): 0, UNKNOWN(50): 0, UNKNOWN(51): 0, UNKNOWN(56): 0, UNKNOWN(57): 0)
16:24:38.891 [main] INFO org.apache.kafka.clients.consumer.internals.AbstractCoordinator - [Consumer clientId=consumer-1, groupId=TestGroupId] Group coordinator 99.14.230.91:9092 (id: 2147483547 rack: null) is unavailable or invalid, will attempt rediscovery
16:24:38.891 [main] DEBUG org.apache.kafka.clients.consumer.internals.AbstractCoordinator - [Consumer clientId=consumer-1, groupId=TestGroupId] Attempt to join group failed due to obsolete coordinator information: This is not the correct coordinator.
16:24:38.991 [main] DEBUG org.apache.kafka.clients.consumer.internals.AbstractCoordinator - [Consumer clientId=consumer-1, groupId=TestGroupId] Sending FindCoordinator request to broker 99.14.230.91:9092 (id: 100 rack: null)
16:24:38.991 [main] DEBUG org.apache.kafka.clients.NetworkClient - [Consumer clientId=consumer-1, groupId=TestGroupId] Manually disconnected from 2147483547. Removed requests: .
16:24:38.992 [main] DEBUG org.apache.kafka.clients.consumer.internals.AbstractCoordinator - [Consumer clientId=consumer-1, groupId=TestGroupId] Received FindCoordinator response ClientResponse(receivedTimeMs=1614673478992, latencyMs=1, disconnected=false, requestHeader=RequestHeader(apiKey=FIND_COORDINATOR, apiVersion=2, clientId=consumer-1, correlationId=4821), responseBody=FindCoordinatorResponse(throttleTimeMs=0, errorMessage='NONE', error=NONE, node=99.14.230.91:9092 (id: 100 rack: null)))
16:24:38.992 [main] INFO org.apache.kafka.clients.consumer.internals.AbstractCoordinator - [Consumer clientId=consumer-1, groupId=TestGroupId] Discovered group coordinator 99.14.230.91:9092 (id: 2147483547 rack: null)
16:24:38.992 [main] INFO org.apache.kafka.clients.consumer.internals.AbstractCoordinator - [Consumer clientId=consumer-1, groupId=TestGroupId] Group coordinator 99.14.230.91:9092 (id: 2147483547 rack: null) is unavailable or invalid, will attempt rediscovery
16:24:39.002 [main] DEBUG org.apache.kafka.clients.consumer.internals.AbstractCoordinator - [Consumer clientId=consumer-1, groupId=TestGroupId] Sending FindCoordinator request to broker 99.14.230.91:9092 (id: 100 rack: null)
16:24:39.004 [main] DEBUG org.apache.kafka.clients.consumer.internals.AbstractCoordinator - [Consumer clientId=consumer-1, groupId=TestGroupId] Received FindCoordinator response ClientResponse(receivedTimeMs=1614673479004, latencyMs=2, disconnected=false, requestHeader=RequestHeader(apiKey=FIND_COORDINATOR, apiVersion=2, clientId=consumer-1, correlationId=4822), responseBody=FindCoordinatorResponse(throttleTimeMs=0, errorMessage='NONE', error=NONE, node=99.14.230.91:9092 (id: 100 rack: null)))
16:24:39.004 [main] INFO org.apache.kafka.clients.consumer.internals.AbstractCoordinator - [Consumer clientId=consumer-1, groupId=TestGroupId] Discovered group coordinator 99.14.230.91:9092 (id: 2147483547 rack: null)
16:24:39.004 [main] INFO org.apache.kafka.clients.consumer.internals.AbstractCoordinator - [Consumer clientId=consumer-1, groupId=TestGroupId] Group coordinator 99.14.230.91:9092 (id: 2147483547 rack: null) is unavailable or invalid, will attempt rediscovery
```
 
取到KafkaServer 的运行日志查看server.log，其地址在KafkaServer 运行目录的log 文件架下面，发现日志中有这个报错
 
```log
[2021-03-02 16:14:44,591] ERROR [KafkaApi-100] Error when handling request: clientId=100, correlationId=5, api=LEADER_AND_ISR, version=4, body={controller_id=100,controller_epoch=1,broker_epoch=26,topic_states=[{topic_name=__consumer_offsets,partition_states=[{partition_index=49,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=38,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=16,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=27,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=8,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=19,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=13,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=2,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=46,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=35,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=24,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=5,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=43,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=21,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=32,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=10,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=37,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=48,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=40,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=18,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=29,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=7,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=23,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=45,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=34,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=26,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=15,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=4,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=42,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=31,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=9,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=20,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=12,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=1,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=28,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=17,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=6,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=39,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=44,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=36,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=47,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=3,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=25,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=14,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=30,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=41,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=22,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=33,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=11,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}},{partition_index=0,controller_epoch=1,leader=100,leader_epoch=0,isr=[100],zk_version=0,replicas=[100],adding_replicas=[],removing_replicas=[],is_new=true,_tagged_fields={}}],_tagged_fields={}}],live_leaders=[{broker_id=100,host_name=99.14.230.91,port=9092,_tagged_fields={}}],_tagged_fields={}} (kafka.server.KafkaApis)
java.io.IOException: Map failed
    at sun.nio.ch.FileChannelImpl.map(FileChannelImpl.java:938)
    at kafka.log.AbstractIndex.<init>(AbstractIndex.scala:125)
    at kafka.log.TimeIndex.<init>(TimeIndex.scala:54)
    at kafka.log.LazyIndex$.$anonfun$forTime$1(LazyIndex.scala:109)
    at kafka.log.LazyIndex.$anonfun$get$1(LazyIndex.scala:63)
    at kafka.log.LazyIndex.get(LazyIndex.scala:60)
    at kafka.log.LogSegment.timeIndex(LogSegment.scala:67)
    at kafka.log.LogSegment.resizeIndexes(LogSegment.scala:78)
    at kafka.log.Log.loadSegments(Log.scala:754)
    at kafka.log.Log.<init>(Log.scala:300)
    at kafka.log.Log$.apply(Log.scala:2532)
    at kafka.log.LogManager.$anonfun$getOrCreateLog$1(LogManager.scala:812)
    at kafka.log.LogManager.getOrCreateLog(LogManager.scala:766)
    at kafka.cluster.Partition.createLog(Partition.scala:394)
    at kafka.cluster.Partition.createLogIfNotExists(Partition.scala:369)
    at kafka.cluster.Partition.$anonfun$makeLeader$1(Partition.scala:576)
    at kafka.cluster.Partition.makeLeader(Partition.scala:560)
    at kafka.server.ReplicaManager.$anonfun$makeLeaders$5(ReplicaManager.scala:1537)
    at kafka.utils.Implicits$MapExtensionMethods$.$anonfun$forKeyValue$1(Implicits.scala:62)
    at scala.collection.compat.MapExtensionMethods$.$anonfun$foreachEntry$1(PackageShared.scala:431)
    at scala.collection.mutable.HashMap.$anonfun$foreach$1(HashMap.scala:149)
    at scala.collection.mutable.HashTable.foreachEntry(HashTable.scala:237)
    at scala.collection.mutable.HashTable.foreachEntry$(HashTable.scala:230)
    at scala.collection.mutable.HashMap.foreachEntry(HashMap.scala:44)
    at scala.collection.mutable.HashMap.foreach(HashMap.scala:149)
    at kafka.server.ReplicaManager.makeLeaders(ReplicaManager.scala:1535)
    at kafka.server.ReplicaManager.becomeLeaderOrFollower(ReplicaManager.scala:1407)
    at kafka.server.KafkaApis.handleLeaderAndIsrRequest(KafkaApis.scala:246)
    at kafka.server.KafkaApis.handle(KafkaApis.scala:141)
    at kafka.server.KafkaRequestHandler.run(KafkaRequestHandler.scala:74)
    at java.lang.Thread.run(Thread.java:748)
Caused by: java.lang.OutOfMemoryError: Map failed
    at sun.nio.ch.FileChannelImpl.map0(Native Method)
    at sun.nio.ch.FileChannelImpl.map(FileChannelImpl.java:935)
    ... 30 more
```
 
结合Kafka 的源码，可以看到是在为分区选择Leader 的时候导致的异常，想到我自己的环境中只启动了一个KafkaServer，是不是因为这个原因，显然无法选出一个Leader，所以报错，于是重新在本地再配置基于9093 端口启动一个新的KafkaServer，并且连接到上面的Zookeeper 上，然后再运行Consumer，现在就可以正常消费了！
 
```cmd
// 启动KafkaServer 基于9093 端口
D:
set JAVA_HOME=C:\Program Files (x86)\Java\jdk1.8.0_201\jre
set PATH=%JAVA_HOME%\bin;%PATH%
cd \bigdata\kafka_2.12-2.7.0_9093/bin/windows/
kafka-server-start.bat ../../config/server.properties
```
 
这个只是结合经验，猜测出来解决了问题，并不是从源码层面分析的结果，关于KafkaApis 的源码需要好好看一下！！！
 
## KafkaApis 关于分区选择Leader 的源码分析
 
带着问题，基于上面的异常调用栈分析，首先说明一下KafkaApis，这个类封装了KafkaBroker 在收到各种类型的请求时，对应回调的函数，其核心方法就是handle()
 
```scala
/**
 * Top-level method that handles all requests and multiplexes to the right api
 */
override def handle(request: RequestChannel.Request): Unit = {
  try {
    trace(s"Handling request:${request.requestDesc(true)} from connection ${request.context.connectionId};" +
      s"securityProtocol:${request.context.securityProtocol},principal:${request.context.principal}")
    request.header.apiKey match {
      case ApiKeys.PRODUCE => handleProduceRequest(request)
      case ApiKeys.FETCH => handleFetchRequest(request)
      case ApiKeys.LIST_OFFSETS => handleListOffsetRequest(request)
      case ApiKeys.METADATA => handleTopicMetadataRequest(request)
      case ApiKeys.LEADER_AND_ISR => handleLeaderAndIsrRequest(request)
      case ApiKeys.STOP_REPLICA => handleStopReplicaRequest(request)
      case ApiKeys.UPDATE_METADATA => handleUpdateMetadataRequest(request)
      case ApiKeys.CONTROLLED_SHUTDOWN => handleControlledShutdownRequest(request)
      case ApiKeys.OFFSET_COMMIT => handleOffsetCommitRequest(request)
      case ApiKeys.OFFSET_FETCH => handleOffsetFetchRequest(request)
      case ApiKeys.FIND_COORDINATOR => handleFindCoordinatorRequest(request)
      case ApiKeys.JOIN_GROUP => handleJoinGroupRequest(request)
      case ApiKeys.HEARTBEAT => handleHeartbeatRequest(request)
      case ApiKeys.LEAVE_GROUP => handleLeaveGroupRequest(request)
      case ApiKeys.SYNC_GROUP => handleSyncGroupRequest(request)
      case ApiKeys.DESCRIBE_GROUPS => handleDescribeGroupRequest(request)
      case ApiKeys.LIST_GROUPS => handleListGroupsRequest(request)
      case ApiKeys.SASL_HANDSHAKE => handleSaslHandshakeRequest(request)
      case ApiKeys.API_VERSIONS => handleApiVersionsRequest(request)
      case ApiKeys.CREATE_TOPICS => handleCreateTopicsRequest(request)
      case ApiKeys.DELETE_TOPICS => handleDeleteTopicsRequest(request)
      case ApiKeys.DELETE_RECORDS => handleDeleteRecordsRequest(request)
      case ApiKeys.INIT_PRODUCER_ID => handleInitProducerIdRequest(request)
      case ApiKeys.OFFSET_FOR_LEADER_EPOCH => handleOffsetForLeaderEpochRequest(request)
      case ApiKeys.ADD_PARTITIONS_TO_TXN => handleAddPartitionToTxnRequest(request)
      case ApiKeys.ADD_OFFSETS_TO_TXN => handleAddOffsetsToTxnRequest(request)
      case ApiKeys.END_TXN => handleEndTxnRequest(request)
      case ApiKeys.WRITE_TXN_MARKERS => handleWriteTxnMarkersRequest(request)
      case ApiKeys.TXN_OFFSET_COMMIT => handleTxnOffsetCommitRequest(request)
      case ApiKeys.DESCRIBE_ACLS => handleDescribeAcls(request)
      case ApiKeys.CREATE_ACLS => handleCreateAcls(request)
      case ApiKeys.DELETE_ACLS => handleDeleteAcls(request)
      case ApiKeys.ALTER_CONFIGS => handleAlterConfigsRequest(request)
      case ApiKeys.DESCRIBE_CONFIGS => handleDescribeConfigsRequest(request)
      case ApiKeys.ALTER_REPLICA_LOG_DIRS => handleAlterReplicaLogDirsRequest(request)
      case ApiKeys.DESCRIBE_LOG_DIRS => handleDescribeLogDirsRequest(request)
      case ApiKeys.SASL_AUTHENTICATE => handleSaslAuthenticateRequest(request)
      case ApiKeys.CREATE_PARTITIONS => handleCreatePartitionsRequest(request)
      case ApiKeys.CREATE_DELEGATION_TOKEN => handleCreateTokenRequest(request)
      case ApiKeys.RENEW_DELEGATION_TOKEN => handleRenewTokenRequest(request)
      case ApiKeys.EXPIRE_DELEGATION_TOKEN => handleExpireTokenRequest(request)
      case ApiKeys.DESCRIBE_DELEGATION_TOKEN => handleDescribeTokensRequest(request)
      case ApiKeys.DELETE_GROUPS => handleDeleteGroupsRequest(request)
      case ApiKeys.ELECT_LEADERS => handleElectReplicaLeader(request)
      case ApiKeys.INCREMENTAL_ALTER_CONFIGS => handleIncrementalAlterConfigsRequest(request)
      case ApiKeys.ALTER_PARTITION_REASSIGNMENTS => handleAlterPartitionReassignmentsRequest(request)
      case ApiKeys.LIST_PARTITION_REASSIGNMENTS => handleListPartitionReassignmentsRequest(request)
      case ApiKeys.OFFSET_DELETE => handleOffsetDeleteRequest(request)
      case ApiKeys.DESCRIBE_CLIENT_QUOTAS => handleDescribeClientQuotasRequest(request)
      case ApiKeys.ALTER_CLIENT_QUOTAS => handleAlterClientQuotasRequest(request)
      case ApiKeys.DESCRIBE_USER_SCRAM_CREDENTIALS => handleDescribeUserScramCredentialsRequest(request)
      case ApiKeys.ALTER_USER_SCRAM_CREDENTIALS => handleAlterUserScramCredentialsRequest(request)
      case ApiKeys.ALTER_ISR => handleAlterIsrRequest(request)
      case ApiKeys.UPDATE_FEATURES => handleUpdateFeatures(request)
      // Until we are ready to integrate the Raft layer, these APIs are treated as
      // unexpected and we just close the connection.
      case ApiKeys.VOTE => closeConnection(request, util.Collections.emptyMap())
      case ApiKeys.BEGIN_QUORUM_EPOCH => closeConnection(request, util.Collections.emptyMap())
      case ApiKeys.END_QUORUM_EPOCH => closeConnection(request, util.Collections.emptyMap())
      case ApiKeys.DESCRIBE_QUORUM => closeConnection(request, util.Collections.emptyMap())
    }
  } catch {
    case e: FatalExitError => throw e
    case e: Throwable => handleError(request, e)
  } finally {
    // try to complete delayed action. In order to avoid conflicting locking, the actions to complete delayed requests
    // are kept in a queue. We add the logic to check the ReplicaManager queue at the end of KafkaApis.handle() and the
    // expiration thread for certain delayed operations (e.g. DelayedJoin)
    replicaManager.tryCompleteActions()
    // The local completion time may be set while processing the request. Only record it if it's unset.
    if (request.apiLocalCompleteTimeNanos < 0)
      request.apiLocalCompleteTimeNanos = time.nanoseconds
  }
}
```
 
导致报错的方法是handleLeaderAndIsrRequest(KafkaApis.scala:246)，用于处理Leader 选举和ISR 请求
 
```scala
def handleLeaderAndIsrRequest(request: RequestChannel.Request): Unit = {
  // ensureTopicExists is only for client facing requests
  // We can't have the ensureTopicExists check here since the controller sends it as an advisory to all brokers so they
  // stop serving data to clients for the topic being deleted
  val correlationId = request.header.correlationId
  val leaderAndIsrRequest = request.body[LeaderAndIsrRequest]
 
  def onLeadershipChange(updatedLeaders: Iterable[Partition], updatedFollowers: Iterable[Partition]): Unit = {
    // for each new leader or follower, call coordinator to handle consumer group migration.
    // this callback is invoked under the replica state change lock to ensure proper order of
    // leadership changes
    updatedLeaders.foreach { partition =>
      if (partition.topic == GROUP_METADATA_TOPIC_NAME)
        groupCoordinator.onElection(partition.partitionId)
      else if (partition.topic == TRANSACTION_STATE_TOPIC_NAME)
        txnCoordinator.onElection(partition.partitionId, partition.getLeaderEpoch)
    }
 
    updatedFollowers.foreach { partition =>
      if (partition.topic == GROUP_METADATA_TOPIC_NAME)
        groupCoordinator.onResignation(partition.partitionId)
      else if (partition.topic == TRANSACTION_STATE_TOPIC_NAME)
        txnCoordinator.onResignation(partition.partitionId, Some(partition.getLeaderEpoch))
    }
  }
 
  authorizeClusterOperation(request, CLUSTER_ACTION)
  if (isBrokerEpochStale(leaderAndIsrRequest.brokerEpoch)) {
    // When the broker restarts very quickly, it is possible for this broker to receive request intended
    // for its previous generation so the broker should skip the stale request.
    info("Received LeaderAndIsr request with broker epoch " +
      s"${leaderAndIsrRequest.brokerEpoch} smaller than the current broker epoch ${controller.brokerEpoch}")
    sendResponseExemptThrottle(request, leaderAndIsrRequest.getErrorResponse(0, Errors.STALE_BROKER_EPOCH.exception))
  } else {
    // replicaManager.becomeLeaderOrFollower(...) 就是报错的第246 行
    val response = replicaManager.becomeLeaderOrFollower(correlationId, leaderAndIsrRequest, onLeadershipChange)
    sendResponseExemptThrottle(request, response)
  }
}
```
 
最终调用到kafka.cluster.Partition.makeLeader(Partition.scala:560)，其相关的调用栈如下
 
```
at kafka.cluster.Partition.createLog(Partition.scala:394)
at kafka.cluster.Partition.createLogIfNotExists(Partition.scala:369)
at kafka.cluster.Partition.$anonfun$makeLeader$1(Partition.scala:576)
at kafka.cluster.Partition.makeLeader(Partition.scala:560)
```
 
对应的makeLeader(...) 的代码如下
 
```scala
/**
 * Make the local replica the leader by resetting LogEndOffset for remote replicas (there could be old LogEndOffset
 * from the time when this broker was the leader last time) and setting the new leader and ISR.
 * If the leader replica id does not change, return false to indicate the replica manager.
 */
def makeLeader(partitionState: LeaderAndIsrPartitionState,
               highWatermarkCheckpoints: OffsetCheckpoints): Boolean = {
  // 第560 行
  val (leaderHWIncremented, isNewLeader) = inWriteLock(leaderIsrUpdateLock) {
    // record the epoch of the controller that made the leadership decision. This is useful while updating the isr
    // to maintain the decision maker controller's epoch in the zookeeper path
    controllerEpoch = partitionState.controllerEpoch
    val isr = partitionState.isr.asScala.map(_.toInt).toSet
    val addingReplicas = partitionState.addingReplicas.asScala.map(_.toInt)
    val removingReplicas = partitionState.removingReplicas.asScala.map(_.toInt)
    updateAssignmentAndIsr(
      assignment = partitionState.replicas.asScala.map(_.toInt),
      isr = isr,
      addingReplicas = addingReplicas,
      removingReplicas = removingReplicas
    )
    try {
      // 第576 行
      createLogIfNotExists(partitionState.isNew, isFutureReplica = false, highWatermarkCheckpoints)
    } catch {
      case e: ZooKeeperClientException =>
        stateChangeLogger.error(s"A ZooKeeper client exception has occurred and makeLeader will be skipping the " +
          s"state change for the partition $topicPartition with leader epoch: $leaderEpoch ", e)
        return false
    }
    val leaderLog = localLogOrException
    val leaderEpochStartOffset = leaderLog.logEndOffset
    stateChangeLogger.info(s"Leader $topicPartition starts at leader epoch ${partitionState.leaderEpoch} from " +
      s"offset $leaderEpochStartOffset with high watermark ${leaderLog.highWatermark} " +
      s"ISR ${isr.mkString("[", ",", "]")} addingReplicas ${addingReplicas.mkString("[", ",", "]")} " +
      s"removingReplicas ${removingReplicas.mkString("[", ",", "]")}. Previous leader epoch was $leaderEpoch.")
    //We cache the leader epoch here, persisting it only if it's local (hence having a log dir)
    leaderEpoch = partitionState.leaderEpoch
    leaderEpochStartOffsetOpt = Some(leaderEpochStartOffset)
    zkVersion = partitionState.zkVersion
    // Clear any pending AlterIsr requests and check replica state
    alterIsrManager.clearPending(topicPartition)
    // In the case of successive leader elections in a short time period, a follower may have
    // entries in its log from a later epoch than any entry in the new leader's log. In order
    // to ensure that these followers can truncate to the right offset, we must cache the new
    // leader epoch and the start offset since it should be larger than any epoch that a follower
    // would try to query.
    leaderLog.maybeAssignEpochStartOffset(leaderEpoch, leaderEpochStartOffset)
    val isNewLeader = !isLeader
    val curTimeMs = time.milliseconds
    // initialize lastCaughtUpTime of replicas as well as their lastFetchTimeMs and lastFetchLeaderLogEndOffset.
    remoteReplicas.foreach { replica =>
      val lastCaughtUpTimeMs = if (isrState.isr.contains(replica.brokerId)) curTimeMs else 0L
      replica.resetLastCaughtUpTime(leaderEpochStartOffset, curTimeMs, lastCaughtUpTimeMs)
    }
    if (isNewLeader) {
      // mark local replica as the leader after converting hw
      leaderReplicaIdOpt = Some(localBrokerId)
      // reset log end offset for remote replicas
      remoteReplicas.foreach { replica =>
        replica.updateFetchState(
          followerFetchOffsetMetadata = LogOffsetMetadata.UnknownOffsetMetadata,
          followerStartOffset = Log.UnknownOffset,
          followerFetchTimeMs = 0L,
          leaderEndOffset = Log.UnknownOffset)
      }
    }
    // we may need to increment high watermark since ISR could be down to 1
    (maybeIncrementLeaderHW(leaderLog), isNewLeader)
  }
  // some delayed operations may be unblocked after HW changed
  if (leaderHWIncremented)
    tryCompleteDelayedRequests()
  isNewLeader
}
```
 
继续看createLogIfNotExists(...) 方法
 
```scala
def createLogIfNotExists(isNew: Boolean, isFutureReplica: Boolean, offsetCheckpoints: OffsetCheckpoints): Unit = {
  isFutureReplica match {
    case true if futureLog.isEmpty =>
      val log = createLog(isNew, isFutureReplica, offsetCheckpoints)
      this.futureLog = Option(log)
    case false if log.isEmpty =>
      // 第369 行
      val log = createLog(isNew, isFutureReplica, offsetCheckpoints)
      this.log = Option(log)
    case _ => trace(s"${if (isFutureReplica) "Future Log" else "Log"} already exists.")
  }
}
 
// Visible for testing
private[cluster] def createLog(isNew: Boolean, isFutureReplica: Boolean, offsetCheckpoints: OffsetCheckpoints): Log = {
  def fetchLogConfig: LogConfig = {
    val props = stateStore.fetchTopicConfig()
    LogConfig.fromProps(logManager.currentDefaultConfig.originals, props)
  }
 
  def updateHighWatermark(log: Log) = {
    val checkpointHighWatermark = offsetCheckpoints.fetch(log.parentDir, topicPartition).getOrElse {
      info(s"No checkpointed highwatermark is found for partition $topicPartition")
      0L
    }
    val initialHighWatermark = log.updateHighWatermark(checkpointHighWatermark)
    info(s"Log loaded for partition $topicPartition with initial high watermark $initialHighWatermark")
  }
 
  logManager.initializingLog(topicPartition)
  var maybeLog: Option[Log] = None
  try {
    // 第394 行
    val log = logManager.getOrCreateLog(topicPartition, () => fetchLogConfig, isNew, isFutureReplica)
    maybeLog = Some(log)
    updateHighWatermark(log)
    log
  } finally {
    logManager.finishedInitializingLog(topicPartition, maybeLog, () => fetchLogConfig)
  }
}
```
 
如此逐层跟着异常调用栈往下分析，最终找到报错的地方在kafka.log.AbstractIndex.<init>(AbstractIndex.scala:125)
 
```
@volatile
protected var mmap: MappedByteBuffer = {
  val newlyCreated = file.createNewFile()
  val raf = if (writable) new RandomAccessFile(file, "rw") else new RandomAccessFile(file, "r")
  try {
    /* pre-allocate the file if necessary */
    if(newlyCreated) {
      if(maxIndexSize < entrySize)
        throw new IllegalArgumentException("Invalid max index size: " + maxIndexSize)
      raf.setLength(roundDownToExactMultiple(maxIndexSize, entrySize))
    }
 
    /* memory-map the file */
    _length = raf.length()
    val idx = {
      if (writable)
        // 第125 行，尝试以读写方式打开文件，然后就是在这里报错的
        raf.getChannel.map(FileChannel.MapMode.READ_WRITE, 0, _length)
      else
        raf.getChannel.map(FileChannel.MapMode.READ_ONLY, 0, _length)
    }
    /* set the position in the index for the next entry */
    if(newlyCreated)
      idx.position(0)
    else
      // if this is a pre-existing index, assume it is valid and set position to last entry
      idx.position(roundDownToExactMultiple(idx.limit(), entrySize))
    idx
  } finally {
    CoreUtils.swallow(raf.close(), AbstractIndex)
  }
}
```
 
可以看到这里面用到了`raf.getChannel.map(FileChannel.MapMode.READ_WRITE, 0, _length)`，这个刚好也是Kafka 零拷贝的其中一点（mmap）
 
## 问题分析
 
再回到上面的问题，报错的信息是这样的
 
```
Caused by: java.lang.OutOfMemoryError: Map failed
    at sun.nio.ch.FileChannelImpl.map0(Native Method)
    at sun.nio.ch.FileChannelImpl.map(FileChannelImpl.java:935)
    ... 30 more
```
 
抽取上面的代码，主要的就是
 
```scala
val raf = new RandomAccessFile(file, "rw")
_length = raf.length()
 
// 这里到导致OutOfMemoryError
raf.getChannel.map(FileChannel.MapMode.READ_WRITE, 0, _length)
```
 
RandomAccessFile.getChannel() 方法获取相应的NIO 通道；RandomAccessFile.getChannel().map() 方法为文件创建一块内存映射区域，这块内存属于堆外内存
 
在最开始报错的情况下，其实当时只启动了一个Kafka Broker，其broker.id = 100，再回看上面报错的日志中有这样的信息的
 
```
ERROR [KafkaApi-100] Error when handling request: clientId=100, correlationId=5, api=LEADER_AND_ISR, version=4, body={....
```
 
因为集群中只有一个节点，看着像是broker.id = 100 自己连接到自己，尝试将自己作为另一个副本，然后自己因此又对文件做了一次内存映射，此时内存不够用了，所以导致内存溢出报错！
 
>当然以上只是猜测，比如为什么broker.id=100 为什么会和自己通讯？这个不太好解释后续还是会深究源码，验证这个猜测是否正确
 
## 简单总结
 
以上的流程是涉及到KafkaBroker 端对于分区的选Leader 的逻辑，以及ISR 的逻辑，涉及到的核心类有KafkaApis、ReplicaManager、Partition、LogManager、Log、LogSegment
 
关于KafkaServer 的详细实现架构，会慢慢体现在我的博客中！

