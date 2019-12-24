---
title: CouchDB学习-API
date: 2019-12-24 10:52:40
tags: CouchDb
categories: CouchDb学习
---
# API

API URL路径可以指定访问CouchDB服务器的某个组件。URL请求结果包括标识和访问的数据库中的高效的描述字段。
与所有URL一样，各个组件之间用正斜杠分隔。
通常，以_（下划线）字符开头的URL组件和JSON字段表示服务器或返回的对象中的特殊组件或实体。例如，URL片段`/_all_dbs`获取CouchDB实例中所有数据库的列表。
该引用根据URL结构进行构造，如下所示。

## 1 基本API

CouchDB API是与CouchDB实例接口的主要方法。使用HTTP发出请求，请求用于从数据库请求信息，存储新数据以及对文档中存储的信息进行查看和格式化。
对API的请求可以按您正在访问的CouchDB系统的不同区域以及用于发送请求的HTTP方法进行分类。不同的方法意味着不同的操作，例如，从数据库中检索信息通常由`GET`操作处理，而更新则由`POST`或`PUT`请求处理。不同方法必须提供的信息之间存在一些差异。有关基本HTTP方法和请求结构的指南，请参见请求格式和响应。
对于几乎所有操作，都在JavaScript对象表示法（JSON）对象中定义了提交的数据和返回的数据结构。 JSON基础知识中提供了有关JSON内容和数据类型的基本信息。
使用标准HTTP状态代码报告访问CouchDB API时的错误。 HTTP状态代码中提供了有关CouchDB返回的通用代码的指南。
访问CouchDB API的特定区域时，将提供有关HTTP方法和请求，JSON结构和错误代码的特定信息和示例。

### 1.1 请求格式和响应

CouchDB支持以下HTTP请求方法：

* `GET`:请求指定的条目。
* `HEAD`：获取HTTP请求头部信息
* `POST`：上传数据
* `PUT`：用于PUT指定的资源，如创建新的对象(数据库，文档，视图，设计文档)
* `DELETE`：删除指定的资源
* `COPY`：特殊的方法，用于拷贝文档和对象

如果使用CouchDB不支持的HTTP请求类型，将会返回状态码`405-Method Not Allowed`.

### 1.2 HTTP请求头

CouchDB使用HTTP进行所有通信。所以需要确保正确的并且是被支持的HTTP头部信息。

#### 1.2.1 请求头

* `Accept`:由服务器返回指定的被接受的数据类型列表
* `Content-type`：指定请求中提供的信息的内容类型

#### 1.2.2 响应头

* `Cache-control`：缓存控制
* `Content-length`：返回的内容的长度
* `Content-type`：指定的返回数据的MIME类型
* `Etag`：显示文档或者视图的修订版本
* `Transfer-Encoding`：如果响应使用编码，那么则在该字段中指定


### 1.3 JSON基础
### 1.4 HTTP状态码

* 200 - `OK`：请求完全成功
* 201 - `Created`：文档成功创建
* 202 - `Accepted`：请求被接受，但是相关的操作可能不完整，经常用于后台操作如数据库压缩。
* 304 - `Not Modified`：请求的其他内容尚未修改。
* 400 - `Bad Request`：坏的请求结构，如错误的请求URL，路径或请求头。
* 401 - `Unauthorized`：不具备获取指定数据的权限，或者权限不支持
* 403 - `Forbidden`：请求被服务器拒绝
* 404 - `Not Found`：没有找到请求的数据
* 405 - `Method Not Allowed`：请求方法不被支持
* 406 - `Not Acceptable`：请求的内容类型不被支持
* 409 - `Conflict`：更新数据冲突
* 412 - `Preconfition Failed`：客户端的请求头和服务器的兼容性不匹配
* 413 - `Request Entity Too Large`：请求的数据过大
* 415 - `Unsupported Media Type`：支持的内容类型以及正在请求或提交的信息的内容类型表示不支持该内容类型。
* 416 - `Requested Range Not Satisfiable`：服务器无法满足请求标头中指定的范围。
* 417 - `Expectation Failed`：批量发送文档时，批量加载操作失败。
* 500 - `Internal Server Error`：请求无效


