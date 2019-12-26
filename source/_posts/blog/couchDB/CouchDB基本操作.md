---
title: CouchDB基本操作
date: 2019-12-26 20:37:17
tags: CouchDb
categories: CouchDb应用
---
## CouchDB操作

判断数据库是否正常运行:
```
curl http://localhost:5984/_up | jq .
```
获取CouchDB唯一标识符(UUID):
```
curl http://localhost:5984/_uuids | jq .
```
获取CouchDB数据库信息:
```
curl http://localhost:5984/ | jq .
```
## 节点操作

### 查询节点
### 查询所有节点
查询当前节点连接的所有节点以及集群中的节点：
```
curl -u admin:admin http://localhost:5984/_membership
```
### 查询单个节点状态
```
curl -u admin:admin http://localhost:5984/_node/{node-name}/_stats
# 查询本地节点状态
curl -u admin:admin http://localhost:5984/_node/local/_stats 
```
## 数据库操作

### 查询数据库

查询所有数据库:
```
curl http://localhost:5984/_all_dbs | jq .
```
查询某个数据库详细信息:
```
curl http://localhost:5984/{db_name} | jq .
```

查询数据库更新事件:
```
curl -u admin:admin http://localhost:5984/_db_updates | jq .
```

查询数据库设计文档:
```
curl -u admin:admin http://localhost:5984/data/_design_docs | jq .
```

### 创建数据库
创建名称为`data`的数据库，分片数为1，副本数为2(包括源数据库).

* `-u`指定用户名与密码
* `-X`指定请求方法为`PUT`(不加`-X`默认为`GET`)
```
curl -u admin:admin -X PUT http://localhost:5984/data?q=1&n=2 | jq .
```

### 删除数据库
删除刚刚创建的数据库`data`。
```
curl -u admin:admin -X DELETE http://localhost:5984/data | jq .
```

### 更新数据库
为指定的数据库创建复合键:
```
curl -X POST  \
    -H "Content-Type:application/json" \
    -H "Host:localhost:5984" \
    -u admin:admin \
    http://localhost:5984/data/_all_docs \
    -d "{ \"_id\": [ \"abc\",\"bcd\" ]}" | jq .
```

为指定的本地数据库创建复合键:
```
curl -X POST  \
    -H "Content-Type:application/json" \
    -H "Host:localhost:5984" \
    -u admin:admin \
    http://localhost:5984/data/_local_docs \
    -d "{ \"_id\": [ \"abc\",\"bcd\" ]}" | jq .
```
### 数据库索引
查询指定数据库索引:
```
curl -u admin:admin \
    -H "Content-Type:application/json" \
    http://localhost:5984/data/_index | jq .
```
为指定数据库创建索引:

* 索引字段为`foo`
* 索引名称为`foo-index`
* 索引类型为`json`
```
curl -X POST \
    -u admin:admin \
    -H "Content-Type:application/json" \
    -H "localhost:5984" \
    http://localhost:5984/data/_index \
    -d "{ \"index\": { \"fields\": [\"foo\" ]}, \"name\":\"foo-index\",\"type\":\"json\"}" | jq .
```
删除索引:
```
curl -u admin:admin \
    -H "Content-Type:application/json" \
    -X DELETE \ http://localhost:5984/data/_index/{ddoc}/json/{index_name}
```

清空所有视图索引文件:
```
curl -X POST -u admin:admin http://localhost:5984/data/_view_cleanup
```
### 数据库分片
查询指定的数据库分片信息:
```
curl -u admin:admin \
    -H "Content-Type:application/json" \
    http://localhost:5984/data/_shards | jq .
```
根据文档ID查询指定的分片上存储的文档信息:
```
curl -u admin:admin \
    -H "Content-Type:application/json" \
    http://localhost:5984/data/_shards/{docid} | jq .
```
强制进行数据库分片信息同步:
```
curl -u admin:admin \
    -X POST \
    -H "Content-Type:application/json" \
    http://localhost:5984/data/_sync_shards | jq .
```
### 数据库压缩
压缩指定的数据库:
```
curl -u admin:admin \
    -X POST \
    -H "Content-Type:application/json" \
    http://localhost:5984/data/_compact | jq .
```

### 数据库安全
获取当前数据库安全对象:
```
curl -u admin:admin http://localhost:5984/data/_security | jq .
```
## 文档操作

### 查询文档
查询数据库`data`中所有文档:
```
curl -u admin:admin -H "Content-Type:application/json" http://localhost:5984/data/_all_docs | jq .
```

查询数据库`data`中的指定文档:
`cec6606d0ddaca2b555ebb8404a772a0`为指定的文档ID
```
curl -u admin:admin http://localhost:5984/data/cec6606d0ddaca2b555ebb8404a772a0 | jq .
```

查询数据库中文档的更新信息:
```
curl -u admin:admin \
    -H "Content-Type:application/json" \
    http://localhost:5984/data/_changes | jq .
```

查询本地数据库中的文档:
```
curl -u admin:admin http://localhost:5984/data/_local_docs | jq .
```
### 创建文档
向数据库`data`中创建`id`为`id`,标题为`demo`的新文档:

```
curl -X POST \
    -H "Content-Type:application/json" \
    -u admin:admin \
    http://localhost:5984/data/ \
    -d "{ \"_id\":\"id\",\"title\":\"demo\"}" | jq .
```

### 删除文档
从数据库`data`中删除指定的文档:
```
curl -X DELETE -u admin:admin http://localhost:5984/data/cec6606d0ddaca2b555ebb8404a772a0
```
