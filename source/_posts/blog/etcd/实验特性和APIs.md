---
title: 实验特性和APIs
date: 2019-11-24 13:11:15
tags: etcd
---
原文地址:[Experimental features and APIs](https://github.com/etcd-io/etcd/blob/master/Documentation/dev-guide/experimental_apis.md)
大多数情况下，etcd项目是稳定的，但我们仍在快速发展！ 我们相信快速发布理念。 我们希望获得有关仍在开发和稳定中的功能的早期反馈。 因此，存在并且将会有更多的实验性功能和API。 我们计划根据社区的早期反馈来改进这些功能，如果兴趣不足，请在接下来的几个版本中放弃这些功能。 请不要在生产环境中依赖任何实验性功能或API。
## **当前实验API/特性是：**
* * *

* [键值对排序](https://godoc.org/github.com/etcd-io/etcd/clientv3/ordering)包装器：
当etcd客户端切换端点时，如果新端点落后于集群的其余部分，则对可序列化读取的响应可能推迟。排序包装器从响应标头缓存当前集群修订版。 如果响应修订版本小于缓存修订版本，则客户端选择另一个端点并重新发出读取。在grpcproxy中启动`--experimental-serializable-ordering`.