## 2 服务器
### 2.1 `/`
`GET /`:访问CouchDB实例的Root并返回关于实例的元数据。
**请求头：**
&emsp;&emsp;&emsp;&emsp;    * `Accept-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain`
**响应头：**
&emsp;&emsp;&emsp;&emsp;    * `Content-Type-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain;charset=utf-8`
**状态码：**
&emsp;&emsp;&emsp;&emsp;    * 200 `OK`

### 2.2 `/_active_tasks`

`GET /_active_tasks`:列出运行中的任务，包括任务类型，名字，状态和进程ID。
**请求头：**
&emsp;&emsp;&emsp;&emsp;    * `Accept-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain`
**响应头：**
&emsp;&emsp;&emsp;&emsp;    * `Content-Type-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain;charset=utf-8`
**响应JSON对象：**
&emsp;&emsp;&emsp;&emsp;    * `changes_done(number):`处理的变更
&emsp;&emsp;&emsp;&emsp;    * `database(string):`源数据库
&emsp;&emsp;&emsp;&emsp;    * `pid(string):`进程ID
&emsp;&emsp;&emsp;&emsp;    * `progress(number):`当前进度百分比
&emsp;&emsp;&emsp;&emsp;    * `started_on(number):`任务开始时间
&emsp;&emsp;&emsp;&emsp;    * `status(string):`任务状态信息
&emsp;&emsp;&emsp;&emsp;    * `task(string):`任务名称
&emsp;&emsp;&emsp;&emsp;    * `total_changes(number):`进程总的改变
&emsp;&emsp;&emsp;&emsp;    * `type(string):`操作类型
&emsp;&emsp;&emsp;&emsp;    * `update_on(number):`最后一次更新时间
**状态码：**
&emsp;&emsp;&emsp;&emsp;    * 200 `OK`
&emsp;&emsp;&emsp;&emsp;    * 401 `Unauthorized`

### 2.3 `/_all_dbs`

`GET /_all_dbs`:返回CouchDB实例所有数据库列表
**请求头：**
&emsp;&emsp;&emsp;&emsp;    * `Accept-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain`
**请求参数：**
&emsp;&emsp;&emsp;&emsp;    * `descending(boolean):`按键降序返回数据库。 默认为false。
&emsp;&emsp;&emsp;&emsp;    * `endkey(json):`到达指定的键时，停止返回数据库。
&emsp;&emsp;&emsp;&emsp;    * `end_key(json):`endkey的别名
&emsp;&emsp;&emsp;&emsp;    * `limit(number):`返回数据库数量的限制
&emsp;&emsp;&emsp;&emsp;    * `skip(number):`跳过此值得数据库，默认为0
&emsp;&emsp;&emsp;&emsp;    * `startkey(json):`从指定的键返回数据库
&emsp;&emsp;&emsp;&emsp;    * `start_key(json):`startkey的别名
**响应头：**
&emsp;&emsp;&emsp;&emsp;    * `Content-Type-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain;charset=utf-8`
**状态码：**
&emsp;&emsp;&emsp;&emsp;    * `200 OK`

### 2.4 `/_dbs_info`

`GET /_dbs_info`:返回CouchDB实例所有数据库列表的数据库信息
**请求头：**
&emsp;&emsp;&emsp;&emsp;    * `Accept-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
**响应头：**
&emsp;&emsp;&emsp;&emsp;    * `Content-Type-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
**请求JSON对象：**
&emsp;&emsp;&emsp;&emsp;    * `keys(array):`被请求的数据库名字(数组)
**状态码：**
&emsp;&emsp;&emsp;&emsp;    * 200 `OK`

