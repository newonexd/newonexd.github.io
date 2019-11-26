---
title: HTTP_JSON_API通过gRPC网关
date: 2019-11-23 12:32:38
tags: etcd
---
原文地址:[HTTP JSON API through the gRPC gateway](https://github.com/etcd-io/etcd/blob/master/Documentation/dev-guide/api_grpc_gateway.md)
etcd v3 使用 gRPC 作为消息协议。etcd项目包括一个基于gRPC的[Go客户端](https://newonexd.github.io/2019/11/23/blog/etcd/%E5%AE%A2%E6%88%B7%E7%AB%AFv3/)和一个命令行工具，[etcdctl](https://github.com/etcd-io/etcd/tree/master/etcdctl),通过gRPC与etcd集群进行交互.对于没有gRPC支持的语言，etcd提供JSON [gRPC网关](https://github.com/grpc-ecosystem/grpc-gateway)，这个网关提供一个RESTful风格的代理可以将HTTP/JSON请求转换为gRPC消息。
### 使用 gRPC网关
这个网关接受一个到etcd's buffer协议消息定义的JSON格式的映射,注意`Key`和`Value`字段定义为byte 数组，因此JSON必须使用base64编码,下面的例子使用`curl`,但是每个HTTP/JSON客户端的工作原理都和例子相同。
**注意**
gRPC网关节点从etcd v3.3发生变化：

* etcd v3.2以及之前版本只使用`[CLIENT-URL]/v3alpha/*`。
* etcd v3.3使用`[CLIENT-URL]/v3beta/*`保持`[CLIENT-URL]/v3alpha/*`使用。
* etcd v3.4使用`[CLIENT-URL]/v3/*`保持`[CLIENT-URL]/v3beta/*`使用。
    * `[CLIENT-URL]/v3alpha/*`被抛弃使用。
* etcd v3.5以及最新版本只使用`[CLIENT-URL]/v3/*`。
    * `[CLIENT-URL]/v3beta/*`被抛弃使用。

### 存储和获取Keys
使用`/v3/kv/range`和`/v3/kv/put`服务读和写Keys:
```
<<COMMENThttps://www.base64encode.org/foo is 'Zm9v' in Base64bar is 'YmFy'COMMENT

curl -L http://localhost:2379/v3/kv/put \
  -X POST -d '{"key": "Zm9v", "value": "YmFy"}'# {"header":{"cluster_id":"12585971608760269493","member_id":"13847567121247652255","revision":"2","raft_term":"3"}}

curl -L http://localhost:2379/v3/kv/range \
  -X POST -d '{"key": "Zm9v"}'# {"header":{"cluster_id":"12585971608760269493","member_id":"13847567121247652255","revision":"2","raft_term":"3"},"kvs":[{"key":"Zm9v","create_revision":"2","mod_revision":"2","version":"1","value":"YmFy"}],"count":"1"}

# get all keys prefixed with "foo"
curl -L http://localhost:2379/v3/kv/range \
  -X POST -d '{"key": "Zm9v", "range_end": "Zm9w"}'# {"header":{"cluster_id":"12585971608760269493","member_id":"13847567121247652255","revision":"2","raft_term":"3"},"kvs":[{"key":"Zm9v","create_revision":"2","mod_revision":"2","version":"1","value":"YmFy"}],"count":"1"}
```
### 查看 Keys
使用`/v3/watch`服务查看Keys:
```
curl -N http://localhost:2379/v3/watch \
  -X POST -d '{"create_request": {"key":"Zm9v"} }' &# {"result":{"header":{"cluster_id":"12585971608760269493","member_id":"13847567121247652255","revision":"1","raft_term":"2"},"created":true}}

curl -L http://localhost:2379/v3/kv/put \
  -X POST -d '{"key": "Zm9v", "value": "YmFy"}' >/dev/null 2>&1# {"result":{"header":{"cluster_id":"12585971608760269493","member_id":"13847567121247652255","revision":"2","raft_term":"2"},"events":[{"kv":{"key":"Zm9v","create_revision":"2","mod_revision":"2","version":"1","value":"YmFy"}}]}}
```
### 交易
使用``/v3/kv/txn`发行一个交易：
```
# 目标创建
curl -L http://localhost:2379/v3/kv/txn \
  -X POST \
  -d '{"compare":[{"target":"CREATE","key":"Zm9v","createRevision":"2"}],"success":[{"requestPut":{"key":"Zm9v","value":"YmFy"}}]}'# {"header":{"cluster_id":"12585971608760269493","member_id":"13847567121247652255","revision":"3","raft_term":"2"},"succeeded":true,"responses":[{"response_put":{"header":{"revision":"3"}}}]}
```
```
# 目标版本
curl -L http://localhost:2379/v3/kv/txn \
  -X POST \
  -d '{"compare":[{"version":"4","result":"EQUAL","target":"VERSION","key":"Zm9v"}],"success":[{"requestRange":{"key":"Zm9v"}}]}'# {"header":{"cluster_id":"14841639068965178418","member_id":"10276657743932975437","revision":"6","raft_term":"3"},"succeeded":true,"responses":[{"response_range":{"header":{"revision":"6"},"kvs":[{"key":"Zm9v","create_revision":"2","mod_revision":"6","version":"4","value":"YmF6"}],"count":"1"}}]}
```
### 权限
使用`/v3/auth`设置权限：
```
# 创建root用户
curl -L http://localhost:2379/v3/auth/user/add \
  -X POST -d '{"name": "root", "password": "pass"}'# {"header":{"cluster_id":"14841639068965178418","member_id":"10276657743932975437","revision":"1","raft_term":"2"}}

# 创建root角色
curl -L http://localhost:2379/v3/auth/role/add \
  -X POST -d '{"name": "root"}'# {"header":{"cluster_id":"14841639068965178418","member_id":"10276657743932975437","revision":"1","raft_term":"2"}}

# 授予root角色
curl -L http://localhost:2379/v3/auth/user/grant \
  -X POST -d '{"user": "root", "role": "root"}'# {"header":{"cluster_id":"14841639068965178418","member_id":"10276657743932975437","revision":"1","raft_term":"2"}}

# 开启认证
curl -L http://localhost:2379/v3/auth/enable -X POST -d '{}'# {"header":{"cluster_id":"14841639068965178418","member_id":"10276657743932975437","revision":"1","raft_term":"2"}}
```
通过`/v3/auth/authenticate`服务使用一个认证令牌进行认证:
```
# 为根用户获取认证令牌
curl -L http://localhost:2379/v3/auth/authenticate \
  -X POST -d '{"name": "root", "password": "pass"}'# {"header":{"cluster_id":"14841639068965178418","member_id":"10276657743932975437","revision":"1","raft_term":"2"},"token":"sssvIpwfnLAcWAQH.9"}
```
使用认证证书设置认证头部到认证令牌获取Keys：
```
curl -L http://localhost:2379/v3/kv/put \
  -H 'Authorization : sssvIpwfnLAcWAQH.9' \
  -X POST -d '{"key": "Zm9v", "value": "YmFy"}'# {"header":{"cluster_id":"14841639068965178418","member_id":"10276657743932975437","revision":"2","raft_term":"2"}}
```