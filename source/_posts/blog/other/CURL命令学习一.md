---
title: CURL命令学习一
date: 2019-12-17 10:17:40
tags: curl学习
categories: curl
---
每天学习一点点。。。。

* 直接获取页面数据：

```
curl http://www.xxx.com/[可以指定具体的路径获取某个文件]
```

### 用户名(密码):

```
curl -u username http://www.xxx.com
curl -u username:pwsswd http://www.xxx.com
curl http://name:passwd@xxx.domain/filepath/
```

### 下载页面数据：

```
#以`demo.html`文件保存
curl -o demo.html http://www.xxx.com/
```

* 下载某个页面数据保存到本地并以源页面名称为默认命名(可以指定多个页面)：

```
curl -O http://www.xxx.com/index.html/. [-O http://www.xxx2.com/html/]
```

* 代理 

```
curl -x proxy:port http://www.xxx.com/
#如果代理需要名字和密码，用-U指定(-u)指定页面需要的用户名密码
curl -U user:passwd -x proxy:port http://www.xxx.com/
```

* 获取部分数据

```
#获取前100比特数据
curl -r 0-99 http://www.xxx.com/
#获取最后100比特数据
curl -r -100 http://www.xxx.com/
```

### 上传文件

```
#上传所有文件或者是从输入上传
curl -T - ftp://ftp.upload.com/myfile
#上传文件到远程服务器并使用本地文件名
curl -T uploadfile ftp://ftp.upload.com/
#上传文件并添加到远程文件中
curl -T uploadfile -a ftp://ftp.upload.com/
```

### 打印日志信息

```
curl -v http://www.xxx.com
#获取更多信息
curl --trace http://www.xxx.com
```

### POST方法

```
curl -d "name=value&name1=value1" http://www.xxx.com/
-F 从文件中读取
curl -F "coolfiles=@fill.gif;type=image/gif,fil2.txt,fil3.html" http://www.xxx.com/
curl -F ”file=@coottext.txt“ -F "name=value" -F "name=value1 value2 ..." htttp://www.xxx.com/
curl -F "pict=@dog.gif,cat.gif" http://www.xxx.com/
```

### Agent

```
curl -A 'Mozilla/3.0 (Win95; I)' http://www.xxx.com/
```

### Cookies

```
curl -b "name=value" http://www.xxx.com
curl -c cookies.txt http://www.xxx.com
#read write
curl -b cookies.txt -c cookies.txt http://www.xxx.com
```

### 额外的头部信息

```
curl -H "X-you-and-me: yes" http://www.xxx.com
```

### FTP 防火墙 

```
#使用192.168.0.10作为IP地址
curl -P 192.168.0.10 ftp.download.com
```

### HTTPS

```
curl -E /path/to/cert.pem:password https://www.xxx.com
```

### 文件续传

```
#download
curl -C - -o file ftp://ftp.server.com/path/file
#upload
curl -C - -T file ftp://ftp.server.com/path/file
```

### -L
如果页面内容移动到另一个页面比如返回状态码30X，则向新的页面发送请求

### -s
静默模式，没有输出

### -S
当使用`-s`时，输出错误信息。