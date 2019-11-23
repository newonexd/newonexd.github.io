---
title: gRPC命名与发现
date: 2019-11-23 12:32:31
tags: etcd
---
etcd提供一个gRPC解析器支持备用的命名系统，该命名系统从etcd获取主机以发现gRPC服务。以下机制基于监视对以服务名称为前缀的Key的更新。
通过go-grpc使用etcd发现服务

* * *
etcd客户端提供一个gRPC解析器通过etcd后端解析gRPC主机,解析器通过etcd客户端初始化并指定了解析目标:
```
import (
        "go.etcd.io/etcd/clientv3"
        etcdnaming "go.etcd.io/etcd/clientv3/naming"

        "google.golang.org/grpc"
)

...

cli, cerr := clientv3.NewFromURL("http://localhost:2379")
r := &etcdnaming.GRPCResolver{Client: cli}
b := grpc.RoundRobin(r)
conn, gerr := grpc.Dial("my-service", grpc.WithBalancer(b), grpc.WithBlock(), ...)
```
### 管理服务主机
etcd解析器对于解析目标前缀下所有Keys后面跟一个"/"(例如"my-service/"),使用JSON编码go-grpc`naming.Update`值作为潜在的服务主机。通过创建一个新的Key将主机添加到服务中，通过删除Keys将主机从服务中删除。
### 添加一个主机
一个新的主机可以通过`etcdctl`添加到服务中：
```
ETCDCTL_API=3 etcdctl put my-service/1.2.3.4 '{"Addr":"1.2.3.4","Metadata":"..."}'
```
etcd客户端的`GRPCResolver.Update`方法也可以通过key匹配`Addr`注册一个新的主机到服务中：
```
r.Update(context.TODO(), "my-service", naming.Update{Op: naming.Add, Addr: "1.2.3.4", Metadata: "..."})
```
### 删除一个主机
通过etcdctl可以从服务中删除一个主机:
```
ETCDCTL_API=3 etcdctl del my-service/1.2.3.4
```
etcd 客户端的`GRPCResolver.Update`方法也可以删除一个主机：
```
r.Update(context.TODO(), "my-service", naming.Update{Op: naming.Delete, Addr: "1.2.3.4"})
```
### 注册一个主机并绑定一个租约
注册一个主机ging绑定一个租约确保如果主机不能维护保持存活的心跳(例如机器宕机)，该主机将会从服务中移除。
```
lease=`ETCDCTL_API=3 etcdctl lease grant 5 | cut -f2 -d' '`
ETCDCTL_API=3 etcdctl put --lease=$lease my-service/1.2.3.4 '{"Addr":"1.2.3.4","Metadata":"..."}'
ETCDCTL_API=3 etcdctl lease keep-alive $lease
```