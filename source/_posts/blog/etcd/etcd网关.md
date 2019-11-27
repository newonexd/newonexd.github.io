---
title: etcd网关
date: 2019-11-24 15:24:56
tags: etcd
categories: etcd文档翻译
---
原文地址:[L4 gateway](https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/gateway.md)
## 什么是etcd网关
* * *
etcd网关是一个简单的TCP代理，可将网络数据转发到etcd集群。网关是无状态且透明的； 它既不会检查客户端请求，也不会干扰群集响应。
网关支持多个etcd服务器端点，并采用简单的循环策略。 它仅路由到可用端点，并向其客户端隐藏故障。 将来可能会支持其他重试策略，例如加权轮询。

## 什么时候使用etcd网关
* * *
每个访问etcd的应用程序必须首先具有etcd集群客户端端点的地址。 如果同一服务器上的多个应用程序访问相同的etcd集群，则每个应用程序仍需要知道etcd集群的广播的客户端端点。 如果将etcd集群重新配置为具有不同的端点，则每个应用程序可能还需要更新其端点列表。 这种大规模的重新配置既乏味又容易出错。
etcd网关通过充当稳定的本地端点来解决此问题。 典型的etcd网关配置是，每台计算机运行一台网关，侦听本地地址，并且每个etcd应用程序都连接到其本地网关。 结果只是网关需要更新其端点，而不是更新每个应用程序。
总之，为了自动传播集群端点更改，etcd网关在为访问同一etcd集群的多个应用程序服务的每台机器上运行。

## 什么时候不该使用etcd网关

* 提升性能
该网关不是为提高etcd群集性能而设计的。 它不提供缓存，监视合并或批处理。 etcd团队正在开发一种缓存代理，旨在提高群集的可伸缩性。
* 在集群管理系统运行时
像Kubernetes这样的高级集群管理系统本身就支持服务发现。 应用程序可以使用系统管理的DNS名称或虚拟IP地址访问etcd集群。 例如，kube-proxy等效于etcd网关。
## 启动etcd网关
* * *
考虑一个具有以下静态端点的etcd集群：

|名字|地址|主机名|
|---|---|---|
|infra0|10.0.1.10|infra0.example.com|
|infra1|10.0.1.11|infra1.example.com|
|infra2|10.0.1.12|infra2.example.com|

通过以下命令使用静态端点启动etcd网关:
```
$ etcd gateway start --endpoints=infra0.example.com,infra1.example.com,infra2.example.com
2016-08-16 11:21:18.867350 I | tcpproxy: ready to proxy client requests to [...]
```
或者，如果使用DNS进行服务发现，请考虑DNS SRV条目：
```
$ dig +noall +answer SRV _etcd-client._tcp.example.com
_etcd-client._tcp.example.com. 300 IN SRV 0 0 2379 infra0.example.com.
_etcd-client._tcp.example.com. 300 IN SRV 0 0 2379 infra1.example.com.
_etcd-client._tcp.example.com. 300 IN SRV 0 0 2379 infra2.example.com.
```
```
$ dig +noall +answer infra0.example.com infra1.example.com infra2.example.com
infra0.example.com.  300  IN  A  10.0.1.10
infra1.example.com.  300  IN  A  10.0.1.11
infra2.example.com.  300  IN  A  10.0.1.12
```
启动etcd网关，以使用以下命令从DNS SRV条目中获取端点：
```
$ etcd gateway start --discovery-srv=example.com
2016-08-16 11:21:18.867350 I | tcpproxy: ready to proxy client requests to [...]
```

## 配置参数
* * *
#### **etcd 集群**

**--endpoints**

* 以逗号分隔的用于转发客户端连接的etcd服务器目标列表。
* 默认：`127.0.0.1:2379`
* 无效的例子:`https://127.0.0.1:2379`(网关不适用于TLS 终端)

**--discovery-srv**

* 用于通过SRV记录引导群集终结点的DNS域。
* 默认值：未设置

#### **网络**
**--listen-addr**

* 接收客户端请求绑定的接口和端口
* 默认:`127.0.0.1:23790`

**--retry-delay**

* 重试连接到失败的端点之前的延迟时间。
* 默认值：1m0s
* 无效例子："123"(期望之外的时间格式)

#### **安全**
**--insecure-discovery**

* 接受不安全或容易受到中间人攻击的SRV记录。
* 默认值：false

**--trusted-ca-file**

* etcd集群的客户端TLS CA文件的路径。 用于认证端点。
* 默认值：未设置