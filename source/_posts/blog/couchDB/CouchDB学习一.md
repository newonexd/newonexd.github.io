---
title: CouchDB学习一
date: 2019-12-19 20:54:41
tags: CouchDb学习
categories: CouchDB
---
## 端口

|端口号|协议|作用|
|---|---|---|
|5984|tcp|标椎集群端口用于所有的HTTP API请求|
|5986|tcp|用于管理员对节点与分片的管理|
|4369|tcp|Erlang端口到daemon的映射|

## 基本配置
### couchdb配置
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/couchdb/`后接参数.

* attachment_stream-buffer_size
    缓冲池大小，越大读性能越好，但增加写操作的响应时间.
* database_dir
    数据库文件地址
* default_security
    默认的安全级别`admin_local`. `everyone`:任何人都可以读和写。`admin_only`：只有admin可以读和写.`admin_local`:被分片的数据库可以被任何人读和写，但分片只可以被admin读和写.
* delayed_commits
    延迟提交 `false`保证同步.`true`可以提高性能。
* file_compression
    文件压缩默认`snappy`。`none`：不进行压缩。`snappy`：使用谷歌的snappy.`deflate_N`：使用`zlib`,N为压缩等级从1(速度最快，压缩率最低)到9(速度最慢，压缩率最高).
* fsync_options
    缓冲区内的文件是否与操作系统同步刷新到硬盘中.一般不需要修改.`fsync_options=[before_header,after_header,on_file_open]`
* max_dbs_open
    同时打开数据库的最大数量默认为100.
* os_process_timeout
    处理超时时间默认5000ms
* uri_file
    该参数指定的文件包含完整的用来访问CouchDB数据库实例的`URI`.默认值：`/var/run/couchdb/couchdb.uri`
* users_db_suffix
    用户数据库后缀，默认`_users`.
* util_driver_dir
    二进制驱动的位置。
* uuid
    CouchDb服务器实例的唯一标识符
* view_index_dir
    CouchDB视图索引文件的位置。默认值:`/var/lib/couchdb`
* maintenance_mode
    CouchDb节点可以使用的两种维护模式 `true`:该节点不会响应集群中其他节点的请求并且`/_up`端点将返回404响应.`nolb`:`/_up`端点将返回404响应.`false`:该节点正常响应200。
* max_document_size
    文档的最大的大小默认为4GB


## 操作
### 节点操作
#### 查看所有节点
```
curl -u admin:adminpw -X GET http://localhost:5984/_membership
{
    "all_nodes":[   # 当前节点所知道的节点
        "node1@xxx.xxx.xxx.xxx"],
    "cluster_nodes":[ #当前节点所连接的节点
        "node1@xxx.xxx.xxx.xxx"],
}
```
#### 添加一个节点
```
curl -u admin:adminpw -X PUT http://localhost:5986/_nodes/node2@yyy.yyy.yyy.yyy -d {}
```
#### 删除一个节点
```
#首先获取关于文档的revision
curl -u admin:adminpw -X GET "http://xxx.xxx.xxx.xxx:5986/_nodes/node2@yyy.yyy.yyy.yyy"
{"_id":"node2@yyy.yyy.yyy.yyy","_rev":"1-967a00dff5e02add41820138abb3284d"}	
#删除节点
curl -u admin:adminpw -X DELETE http://localhost:5986/_nodes/node2@yyy.yyy.yyy.yyy?rev=1-967a00dff5e02add41820138abb3284d
```

### 数据库操作
#### 创建数据库
数据库名字不支持大写字符，只支持[a-z],[0-9],以及特殊字符:`_ $ ( ) + - /`
```
#创建一个数据库名字为db_name q=4说明该数据库分为4个部分(片) n=2说明数据库有一个副本。
curl -u admin:adminpw -X PUT http://localhost:5984/db_name?q=4&n=2
```
#### 删除数据库
```
curl -u admin:adminpw -X DELETE http://localhost:5984/db_name
```