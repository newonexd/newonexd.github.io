---
title: CURL命令学习三
date: 2019-12-19 20:52:41
tags: curl学习
categories: curl
---
### `-I`

只获取请求头

### `-k --insecure`

每次SSL连接curl都需要验证是否安全。`-k`参数表示如果不安全也可以继续操作。

### `-4 --ipv4`

告诉curl只使用ipv4地址

### `-6 --ipv6`

告诉curl只使用ipv6

### `--keepalive-time <seconds>`

设置时间保持心跳连接

### `--no-keepalive`

不设置心跳保持连接

### `-l --list-only`

(FTP)当列出FTP文件夹时，该选项强制只列出名字

### `-: --next`

表明curl可一次性发送多个请求。例子：
```
curl www.exam1.com --next -d name=value www.exam2.com
```

### `-N --no-buffer`

不使用输出流的缓冲区