---
title: CouchDB学习-维护
date: 2019-12-22 12:26:41
tags: CouchDb
categories: CouchDb学习
---
[官方文档](https://docs.couchdb.org/en/stable/maintenance/index.html)
# 1 压缩
* * *
压缩操作是通过从数据库或者视图索引文件中移除无用的和老的数据减少硬盘使用空间.操作非常简单类似于其他数据库(SQLite等)管理系统。
在压缩目标期间，CouchDB将创建扩展名为.compact的新文件，并将仅实际数据传输到该文件中。 因此，CouchDB首先检查可用磁盘空间-它应比压缩文件的数据大两倍。
当所有实际数据都成功传输到压缩文件后，CouchDB用目标文件替换目标文件。
## 1.1 数据库压缩
数据库压缩通过删除更新期间创建的未使用的文件部分来压缩数据库文件。 旧文档修订版被少量称为`tombstone`的元数据代替，该元数据用于复制期间的冲突解决。 可以使用`_revs_limit`URL配置存储的修订版本（以及`tombstone`）的数量。
压缩是每个数据库手动触发的操作，并作为后台任务运行。要针对特定的数据库启动它，需要发送目标数据库的HTTP POST`/{db}/_compact`子资源：
```
curl -H "Content-Type: application/json" -X POST http://localhost:5984/my_db/_compact
```
成功的话，将立即返回HTTP 状态码`202 Accepted`。
```
HTTP/1.1 202 Accepted
Cache-Control: must-revalidate Content-Length: 12
Content-Type: text/plain; charset=utf-8 Date: Wed, 19 Jun 2013 09:43:52 GMT Server: CouchDB (Erlang/OTP)
```
```
{"ok":true}
```
尽管未使用请求主体，但仍必须为请求指定带有`application/json`值的`Content-Type`标头。否则，您会知道HTTP状态`415不支持的媒体类型响应`：
```
HTTP/1.1 415 Unsupported Media Type
Cache-Control: must-revalidate 
Content-Length: 78
Content-Type: application/json 
Date: Wed, 19 Jun 2013 09:43:44 GMT 
Server: CouchDB (Erlang/OTP)
{"error":"bad_content_type","reason":"Content-Type must be application/json"}
```
当压缩成功启动并运行时，可以通过数据库信息资源获取有关压缩的信息：
```
curl http://localhost:5984/my_db
```
```
HTTP/1.1 200 OK
Cache-Control: must-revalidate 
Content-Length: 246
Content-Type: application/json 
Date: Wed, 19 Jun 2013 16:51:20 GMT 
Server: CouchDB (Erlang/OTP)
{
    "committed_update_seq": 76215, 
    "compact_running": true, 
    "data_size": 3787996, 
    "db_name": "my_db", 
    "disk_format_version": 6, 
    "disk_size": 17703025, 
    "doc_count": 5091, 
    "doc_del_count": 0, 
    "instance_start_time": "0", 
    "purge_seq": 0,
    "update_seq": 76215
}
```
请注意，`compaction_running`字段为`true`，指示压缩实际上正在运行。 要跟踪压缩进度，可以查询`_active_tasks`资源：
```
curl http://localhost:5984/_active_tasks
```
```
HTTP/1.1 200 OK
Cache-Control: must-revalidate
Content-Length: 175
Content-Type: application/json 
Date: Wed, 19 Jun 2013 16:27:23 GMT 
Server: CouchDB (Erlang/OTP)
[
    {
        "changes_done": 44461, 
        "database": "my_db",
        "pid": "<0.218.0>", 
        "progress": 58,
        "started_on": 1371659228, 
        "total_changes": 76215, 
        "type": "database_compaction", 
        "updated_on": 1371659241
    }
]
```
## 1.2 视图压缩
与数据库视图不同，视图也需要像数据库一样进行压缩，这与按每个设计文档按组对数据库视图进行压缩不同。要启动其压缩，需要发送HTTP POST`/{db}/_compact/{ddoc}`请求：
```
curl -H "Content-Type: application/json" -X POST http://localhost:5984/dbname/_compact/designname
```
```
{"ok":true}
```
这将从指定设计文档的当前版本压缩视图索引。 HTTP响应代码`202 Accepted`(类似于数据库的压缩)，并且将创建压缩后台任务。
### 1.2.1视图清理
磁盘上的视图索引以视图定义的MD5哈希命名。更改视图时，旧索引仍保留在磁盘上。要清除所有过时的视图索引（以视图的MD5表示形式命名的文件，该文件不再存在），可以触发视图清除：
```
curl -H "Content-Type: application/json" -X POST http://localhost:5984/dbname/_view_cleanup
```
```
{"ok":true}
```
## 1.3 自动压缩
虽然需要手动触发数据库和视图的压缩，但也可以配置自动压缩，以便基于各种条件自动触发数据库和视图的压缩。 在CouchDB的配置文件中配置了自动压缩。
守护程序`/compaction_daemon`负责触发压缩。 默认情况下启用它并自动启动。在压缩部分中配置了触发压缩的条件。
# 2 性能
* * *
无论您如何编写代码，即使有了成千上万的文档，通常都会发现CouchDB可以很好地执行。但是一旦开始阅读数百万个文档，您需要更加小心。
## 2.1 硬盘IO
### 2.1.1 文件大小
文件大小越小，I/O操作将越少，CouchDB和操作系统可以缓存的文件越多，复制，备份等的速度就越快。因此，您应该仔细检查所要存储的数据储存。例如，使用长度为数百个字符的键会很愚蠢，但是如果仅使用单个字符键，则程序将很难维护。通过将其放在视图中来仔细考虑重复的数据。
### 2.1.2 硬盘和文件系统性能
使用更快的磁盘，条带化RAID阵列和现代文件系统都可以加快CouchDB部署。但是，当磁盘性能成为瓶颈时，有一种方法可以提高CouchDB服务器的响应速度。 从文件模块的Erlang文档中：
在具有线程支持的操作系统上，可以让文件操作在其自己的线程中执行，从而允许其他Erlang进程继续与文件操作并行执行。 请参阅erl(1)中的命令行标志+A。
将此参数设置为大于零的数字可以使您的CouchDB安装保持响应状态，即使在磁盘使用率很高的时期也是如此。设置此选项的最简单方法是通过`ERL_FLAGS`环境变量。例如，要为Erlang提供执行I/O操作的四个线程，请将以下内容添加到`(prefix)/etc/defaults/couchdb`（或等效项）中：
```
export ERL_FLAGS="+A 4"
```
## 2.2 系统资源限制
管理员在其部署变大时会遇到的问题之一是系统和应用程序配置施加的资源限制。 提高这些限制可以使您的部署超出默认配置所支持的范围。
### 2.2.1 CouchDB配置选项
#### `delayed_commits`
延迟的提交允许在某些工作负载下实现更好的写入性能，同时牺牲少量的持久性。 该设置使CouchDB在更新后提交新数据之前要等待一整秒。如果服务器在写入标头之前崩溃，则自上次提交以来的所有写入都将丢失。 启用此选项需要您自担风险。
#### `max_dbs_open`
在配置(`local.ini`或类似版本)中,或者地址`couchdb/max_dbs_open`：
```
[couchdb]
max_dbs_open = 100
```
此选项将一次可以打开的数据库数量设置为上限。CouchDB引用对内部数据库访问进行计数，并在必要时关闭空闲数据库。有时有必要一次保持超过默认值的速度，例如在许多数据库将被连续复制的部署中。
#### `Erlang`
即使增加了CouchDB允许的最大连接数，默认情况下，Erlang运行时系统也将不允许超过1024个连接。 将以下指令添加到`(prefix)/etc/default/couchdb`(或等效文件)将增加此限制(在这种情况下，增加到4096)：
```
export ERL_MAX_PORTS=4096
```
高达1.1.x的CouchDB版本还会为每个复制创建`Erlang Term Storage`(ETS)表。如果您使用的CouchDB版本早于1.2，并且必须支持许多复制，则还应设置`ERL_MAX_ETS_TABLES`变量。 默认值是大约1400表。
请注意，在Mac OS X上，Erlang实际上不会将文件描述符限制增加到超过1024（即系统标头定义的FD_SETSIZE值）。 
#### 打开文件描述的最大数量(无限制)
大多数`*nix`操作系统在每个进程上都有各种资源限制。增加这些限制的方法因初始化系统和特定的OS版本而异。许多操作系统的默认值为1024或4096。在具有许多数据库或视图的系统上，CouchDB可以非常迅速地达到此限制。
如果您的系统设置为使用可插拔身份验证模块(`PAM`)系统（几乎所有现代Linux都是这种情况），则增加此限制很简单。例如，创建具有以下内容的名为`/etc/security/limits.d/100-couchdb.conf`的文件将确保CouchDB可以一次打开多达10000个文件描述符：
```
#<domain>  <type>    <item>  <value>
couchdb    hard      nofile  10000 
couchdb    soft      nofile  10000
```
如果使用的是Debian/Ubuntu sysvinit脚本(`/etc/init.d/couchdb`，则还需要提高root用户的限制：
```
#<domain>    <type>   <item>  <value>
root         hard    nofile   10000
root         soft    nofile   10000
```
您可能还需要编辑`/etc/pam.d/common-session`和`/etc/pam.d/common-session-noninteractive`文件以添加以下行：
```
session required pam_limits.so
```
如果还不存在。
对于基于系统的Linux（例如CentOS/RHEL 7，Ubuntu 16.04 +，Debian 8或更高版本）,假设您要从systemd启动CouchDB，则还必须通过创建文件`/etc/systemd/system/<servicename>.d/override.conf`添加以下内容：
```
[Service]
LimitNOFILE=#######
```
并将`#######`替换为文件描述符的上限CouchDB允许立即保持打开状态。
如果您的系统不使用`PAM`，通常可以在自定义脚本中使用`ulimit`命令来启动
CouchDB具有增加的资源限制。 典型的语法类似于`ulimit -n 10000`。
通常，类似UNIX的现代系统每个进程可以处理大量文件句柄（例如100000）
没有问题。 不要害怕增加系统限制。
## 2.3 网络
产生和接收每个请求/响应都有延迟开销。通常，您应该分批执行请求。大多数API具有某种批处理机制，通常是通过在请求正文中提供文档或键的列表来进行的。请注意为批次选择的大小。较大的批处理需要更多的时间来使客户将项目编码为  `JSON`，并将更多的时间用于解码该数量的响应。使用您自己的配置和典型数据进行一些基准测试，以找到最佳位置。 它可能在一到一万个文档之间。
如果您拥有快速的I/O系统，那么您也可以使用并发-同时具有多个请求/响应。这减轻了组装JSON，进行网络连接和解码`JSON`所涉及的延迟。
从CouchDB 1.1.0开始，与旧版本相比，用户经常报告文档的写入性能较低。主要原因是此版本随附HTTP服务器库`MochiWeb`的最新版本，该库默认情况下将`TCP`套接字选项`SO_NODELAY`设置为`false`。这意味着发送到TCP套接字的小数据（例如对文档写请求的答复（或读取非常小的文档）的答复）不会立即发送到网络`TCP`将对其缓冲一会儿，希望它会被询问通过同一套接字发送更多数据，然后一次发送所有数据以提高性能。 可以通过`httpd/socket_options`禁用此`TCP`缓冲行为：
```
[httpd]
socket_options = [{nodelay, true}]
```
### 2.3.1 连接限制
`MochiWeb`处理`CouchDB`请求。默认最大连接数为2048。要更改此限制，请使用`server_options`配置变量。 `max`表示最大连接数。
```
[chttpd]
server_options = [{backlog, 128}, {acceptor_pool_size, 16}, {max, 4096}]
```
## 2.4 CouchDB
### 2.4.1 删除操作
当您删除文档时，数据库将创建一个新的修订版，其中包含`_id`和`_rev`字段以及`_deleted`标志。即使在数据库压缩后，此修订版仍将保留，以便可以复制删除内容。像未删除的文档一样，已删除的文档可能会影响视图生成时间，`PUT`和`DELETE`请求时间以及数据库的大小，因为它们会增加`B+Tree`的大小。您可以在数据库信息中看到已删除文档的数量。如果您的用例创建了许多已删除的文档（例如，如果您存储日志条目，消息队列等短期数据），则可能需要定期切换到新数据库并删除已过期的旧数据库）。
### 2.4.2 文档ID
数据库文件的大小源自您的文档和视图大小，但也取决于您的`_id`大小的倍数。`_id`不仅存在于文档中，而且它及其部分内容在`CouchDB`用来导航文件以首先找到文档的二叉树结构中也是重复的。作为一个现实世界的例子，一个用户从16个字节的ID切换到4个字节的ID，使数据库从21GB变为4GB，包含1000万个文档（从2.5GB到2GB的原始JSON文本）。
插入具有顺序（至少已排序）的ID的速度要比随机ID快。 因此，您应该考虑自己生成id，按顺序分配它们，并使用消耗更少字节的编码方案。例如，可以用4个基数62个数字（用10个数字，26个小写字母，26个大写字母）来完成需要16个十六进制数字表示的内容。
## 2.5 视图
### 2.5.1 视图生成
当要处理的文档数量非常少时，使用JavaScript查询服务器生成的视图非常慢。生成过程甚至不会使单个CPU饱和，更不用说您的I/O了。原因是CouchDB服务器和单独的`couchjs`查询服务器中涉及的延迟，这显着表明了从实施中消除延迟的重要性。
您可以让视图访问权限“过时”，但要确定何时发生会给您带来快速响应以及何时更新视图会花费很长时间，这是不切实际的。(一个拥有1000万个文档的数据库大约需要10分钟才能加载到CouchDB中，而生成视图需要大约4个小时)。
在集群中，“陈旧的”请求由一组固定的分片服务，以便为用户提供请求之间的一致结果。这需要进行可用性权衡-固定的分片集可能不是集群中响应最快的/可用的。如果不需要这种一致性(例如，索引相对静态)，则可以通过指定`stable = false＆update = false`代替`stale = ok`或`stable = false＆update = lazy`代替`stale = update_after`。
视图信息不会被复制-它会在每个数据库上重建，因此您无法在单独的服务器上生成视图。
### 2.5.2 内置缩小功能
如果您使用的是非常简单的视图函数，仅执行求和或计数减少，则可以通过简单地编写`_sum`或`_count`代替函数声明来调用它们的本机`Erlang`实现。 这将大大加快速度，因为它减少了CouchDB和JavaScript查询服务器之间的IO。 例如，如邮件列表中所述，用于输出（已索引和缓存的）视图的时间大约为78,000个项目，时间从60秒减少到4秒。
之前：
```
{
    "_id": "_design/foo",
    "views": {
        "bar": {
            "map": "function (doc) { emit(doc.author, 1); }",
            "reduce": "function (keys, values, rereduce) { return sum(values); }"
        }   
    }
}
```
之后：
```
{
    "_id": "_design/foo",
    "views": {
        "bar": {
            "map": "function (doc) { emit(doc.author, 1); }",
            "reduce": "_sum"
        }
    }
}
```
# 3 CouchDB备份
* * *
CouchDB在运行时可以创建三种不同类型的文件：

* 数据库文件（包括二级索引）
* 配置文件(`* .ini`)
* 日志文件（如果配置为记录到磁盘）

以下是确保所有这些文件的备份一致的策略。
## 3.1 数据库备份
CouchDB备份的最简单，最简单的方法是使用CouchDB复制到另一个CouchDB安装。您可以根据需要在普通（单次）复制或连续复制之间进行选择。
但是，您也可以随时从CouchDB数据目录(默认为`data/`)中复制实际的`.couch`文件，而不会出现问题。 CouchDB的数据库和二级索引的仅追加存储格式可确保这种方法可以正常工作。
为了确保备份的可靠性，建议先备份二级索引(存储在`data/.shards`下)，然后再备份主数据库文件(存储在`data/ shards`以及父级`data/`下的系统级数据库)目录)。这是因为CouchDB将在下一次读取访问时通过更新视图/二级索引来自动处理稍微过时的视图/二级索引，但是比其关联数据库新的视图或二级索引将触发索引的完全重建。这可能是一项非常昂贵且耗时的操作，并且会影响您在灾难情况下快速恢复的能力。
在受支持的操作系统/存储环境上，您还可以使用存储快照。这些优点是在使用块存储系统(例如`ZFS`或`LVM`或`Amazon EBS`)时几乎是即时的。在块存储级别使用快照时，请确保在必要时使用OS级实用程序(例如Linux的`fsfreeze`)使文件系统停顿。如果不确定，请查阅操作系统或云提供商的文档以获取更多详细信息。
## 3.2 配置备份
CouchDB的配置系统将数据存储在配置目录(默认为`etc/`)下的`.ini`文件中。 如果在运行时对配置进行了更改，则配置链中的最后一个文件将使用更改进行更新。
从备份还原后，简单地备份整个`etc/`目录，以确保配置一致。
如果在运行时未通过HTTP API对配置进行任何更改，并且所有配置文件都由配置管理系统(例如`Ansible`或`Chef`)管理，则无需备份配置目录。
## 3.3 日志备份
如果配置为记录到文件，则可能要备份CouchDB编写的日志文件。这些文件的任何备份解决方案都可以使用。
在类似UNIX的系统上，如果使用日志轮换软件，则必须采用“复制然后截断”的方法。创建副本后，这会将原始日志文件截断为零。CouchDB无法识别要关闭其日志文件并创建一个新信号的任何信号。因此，并且由于文件处理功能的差异，除了定期重新启动CouchDB进程外，在Microsoft Windows下没有简单的日志轮换解决方案。