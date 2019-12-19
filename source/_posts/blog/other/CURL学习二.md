---
title: CURL命令学习二
date: 2019-12-19 20:52:41
tags: curl学习
categories: curl
---
### `-a, --append`

用于上传文件时，如果服务器上该文件不存在则创建，如果存在则追加到源文件。

### `-K, --config <file>`

指定从某个文件读取`curl`参数。如果指定`-`为文件名则从输入读取参数。如：`-K --config -`

### `--connect-timeout <seconds>`

指定连接超时时间，若指定多个时间则采用最后一个。

### `-C --continue-at <offset>`

从给予的偏移量继续文件传输，用于断点续传，如果使用`-C -`则表明由`curl`自动获取从哪里开始继续传输。

### `-c --cookie-jar <filename>`

指定将`cookie`写入的文件，如果指定文件名为`-`，则将`cookie`写入输出。

### `-b --cookie <data|filename>`

将数据添加到`Cookie header`中传输到`HTTP`服务器。数据格式应该为`name1=value1;name2=value2`。如果文件名为`-`，则从输入读取数据。
`-b --cookie`只用于输入`cookie`，并不会写`cookie`信息到本地，所以需要和`-c --cookie-jar`同时使用。

### `--create-dirs`

当使用`-o --output`选项时，`curl`将会创建必要的文件夹分层结构。如果`--output`文件名使用不存在的文件夹或者需要分层的文件夹存在，则没有文件夹被创建。

### `-d --data <data>`

通过POST请求发送具体的数据到HTTP服务器。

### `-f --fail`

当curl请求出现服务器错误时不打印错误信息，通常用于脚本中。只返回错误码22

### `-F --form <name=content>`

与`-d`相似，想服务器发送数据，`-F`是以表单形式

* 发送文件：`curl -F "name=@file.txt" http://www.xxx.html`
* 指定`Content-Type`：`curl -F "web=@index.html;type=text/html" http://www.xxx.html`

### `-i`

在输出中包含HTTP响应头信息。

### `-X`

指定具体的请求方法如`GET,POST...`