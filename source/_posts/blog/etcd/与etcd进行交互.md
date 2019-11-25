---
title: 与etcd进行交互
date: 2019-11-23 12:32:15
tags: etcd
---
原文地址：[Interacting with etcd](https://github.com/etcd-io/etcd/blob/master/Documentation/dev-guide/interacting_v3.md)
## 与etcd进行交互
用户更多的是通过putting或者是getting从etcd获取一个键对应的值。这一部分描述了如何通过etcdctl做这些工作。etcdctl是一个与etcd服务器进行交互的命令行工具.这里的描述适用于gRPC APIs或者是客户端库的APIs。
用于与etcd交互的API版本可以通过环境变量`ETCDCTL_API`设置为2或者3.默认情况下，分支为(3.4)的主版本使用V3 的API，而早期的版本(3.3或者更早)默认使用V2 API。
注意使用V2 API所创建的任何Key不能够通过V3 API进行访问。而V3 API `etcdctl get`获取V2 的Key将返回0并退出，这是预料之中的情况。
```
export ETCDCTL_API=3
```
### 发现版本
使用合适的命令在执行不同版本的etcd时etcdctl和服务器API的版本将会有用。
这里的命令可用于发现版本信息：
```
$ etcdctl version
etcdctl version:3.1.0-alpha.0+git
API version:3.1
```
### 写入一个KEY
应用程序通过向etcd集群写入Keys来存储Keys，每次存储的Key将会通过Raft协议实现一致性与可扩展性复制到所有的etcd集群成员中。
这里的命令是将Key`foo`的值存储到`bar`上：
```
$ etcdctl put foo bar
OK
```
给Key附上一个租约，Key将在一个具体的时间间隔被设置。
这里的命令是在10秒后将Key`foo`的值存储到`bar`上：
```
$ etcdctl put foo1 bar1 --lease=1234abcd
```
注意：以上命令中租约ID为1234abcd将会在租约创建10秒后将id返回，这个id将附在Key上。
### 读取Keys
应用程序可以从一个etcd集群中读取Key，可能会查询到单个Key，或者是一个范围内的Key。
比如etcd集群中存储以下Key：
```
foo = bar
foo1 = bar1
foo2 = bar2
foo3 = bar3
```
这里的命令是读取Key`foo`对应的值：
```
$ etcdctl get foo
foo
bar
```
这里的命令是读取Key`foo`对应的十六进制的值:
```
$ etcdctl get foo --hex
\x66\x6f\x6f       #Key
\x62\x61\x72       #Value
```
这里的命令是只读取Key`foo`对应的值：
```
$ etcdctl get foo --print-value-only
bar
```
这里的命令是读取从Key`foo`到Key`foo3`范围内对应的值：
```
$ etcdctl get foo foo3
foo
bar
foo1
bar1
foo2
bar2
```
注意这里Key为`foo3`不包括在内因为这里的范围是半开区间`[foo,foo3)`，不包括`foo3`。

这里的命令是获取前缀为`foo`的Key的范围内所有的值：
```
$ etcdctl get --prefix foo
foo
bar
foo1
bar1
foo2
bar2
foo3
bar3
```
这里的命令是获取前缀为`foo`的Key的范围内所有的值,并且限制结果集为2：
```
$ etcdctl get --prefix --limit=2 foo
foo
bar
foo1
bar1
```
### 读取之前版本的Keys：
应用程度可能希望读取一个被替代的版本的Key。例如，一个应用程序可能想要通过读取一个先前版本的Key来回滚到一个老的配置。另外，一个应用程序可能想要通过访问Key的历史记录对多个Key通过多个请求获取一致性的结果。由于对etcd集群中键值对的每一次修改都会增加对在etcd集群中的全局修订存储，应用程序可以通过提供一个老的版本来读取被替代的Keys。
比如一个etcd集群中存在以下的Keys：
```
foo = bar         # revision = 2
foo1 = bar1       # revision = 3
foo = bar_new     # revision = 4
foo1 = bar1_new   # revision = 5
```
这里的例子是访问过去版本的Keys：
```
$ etcdctl get --prefix foo # access the most recent versions of keys
foo
bar_new
foo1
bar1_new

$ etcdctl get --prefix --rev=4 foo # access the versions of keys at revision 4
foo
bar_new
foo1
bar1

$ etcdctl get --prefix --rev=3 foo # access the versions of keys at revision 3
foo
bar
foo1
bar1

$ etcdctl get --prefix --rev=2 foo # access the versions of keys at revision 2
foo
bar

$ etcdctl get --prefix --rev=1 foo # access the versions of keys at revision 1
```
### 读取大于或等于一个具体的Key的比特值的Key：
应用程序可能想要读取大于或等于一个具体的Key的byte值的Key。
一个etcd集群中有以下的Keys：
```
a = 123
b = 456
z = 789
```
这里的命令是读取大于或等于Key `b`的byte值的Key：
```
$ etcdctl get --from-key b
b
456
z
789
```
### 删除 Keys
应用程序可以从etcd集群中删除一个Key或者删除一个范围内的Key：
一个etcd集群中有以下的Keys：
```
foo = bar
foo1 = bar1
foo3 = bar3
zoo = val
zoo1 = val1
zoo2 = val2
a = 123
b = 456
z = 789
```
这里的命令是删除Key`foo`:
```
$ etcdctl del foo
1 # 1 个 key 被删除
```
这里的命令是删除从Key`foo`到Key`foo9`范围内的Key:
```
$ etcdctl del foo foo9
2 # 2 个 keys 被删除
```
这里的命令是删除Key`zoo`并将已删除的键值对返回:
```
$ etcdctl del --prev-kv zoo
1   # 1 个 key 被删除
zoo # 被删除的Key
val # 被删除的Key所对应的Value
```
这里的命令是删除前缀为`zoo`的Keys:
```
$ etcdctl del --prefix zoo
2 # 2 个 key 被删除
```
这里的命令是读取大于或等于Key `b`的byte值的Keys：
```
$ etcdctl del --from-key b
2 # 2 个 key 被删除
```
### 观察key的变化
应用程序可以监视一个Key或者一个范围内的Keys的每一次更新。
这里的命令是观察key`foo`:
```
$ etcdctl watch foo
# 在另一个终端执行: etcdctl put foo bar
PUT
foo
bar
```
这里的命令是观察十六进制的key`foo`:
```
$ etcdctl watch foo --hex
# 在另一个终端执行: etcdctl put foo bar
PUT
\x66\x6f\x6f          # Key
\x62\x61\x72          # Value
```
这里的命令是观察从Key`foo`到Key`foo9`范围内的Key：
```
$ etcdctl watch foo foo9
# 在另一个终端执行: etcdctl put foo bar
PUT
foo
bar
# 在另一个终端执行: etcdctl put foo1 bar1
PUT
foo1
bar1
```
这里的命令是观察前缀为`foo`的Key的范围内所有的值：
```
$ etcdctl watch --prefix foo
# 在另一个终端执行: etcdctl put foo bar
PUT
foo
bar
# 在另一个终端执行: etcdctl put fooz1 barz1
PUT
fooz1
barz1
```
这里的命令是观察多个Keys`foo`和`zoo`:
```
$ etcdctl watch -i
$ watch foo
$ watch zoo
# 在另一个终端执行: etcdctl put foo bar
PUT
foo
bar
# 在另一个终端执行: etcdctl put zoo val
PUT
zoo
val
```
### 观察Keys的历史版本
应用程序可能想要观察etcd中Keys的更新历史。例如，应用程序可能想获取key的所有修改；如果应用程序保持与etcd的连接，那么命令`watch`已经足够。然而，如果应用程序或者etcd宕机，一次更新可能就会失败，应用程序可能不能实时接收Key的更新。为了保证更新可以被交付，应用程序必须通过观察到Keys的历史更新。为了做到这些，应用程序要指定观察的历史版本，就像读取历史版本的Keys：
我们首先完成以下操作：
```
$ etcdctl put foo bar         # revision = 2
OK
$ etcdctl put foo1 bar1       # revision = 3
OK
$ etcdctl put foo bar_new     # revision = 4
OK
$ etcdctl put foo1 bar1_new   # revision = 5
OK
```
这里有个例子观察历史更新：
```
# watch for changes on key `foo` since revision 2
$ etcdctl watch --rev=2 foo
PUT
foo
bar
PUT
foo
bar_new
```
```
# watch for changes on key `foo` since revision 3
$ etcdctl watch --rev=3 foo
PUT
foo
bar_new
```
这里有例子只观察最后一次的更新：
```
# watch for changes on key `foo` and return last revision value along with modified value
$ etcdctl watch --prev-kv foo
# 在另一个终端执行 etcdctl put foo bar_latest
PUT
foo         # key
bar_new     # last value of foo key before modification
foo         # key
bar_latest  # value of foo key after modification
```
### 观察进度
应用程序可能想要检查观察者进度以确定最新的观察者流的状态。例如，如果观察者更新的缓存，那么就可以通过原子读取与修改进度进行比较知道缓存内容是否已经过时。
进度请求可以通过`progress`命令与观察者session进行交互在一个观察者流中告诉服务器发送一个进度提示更新.
```
$ etcdctl watch -i
$ watch a
$ progress
progress notify: 1
# 在另一个终端执行: etcdctl put x 0
# 在另一个终端执行: etcdctl put y 1
$ progress
progress notify: 3
```
注意，在进度提示响应中的修改号来自观察者流连接到的本地etcd服务器。如果该节点被分区并且不是该分区的一部分，这个进度提示修改版本可能会低于由未分区的etcd服务器节点返回的修改版本。
### 压缩修改
正如我们提到的，etcd保持修改信息所以应用可以读取过去版本的Keys，然而，为了避免无数的修改历史累积，对过去的修改进行压缩是很重要的。在压缩后，etcd移除了历史修改，释放资源为以后使用。在压缩修改版本之前所有的被修改的替代版本数据将不能获取。
这里的命令是对修改进行压缩：
```
$ etcdctl compact 5
compacted revision 5

# any revisions before the compacted one are not accessible
$ etcdctl get --rev=4 foo
Error:  rpc error: code = 11 desc = etcdserver: mvcc: required revision has been compacted
```
注意：etcd服务器的当前版本可以使用json格式的命令通过(存在或不存在的)key发现。例如下面的通过查看在etcd服务器中不存在的myKey:
```
$ etcdctl get mykey -w=json
{"header":{"cluster_id":14841639068965178418,"member_id":10276657743932975437,"revision":15,"raft_term":4}}
```
### 授予租约
应用程序可以为etcd集群上的Keys授予一个租约。当Key附上租约后，它的生命周期会绑定到租约的生命周期并由存活时间(TTL)进行管理。每一个租约都有一个由应用程序授予的最小的TTL值.这个租约实际的TTL值至少是最小的TTL值，由etcd集群决定。一旦超过租约的TTL，租约将会超时并删除附上的所有的Keys。
这里有命令授予一个租约：
```
# grant a lease with 60 second TTL
$ etcdctl lease grant 60
lease 32695410dcc0ca06 granted with TTL(60s)

# attach key foo to lease 32695410dcc0ca06
$ etcdctl put --lease=32695410dcc0ca06 foo bar
OK
```
### 撤销租约
应用程序可以根据租约ID撤销租约，撤销一个租约将删除附上的所有的Keys。
例如我们完成下面的操作：
```
$ etcdctl lease grant 60
lease 32695410dcc0ca06 granted with TTL(60s)
$ etcdctl put --lease=32695410dcc0ca06 foo bar
OK
```
这里的命令可以撤销该租约：
```
$ etcdctl lease revoke 32695410dcc0ca06
lease 32695410dcc0ca06 revoked

$ etcdctl get foo
# empty response since foo is deleted due to lease revocation
```
### 保持租约存活
应用程序可以通过刷新租约的TTL使它不会超时保证租约存活。
例如我们完成下面的操作：
```
$ etcdctl lease grant 60
lease 32695410dcc0ca06 granted with TTL(60s)
```
这里有命令保持租约存活：
```
$ etcdctl lease keep-alive 32695410dcc0ca06
lease 32695410dcc0ca06 keepalived with TTL(60)
lease 32695410dcc0ca06 keepalived with TTL(60)
lease 32695410dcc0ca06 keepalived with TTL(60)
...
```
### 获取租约信息
应用程序可能想知道关于租约的信息，所以可以通过重新创建或者检查租约是否仍然生存或已经超时。应用程序可能也想知道一个具体的租约上所附的Key。
例如我们完成下面的操作：
```
# grant a lease with 500 second TTL
$ etcdctl lease grant 500
lease 694d5765fc71500b granted with TTL(500s)

# attach key zoo1 to lease 694d5765fc71500b
$ etcdctl put zoo1 val1 --lease=694d5765fc71500b
OK

# attach key zoo2 to lease 694d5765fc71500b
$ etcdctl put zoo2 val2 --lease=694d5765fc71500b
OK
```
这里有命令获取关于租约的信息:
```
$ etcdctl lease timetolive 694d5765fc71500b
lease 694d5765fc71500b granted with TTL(500s), remaining(258s)
```
这里有命令获取租约上所依附的关于Keys的信息：
```
$ etcdctl lease timetolive --keys 694d5765fc71500b
lease 694d5765fc71500b granted with TTL(500s), remaining(132s), attached keys([zoo2 zoo1])

# if the lease has expired or does not exist it will give the below response:
Error:  etcdserver: requested lease not found
```