### 2.5 `/_cluster_setup`

`GET /_cluster_setup`:根据群集设置向导返回节点或群集的状态。
**请求头：**
&emsp;&emsp;&emsp;&emsp;    * `Accept-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain`
**请求参数：**
&emsp;&emsp;&emsp;&emsp;    * `ensure_dbs_exist(array):`列出系统数据库确保在节点/集群上存在,默认：`["_users","_replicator", "_global_changes"]`.
**响应头：**
&emsp;&emsp;&emsp;&emsp;    * `Content-Type-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain;charset=utf-8`
**响应JSON对象：**
&emsp;&emsp;&emsp;&emsp;    * `state(string):`节点/集群的当前状态(见下面)
**状态码：**
&emsp;&emsp;&emsp;&emsp;    * 200 `OK`

**STATE**

* `cluster_disabled`:当前节点完全没有被配置。
* `single_node_disabled`：当前节点被配置为单节点，不具备服务器基本的管理员用户定义并且完整的标准系统数据库没有被创建。如果指定了`ensure_dbs_exist`查询参数，则提供的数据库列表将覆盖标准系统数据库的默认列表。
* `single_node_enabled`：当前节点被配置为单节点，具有服务器基本的管理员用户定义并且`ensure_dbs_exist`列表中的数据库已经被创建。
* `cluster_enabled`：当前节点集群数量大于1，没有绑定在`127.0.0.1`，具有服务器基本的管理员用户定义但是完整的标准系统数据库没有被创建。如果指定了`ensure_dbs_exist`查询参数，则提供的数据库列表将覆盖标准系统数据库的默认列表。
* `cluster_finished`：当前节点集群数量大于1，没有绑定在`127.0.0.1`，具有服务器基本的管理员用户定义并且`ensure_dbs_exist`列表中的数据库已经被创建。

`POST /_cluster_setup`:配置一个节点作为单节点，或者是集群的一部分，或者完成集群。
**请求头：**
&emsp;&emsp;&emsp;&emsp;    * `Accept-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain`
**请求JSON对象：**
&emsp;&emsp;&emsp;&emsp;    * `action(string):`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `enable_single_node:`配置当前节点为单节点
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `enable_cluster:`配置本地或远程节点，准备将它添加到新的CouchDB集群
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `add_node:`添加一个指定的远程节点到该集群列表中
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `finish_cluster:`完成集群的创建并创建标准的系统数据库
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `bind_address(string):`当前节点绑定的IP地址
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `username(string):`服务器级别的管理员用户名
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `password(string):`服务器级别的管理员密码
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `port(number):`该节点或远程节点(只用于`add_node`)绑定的TCP端口
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `node_count(number):`集群中节点总数
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `remote_node(string):`配置集群中的远程该节点的IP地址
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `remote_current_user(string):`服务器级别的管理员授权到远程节点的管理员用户名
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `remote_current_password(string):`服务器级别的管理员授权到远程节点的管理员密码
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `host(string):`添加到集群的远程节点的IP地址
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `ensure_dbs_exist(array):`列出系统数据库确保在该节点上存在。

### 2.6 `/_db_updates`

