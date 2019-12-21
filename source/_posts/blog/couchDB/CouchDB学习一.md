---
title: CouchDB学习一
date: 2019-11-24 15:24:56
tags: CouchDb
categories: CouchDb学习
---
## 端口

|端口号|协议|作用|
|---|---|---|
|5984|tcp|标椎集群端口用于所有的HTTP API请求|
|5986|tcp|用于管理员对节点与分片的管理|
|4369|tcp|Erlang端口到daemon的映射|

### 配置介绍
#### 配置文件
CouchDb从以下位置按顺序读取配置文件
* etc/fefault.ini
* etc/default.d/*.ini
* etc/local.ini
* etc/local.d/*.ini

类UNIX系统：`/opt/couchdb/`
Windows系统:`C:\CouchDB`
maxOS:`Applications/Apache CouchDB.app/Contents/Resources/couchdbx-core/etc`下的`default.ini`和`default.d`文件夹。`/Users/youruser/Library/Application Support/CouchDB2/etc/couchdb`下的`default.ini`和`default.d`文件夹.

#### 通过HTTP API修改参数
**集群**：
```
curl -X PUT http://localhost:5984/_node/name@host/_config/uuids/algorithm -d '"random"'
```
**单节点**
```
curl -X PUT http://localhost:5984/_node/_local/_config/uuids/algorithm -d '"random"'
```
### 基本配置
#### couchdb配置
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

### cluster 配置
#### 集群选项
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/cluster/`后接参数.
* q
    新创建的数据库的分片数量，默认为8
* n
    集群中每一个数据库文档的副本数。单节点为1，每个节点最多仅持有一个副本。
* placement
* seedlist
    以逗号分隔的节点名称列表，当前节点应与之通信加入集群。

### couch_peruser
#### couch_peruser配置
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/couch_peruser/`后接参数.
* enable
    如果设置为true，则_users为私有的数据库。且只允许当前节点操作。
* delete_dbs
    如果设置为true，当用户被删除，则相关的数据库也一同删除。
### CouchDB HTTP 服务器
#### HTTP Server配置
**[chttpd]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/chttpd/`后接参数.

* bind_address :集群端口绑定的IP地址
    * 127.0.0.1
    * 0.0.0.0：任何IP地址
    * ::1:IPV6
    * :: 任何IPV6的地址
* port:集群端口号
    * 5984:默认
    * 0：可使用任何端口号
* prefer_minimal:如果一个请求含有请求头:Prefer,则只返回`prefer_minimal`配置列表的头部信息
* authentication_handlers:CouchDB使用的认证头部信息。可以使用第三方插件进行扩展。
    * {chttpd_auth, cookie_authentication_handler}: Cookie认证;
    * {couch_httpd_auth, proxy_authentication_handler}:代理认证;
    * {chttpd_auth, default_authentication_handler}: 基本认证：
    * {couch_httpd_auth, null_authentication_handler}:取消认证

**[httpd]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/httpd/`后接参数.
在CouchDB2.X版本，这一部分默认使用5986为默认端口。用于管理员任务与系统维护。应该总是绑定私有的LAN 127.0.0.1地址。

* allow_jsonp
    * 是否支持JSONP，默认false    
* bind_address
    * 本地节点可获得的IP地址。建议总是使用127.0.0.1或IPV6 ::1
* changes_timeout
    * 默认超时时间默认为6000ms
* config_whitelist
    * 配置信息修改白名单。只有白名单内的值可以通过CONFIG API修改配置。为了允许管理员通过HTTP修改该值，需要包括{httpd,config——whitelist}自己。
    * config_whitelist = [{httpd,config_whitelist}, {log,level}, {etc,etc}]
* default_handler
    * 具体的默认HTTP请求Handler
    * default_handler = {couch_httpd_db, handle_request}
* enable_cors
    * 控制CORS特性,默认false
* port
    * 定义监听的端口号 默认5986
* redirect_vhost_handler
    * Handler请求到`virtual hosts`的定制的默认功能
    * redirect_vhost_handler = {Module, Fun}
* server_options
    * 可以被添加到配置文件的`MochiWeb`组件的服务器选项。
    * server_options = [{backlog, 128}, {acceptor_pool_size, 16}]
* secure_rewrites
    * 是否允许通过子域隔离数据库。
* socket_options
    * CouchDB监听Socket选项。可以定义为元组列表.
    * socket_options = [{sndbuf, 262144}, {nodelay, true}]
* server_options
    * CouchDB中mochiweb acceptor池中任何socket服务器选项，可以定义为元组列表.
    * server_options = [{recbuf, undefined}]
* vhost_global_handlers
    * 对于`virtual hosts`全局的Handlers列表
    * vhost_global_handlers = _utils, _uuids, _session, _users

* x_forwarded_host
    * 用于转发`HOST`头部字段的原始值。例如一个转发代理在请求Couchd前重写`Host`头部信息到内部主机。
    * x_forwarded_host = X-Forwarded-Host
* x_forwarded_proto
    * 认证原始的HTTP协议
* x_forwarded_ssl
    * 用于告诉CouchDB使用https代替http
* enable_xframe_options
    * 控制是否开启特性
* WWW-Authenticate
    * 设置在基本认证下不具备权限的请求头部信息
* max_http_request_size
    * 限制HTTP请求体最大值大小默认4GB

#### HTTPS (SSL/TLS)选项
CouchDb支持本地TLS/SSL，不需要使用代理服务器.HTTPS设置比较容器，只需要两个文件：一个证书个一个私钥。可以通过`OpenSSL`命令生成自签名证书。
```
shell> mkdir /etc/couchdb/cert
shell> cd /etc/couchdb/cert
shell> openssl genrsa > privkey.pem
shell> openssl req -new -x509 -key privkey.pem -out couchdb.pem -days 1095
shell> chmod 600 privkey.pem couchdb.pem
shell> chown couchdb privkey.pem couchdb.pem
```
编辑CouchDB配置文件`local.ini`：
```
enable = true
cert_file = /etc/couchdb/cert/couchdb.pem
key_file = /etc/couchdb/cert/privkey.pem
```
使用自签名证书可以通过参数`-k`忽略警告信息
```
curl -k https://127.0.0.1:6984
```
**[ssl]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/ssl/`后接参数.

* cacert_file
    * 包含PEM编码的CA证书路径,CA证书用于构建服务器证书链。用于客户端权限认证。
* cert_file
    * 包含用户证书文件的路径
* key_file
    * 包含用户PEM编码的私钥文件路径
* password
    * 包含用户密码的字符串,当用户私钥通过密码保护时使用
* ssl_certifacate_max_depth
    * 最大的节点证书深度
* verify_fun
    * 如果不指定具体的验证功能，则使用默认的验证功能
* verify_ssl_certificates
    * 如果为true则验证节点证书
* fail_if_no_peer_cert
    * true：如果客户端没有发送证书，则终止TLS/SSL握手
    * false：只当客户端发送无效证书时，终止TLS/SSL握手
* secure_renegotiate
* ciphers
    * 设置erlang格式的被支持的加密套件
    * ciphers = ["ECDHE-ECDSA-AES128-SHA256", "ECDHE-ECDSA-AES128-SHA"]
* tls_versions
    * 设置允许的SSL/TLS协议版本列表
    * tls_versions = [tlsv1 | 'tlsv1.1' | 'tlsv1.2']

#### 跨域资源分享
跨域资源分享.比如浏览器中运行js的网页通过AJAX请求到不同的域。不需要破坏任何一方的安全。
一个典型的用例是通过静态网页通过CDN请求另一资源。比如CouchDB实例。这避免了使用JSONP或类似的变通方法来检索和托管内容的中间代理。
CouchDB实例可以接受直接的连接保护数据库和实例。不会造成浏览器功能由于相同的域的限制被阻塞。CORS支持当前90%的浏览器。
**[cors]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/httpd/`后接参数.
* enable_cors
需要将`httpd/enable_cors`选项设置为`true`。
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/cors/`后接参数.

* credentials
    * 默认情况下，请求和响应中均不包含身份验证标头或cookie。
* origins
    * 通过，分隔接受的原始的URL列表。不能同时设置origins=*和credentials=true

* headers
    * 通过，分隔的可接受的请求头列表。
* methods
    * 可接受的请求方法
* max_age
    * Access-Control-Max-Age

#### 虚拟主机
虚拟主机
CouchDB可以基于`Host`请求头映射请求到绑定同一个IP地址的不同的位置。
允许同一机器上不同虚拟机映射到不同的数据库或者是设计文档。
通过为域名添加一个`CNAME`指针到DNS。在测试或者开发环境下，添加一个实体到hosts文件,如类UNIX系统：
```
127.0.0.1       couchdb.local
```
最后添加一个实体到配置文件的`[vhosts]`部分：
```
couchdb.local:5984 = /example
*.couchdb.local:5984 = /example
```
如果CouchDB监听在默认的HTTP端口80，或者之前设置了代理，则不需要在`vhosts`中指定端口号.
第一行将重写请求以显示示例数据库的内容。 仅当Host标头为couchdb.local且不适用于CNAME时，此规则才有效，另一方面，第二条规则将所有CNAME与示例db匹配，这样www.couchdb.local和db.couchdb.local都可以使用。
**[vhosts]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/vhosts/`后接参数.
* couchdb.local
### 认证与权限
#### 服务器管理员
默认的CouchDB提供了管理员级别的可以访问所有连接的用户。配置在`Admin Party`部分。不应该在生产环境中使用。可以在创建第一个管理员账户后删除这一部分。CouchDB服务管理员和密码没有存储在`_users`数据库。但是CouchDB加载ini文件时可以在最后发现`admin`部分。这个文件(可能为`etc/local.ini`或者`etc/local.d/10-admins.ini`在Debian/Ubuntu系统从包中安装时发现。)应该安全并且只能由系统管理员可读.
管理员可以直接添加到`admin`部分，当CouchDB重新启动时，密码将会自动加密。也可以通过HTTP接口创建管理员账户不需要重启CouchDB。HTTP`/_node/{node-name}/_config/admins`地址支持查询，删除或者是创建新管理员账户。
**[admins]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/admins/`后接参数.
#### 认证配置
**[chttpd]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/chttpd/`后接参数.

* require_valid_user
    * true:不允许来自匿名用户的任何请求

**[couch_httpd_auth]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/couch_httpd_auth/`后接参数.

* allow_persistent_cookies
    * 使得Cookie持久性。
* cookie_domain
    * 配置`AuthSession`Cookie的域属性。默认为空。
    * cookie_domain=example.com
* auth_cache_size
    * 内容中用户对象缓存数量，减少硬盘读写，默认50
* authentication_redirect
    * 权限成功验证后，客户端接受`text/html`响应情况下具体的重定向的位置。
    * authentication_redirect = /_utils/session.html


* iterations
    * 由PBKDF2算法哈希的密码迭代的数量。
* min_iterations
    * 最小迭代的数量
* max_iterations
    * 最大迭代的数量
* proxy_use_secret
    * true:`couch_httpd_auth/secret`选项要求代理身份认证
* public_fields
    * 用户文档中可以被任何用户读的由逗号分隔的字段名称。
    * public_fields = first_name, last_name, contacts, url
* require_valid_user
    * true:不允许来自匿名用户的任何请求
* secret
    * 用于代理身份认证与Cookie身份认证的secret
* timeout
    * 最后一次请求之后session超时过期时间默认600
* users_db_public
    * 允许用户查看所有用户文档，默认情况下，只有管理员可以查看所有用户的文档,用户只能查看自己的文档。
* x_auth_roles
    * HTTP请求头包含用户的角色，用逗号分隔。用于代理身份认证
* x_auth_token
    * HTTP请求头包含用户的token，用逗号分隔。用于代理身份认证
* x_auth_username
    * HTTP请求头包含用户的用户名，用逗号分隔。用于代理身份认证

### 压缩配置
#### 数据库压缩配置
**[database_compaction]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/database_compaction/`后接参数.

* doc_buffer_size
    * 具体的拷贝缓冲区大小
* checkpoint_after
    * 在具体数量的比特后激活检查点拷贝到压缩数据库。

#### 压缩程序规则
**[compactions]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/compactions/`后接参数.
列表中的规则确定什么时候运行自动压缩。配置可以是指定数据库或者是全局的。格式如下:
```
database_name = [ {ParamName, ParamValue}, {ParamName, ParamValue}, ... ]
_default = [ {ParamName, ParamValue}, {ParamName, ParamValue}, ... ]
_default = [{db_fragmentation, "70%"}, {view_fragmentation, "60%"}, {from,"23:00"}, {to, "04:00"}]
```

1. db_fragmentation:数据库中数据压缩率，包括元数据。计算方法：(file_size-data_size)/file_size*100
2. view_fragmentation：数据库中索引文件.....
3. form,to:允许进行压缩的时间段,格式：`HH:MM - HH:MM  (HH in [0..23], MM in [0..59])`
4. strict_window:如果为true，并且在超时时间后还没有压缩完则终止压缩。
5. parallel_view_compaction：是否数据和视图同时进行压缩。

#### 压缩程序配置
**[compaction_daemon]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/compaction_daemon/`后接参数.

* check_interval
    * 两次检查数据库和视图索引是否需要被压缩的时间间隔，默认为3600
* min_file_size
    * 如果数据库或者视图索引文件大小小于该值，则不进行压缩。
* snooze_period_ms

#### 视图压缩选项
**[view_compaction]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/view_compaction/`后接参数.

* keyvalue_buffer_size
    * 压缩时具体的最大拷贝缓冲区大小.

### 日志
#### 日志选项
**[log]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/log/`后接参数.

* writer
    * stderr：日志信息发送到stderr(默认)
    * file:日志信息存储到文件
    * syslog：日志信息发送到syslog daemon
* file
    * 日志保存到文件的具体的位置(默认`/var/log/couchdb/couch.log`)
* write_buffer
    * 写日志缓冲区大小默认0
* write_delay
    * 写日志到硬盘延迟默认为0
* level
    * 日志级别
    * debug
    * info：包括HTTP请求，启动外部程序
    * notice
    * warning,warn：警告信息，例如硬盘空间不足
    * error,err：只输出错误信息
    * critical crit
    * alert
    * emergency emerg
    * none:不输入任何日志
* include_sasl
    * 是否在日志中包含SASL信息
* syslog_host
    * 具体的syslog 主机将日志发送到的位置默认localhost
* syslog_port
    * 当发送日志信息时连接的syslog端口
* syslog_appid
    * 具体的应用名称默认couchdb
* syslog_facility

### 复制者
#### 数据库复制配置
**[replicator]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/replicator/`后接参数.

* max_jobs
    * 活跃的运行的复制任务数量。
* interval
* max_churn
* update_docs
* worker_batch_size
* worker_processes
* http_connections
* connection_timeout
* retries_per_request
* socket_options
* checkpoint_interval
* use_checkpoints
* cert_file
* key_file
* password
* verify_ssl_certificates
* ssl_trusted_certificates_file
* ssl_certificate_max_depth
* auth_plugins

### Query Servers
#### Query Servers Definition
**[query_servers]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/query_servers/`后接参数.
#### Query Servers Configuration
**[query_sercver_config]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/query_sercver_config/`后接参数.

* commit_freq
* os_process_limit
* os_process_soft_limit
* reduce_limit

#### Native Erlang Query Server
**[native_query_servers]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/native_query_servers/`后接参数.

### CouchDB Internal Services
#### CouchDB Daemonized Mini Apps
**[daemons]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/daemons/`后接参数.

* auth_cache
* compaction_daemon
* external_manager
* httpd
* index_server
* query_servers
* replicator_manager
* stats_aggregator
* stats_collector
* uuids
* vhosts

### Miscellaneous Parameters
#### Configuration of Attachment Storage
**[attachments]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/attachments/`后接参数.

* compression_level
* compressible_types

#### Statistic Calculation
**[stats]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/stats/`后接参数.

* rate
* samples

#### UUIDs Configuration
**[uuids]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/uuids/`后接参数.

* algorithm
* utc_id_suffix
* max_count

#### Vendor information
**[vendor]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/vendor/`后接参数.

#### Content-Security_Policy
**[csp]**
`curl`地址：`http://localhost:5984/_node/<name@host>/_config/csp/`后接参数.

* enable
* header_value

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
#创建一个数据库名字为db_name 
curl -u admin:adminpw -X PUT http://localhost:5984/db_name?q=4&n=2
```
#### 删除数据库
```
curl -u admin:adminpw -X DELETE http://localhost:5984/db_name
```