`GET /_db_updates`:返回CouchDB实例上所有数据库事件列表
**请求头：**
&emsp;&emsp;&emsp;&emsp;    * `Accept-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain`
**请求参数：**
&emsp;&emsp;&emsp;&emsp;    * `feed(string)`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `normal`:返回所有数据库历史变化，然后关闭连接。
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `longpoll`:在第一次事件后关闭连接
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `continuous`:每个事件发送一行JSON，一直保持socket开启直到超时。
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `eventsource`:与`continuous`相似，只是以`EventSource`格式发送。
&emsp;&emsp;&emsp;&emsp;    * `timeout(number)`：指定多少秒后关闭CouchDB连接
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `heartbeat(number)`:每隔多少周期毫秒发送空行保持连接，默认60000
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `since(string)`:仅返回指定的序列ID更新
**响应头：**
&emsp;&emsp;&emsp;&emsp;    * `Content-Type-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain;charset=utf-8`
**响应JSON对象：**
&emsp;&emsp;&emsp;&emsp;    * `results(array)`:数据库事件的数组
&emsp;&emsp;&emsp;&emsp;    * `last_seq(string)`:记录的最后一个序列ID
**状态码：**
&emsp;&emsp;&emsp;&emsp;    * 200 `OK`
&emsp;&emsp;&emsp;&emsp;    * 404 `Unauthorized`
**JSON对象：**
&emsp;&emsp;&emsp;&emsp;    * `db_name(string):`数据库名称
&emsp;&emsp;&emsp;&emsp;    * `type(string):`数据库事件类型(`created,updated,deleted`)
&emsp;&emsp;&emsp;&emsp;    * `seq(json):`事件更新序列

### 2.7 `/_membership`

`GET /_membership`:显示`cluster_nodes`集群中的部分节点。 `all_nodes`字段显示该节点知道的所有节点，包括属于集群的节点。在设置集群时非常有用，
**请求头：**
&emsp;&emsp;&emsp;&emsp;    * `Accept-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain`
**响应头：**
&emsp;&emsp;&emsp;&emsp;    * `Content-Type-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain;charset=utf-8`
**状态码：**
&emsp;&emsp;&emsp;&emsp;    * 200 `OK`
### 2.8 `/_replicate`
`GET /_replicate`:请求，配置或停止复制操作
**请求头：**
&emsp;&emsp;&emsp;&emsp;    * `Accept-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain`
&emsp;&emsp;&emsp;&emsp;    * `Content-Type:` `application/json`
**请求JSON对象:**
&emsp;&emsp;&emsp;&emsp;        * `cancel(boolean):`取消复制
&emsp;&emsp;&emsp;&emsp;        * `continuous(boolean):`继续复制
&emsp;&emsp;&emsp;&emsp;        * `create_target(boolean):`创建目标数据库，要求管理员权限
&emsp;&emsp;&emsp;&emsp;        * `doc_ids(array):`同步的文档ID的数组
&emsp;&emsp;&emsp;&emsp;        * `filter(string):`过滤器函数的名字
&emsp;&emsp;&emsp;&emsp;        * `proxy(string):`代理服务器的地址
&emsp;&emsp;&emsp;&emsp;        * `source(string/object):`源数据库名字或URL或对象，包含完整的源数据库URL以及参数例如头部信息
&emsp;&emsp;&emsp;&emsp;        * `target(string/object):`目标数据库名字或URL或对象，包含完整的目标数据库URL以及参数例如头部信息
**响应头：**
&emsp;&emsp;&emsp;&emsp;    * `Content-Type-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `text/plain;charset=utf-8`
**响应JSON对象:**
&emsp;&emsp;&emsp;&emsp;        * `history(array):`复制历史(见下面)
&emsp;&emsp;&emsp;&emsp;        * `ok(boolean):`复制状态
&emsp;&emsp;&emsp;&emsp;        * `replication_id_version(number):`复制协议版本
&emsp;&emsp;&emsp;&emsp;        * `session_id(string):`唯一的sessionID
&emsp;&emsp;&emsp;&emsp;        * `source_last_seq(number):`从源数据库读取的最后的序列号
**状态码：**
&emsp;&emsp;&emsp;&emsp;    * 200 `OK`
&emsp;&emsp;&emsp;&emsp;    * 202 `Accepted`
&emsp;&emsp;&emsp;&emsp;    * 400 `Bad Request`
&emsp;&emsp;&emsp;&emsp;    * 401 `Unauthorized`
&emsp;&emsp;&emsp;&emsp;    * 404 `Not Found`
&emsp;&emsp;&emsp;&emsp;    * 500 `Internal Server Error`
**JSON对象:**
&emsp;&emsp;&emsp;&emsp;        * `doc_write_failures(number):`文档写失败的数量
&emsp;&emsp;&emsp;&emsp;        * `docs_read(number):`文档读取的数量
&emsp;&emsp;&emsp;&emsp;        * `docs_written (number):`文档成功写到目标的数量
&emsp;&emsp;&emsp;&emsp;        * `end_last_seq (number):`更新流中最后的序列号
&emsp;&emsp;&emsp;&emsp;        * `end_time (string):`复制操作完成的时间
&emsp;&emsp;&emsp;&emsp;        * `missing_checked (number):`检查到的缺失的文档数量
&emsp;&emsp;&emsp;&emsp;        * `missing_found (number):`缺失的文档被发现的数量
&emsp;&emsp;&emsp;&emsp;        * `recorded_seq (number):`记录的最后的序列号
&emsp;&emsp;&emsp;&emsp;        * `session_id (string):`这次复制操作的SessionID
&emsp;&emsp;&emsp;&emsp;        * `start_last_seq (number):`更新流中第一个序列号
&emsp;&emsp;&emsp;&emsp;        * `start_time (string):`复制操作开始的时间

#### 2.8.1 复制操作

复制的目的是，在过程结束时，源数据库上的所有活动文档也都在目标数据库中，并且在源数据库中删除的所有文档也都在目标数据库上被删除（如果存在）。
复制可以描述为推式或拉式复制：
&emsp;&emsp;&emsp;&emsp; * 拉复制是当远程CouchDB实例是源数据库，目标是本地数据库的位置。
如果源数据库具有永久IP地址，而目标（本地）数据库可能具有动态分配的IP地址（例如，通过DHCP），则Pull复制是最有用的解决方案。 如果要从中央服务器复制到移动设备或其他设备，则这尤其重要。
&emsp;&emsp;&emsp;&emsp; * 推复制是当本地数据库为源数据库，远程数据库为目标数据库。

#### 2.8.2 指定源和目标数据库

如果要在以下两种情况之一中执行复制，则必须使用CouchDB数据库的URL规范：
&emsp;&emsp;&emsp;&emsp; * 使用远程数据库进行复制（即CouchDB的另一个实例在同一主机或其他主机上）
&emsp;&emsp;&emsp;&emsp; * 数据库复制需要权限认证。
例如，要请求向其发送请求的CouchDB实例本地数据库和远程数据库之间复制，可以使用以下请求：
```
POST http://couchdb:5984/_replicate HTTP/1.1 
Content-Type: application/json
Accept: application/json
{
    "source" : "recipes",
    "target" : "http://coucdb-remote:5984/recipes",
}
```
在所有情况下，源规范和目标规范中所请求的数据库都必须存在。 如果不这样做，则将在JSON对象内返回错误：
```
{
    "reason" : "could not open http://couchdb-remote:5984/ol1ka/",
}
```
您可以通过将`create_target`字段添加到请求对象来创建目标数据库（只要您的用户凭据允许）：
```
POST http://couchdb:5984/_replicate HTTP/1.1 
Content-Type: application/json
Accept: application/json
{
    "create_target" : true
    "source" : "recipes",
    "target" : "http://couchdb-remote:5984/recipes",
}
```
`create_target`字段不是破坏性的。 如果数据库已经存在，则复制将正常进行。

#### 2.8.3 单个复制

您可以请求复制数据库，以便可以同步两个数据库。 默认情况下，复制过程会发生一次，并将两个数据库同步在一起。 例如，您可以通过在请求JSON内容中提供`source`和`target`字段来请求两个数据库之间的单个同步。
```
POST http://couchdb:5984/_replicate HTTP/1.1 
Accept: application/json
Content-Type: application/json
{
    "source" : "recipes",
    "target" : "recipes-snapshot",
}
```
在上面的示例中，数据库配方和配方快照将被同步。 这些数据库是发出请求的CouchDB实例的本地数据库。响应将是一个JSON结构，其中包含同步过程的成功（或失败），以及有关该过程的统计信息：
```
{
    "ok" : true,
    "history" : [
        {
            "docs_read" : 1000,
            "session_id" : "52c2370f5027043d286daca4de247db0",
            "recorded_seq" : 1000,
            "end_last_seq" : 1000,
            "doc_write_failures" : 0,
            "start_time" : "Thu, 28 Oct 2010 10:24:13 GMT",
            "start_last_seq" : 0,
            "end_time" : "Thu, 28 Oct 2010 10:24:14 GMT",
            "missing_checked" : 0,
            "docs_written" : 1000,
            "missing_found" : 1000
        }
    ],
    "session_id" : "52c2370f5027043d286daca4de247db0",
    "source_last_seq" : 1000
}
```

#### 2.8.4 继续复制

在执行复制请求时，数据库与以前提到的方法的同步仅发生一次。 要使目标数据库从源永久复制，您必须将请求内JSON对象的Continuous字段设置为true。
通过连续复制，源数据库中的更改将永久复制到目标数据库，直到您明确要求停止复制为止。
```
POST http://couchdb:5984/_replicate HTTP/1.1 
Accept: application/json
Content-Type: application/json
{
    "continuous" : true
    "source" : "recipes",
    "target" : "http://couchdb-remote:5984/recipes",
}
```
只要两个实例之间存在网络连接，更改就会在两个数据库之间复制。
两个保持彼此同步的数据库，您需要在两个方向上设置复制；也就是说，您必须从源复制到目标，并且必须从目标复制到另一个。

#### 2.8.5 取消继续复制

您可以通过将`cancel`字段添加到JSON请求对象并将值设置为`true`来取消连续复制。请注意，请求的结构必须与原始结构相同，才能兑现取消请求。例如，如果您请求连续复制，则取消请求还必须包含连续字段。
例如，复制请求：
```
POST http://couchdb:5984/_replicate HTTP/1.1 
Content-Type: application/json
Accept: application/json
{
    "source" : "recipes",
    "target" : "http://couchdb-remote:5984/recipes", "create_target" : true,
    "continuous" : true
}
```
必须使用请求取消复制：
```
POST http://couchdb:5984/_replicate HTTP/1.1 
Accept: application/json
Content-Type: application/json
{
    "cancel" : true,
    "continuous" : true
    "create_target" : true,
    "source" : "recipes",
    "target" : "http://couchdb-remote:5984/recipes",
}
```
请求取消不存在的复制将导致404错误。

### 2.9 `/_scheduler/jobs`

`GET /_scheduler/jobs`:列出复制任务
**请求头：**
&emsp;&emsp;&emsp;&emsp;    * `Accept-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
**响应头：**
&emsp;&emsp;&emsp;&emsp;    * `Content-Type-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
**请求参数**
&emsp;&emsp;&emsp;&emsp;    * `limit(number)：`返回多少数量的结果
&emsp;&emsp;&emsp;&emsp;    * `skip(number):`跳过多少数量的结果，以复制ID排序
**响应JSON对象**
&emsp;&emsp;&emsp;&emsp;    * `offset (number)：`多少数量的结果被跳过
&emsp;&emsp;&emsp;&emsp;    * `total_rows (number) ：`复制任务的总数量
&emsp;&emsp;&emsp;&emsp;    * `id (string)：`复制ID
&emsp;&emsp;&emsp;&emsp;    * `database (string)：`复制文档数据库
&emsp;&emsp;&emsp;&emsp;    * `doc_id (string)：`复制文档ID
&emsp;&emsp;&emsp;&emsp;    * `history (list)：`事件的时间戳历史以对象列表展示
&emsp;&emsp;&emsp;&emsp;    * `pid (string)：`复制进程ID
&emsp;&emsp;&emsp;&emsp;    * `node (string)：`运行任务的集群中的节点
&emsp;&emsp;&emsp;&emsp;    * `source (string)：`复制源头
&emsp;&emsp;&emsp;&emsp;    * `target (string)：`复制目标
&emsp;&emsp;&emsp;&emsp;    * `start_time (string)：`开始复制的时间戳
**状态码：**
&emsp;&emsp;&emsp;&emsp;    * 200 `OK`
&emsp;&emsp;&emsp;&emsp;    * 401 `Unauthorized`

### 2.10 `/_scheduler/docs`

`GET /_scheduler/docs`:列出复制文档的状态
**请求头：**
&emsp;&emsp;&emsp;&emsp;    * `Accept-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
**响应头：**
&emsp;&emsp;&emsp;&emsp;    * `Content-Type-`
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;        * `application/json`
**请求参数：**
&emsp;&emsp;&emsp;&emsp;    * `limit(number):`返回多少结果
&emsp;&emsp;&emsp;&emsp;    * `skip(number):`跳过多少数量的结果，以文档ID排序
**响应JSON对象**
&emsp;&emsp;&emsp;&emsp;    * `offset (number)：`多少数量的结果被跳过
&emsp;&emsp;&emsp;&emsp;    * `total_rows (number) ：`复制文档的总数量
&emsp;&emsp;&emsp;&emsp;    * `id (string)：`复制ID或者当复制状态为完成或失败时为空
&emsp;&emsp;&emsp;&emsp;    * `state(string)：`复制状态(`initializing,running,completed,pending,crashing,error,failed`)
&emsp;&emsp;&emsp;&emsp;    * `database (string)：`复制文档的目标数据库
&emsp;&emsp;&emsp;&emsp;    * `doc_id (string)：`复制文档ID
&emsp;&emsp;&emsp;&emsp;    * `last_update(string)：`最后一次更新的时间
&emsp;&emsp;&emsp;&emsp;    * `info(object)：`关于状态的可能的额外信息
&emsp;&emsp;&emsp;&emsp;    * `node (string)：`运行任务的集群中的节点
&emsp;&emsp;&emsp;&emsp;    * `source (string)：`复制源头
&emsp;&emsp;&emsp;&emsp;    * `target (string)：`复制目标
&emsp;&emsp;&emsp;&emsp;    * `start_time (string)：`开始复制的时间戳
&emsp;&emsp;&emsp;&emsp;    * `error_count(number) ：`复制出现错误的数量
**状态码：**
&emsp;&emsp;&emsp;&emsp;    * 200 `OK`
&emsp;&emsp;&emsp;&emsp;    * 401 `Unauthorized`
**JSON对象**
&emsp;&emsp;&emsp;&emsp;    * `revisions_checked (number):`在复制开始时被检查的修订版本的数量
&emsp;&emsp;&emsp;&emsp;    * `missing_revisions_found(number):`在源处有而目标处没有的修订版本的数量
&emsp;&emsp;&emsp;&emsp;    * `docs_read (number) :`从源处读取的文档的数量
&emsp;&emsp;&emsp;&emsp;    * `docs_written (number) :`写到目标的文档的数量
&emsp;&emsp;&emsp;&emsp;    * `changes_pending (number):`还没有复制完成的数量
&emsp;&emsp;&emsp;&emsp;    * `doc_write_failures (number) :`写目标失败的数量
&emsp;&emsp;&emsp;&emsp;    * `checkpointed_source_seq (object):`最后一个从源处成功复制的序列ID

### 2.11 `/_node/{node-name}/_stats`


### 2.12 `/_node/{node-name}/_system`


### 2.13 `/_node/{node-name}/_restart`


### 2.14 `/_utils`


### 2.15 `/_up`



### 2.16 `/_uuids`



### 2.17 `/favicon.ico`


### 2.18 权限认证

### 2.19 配置
