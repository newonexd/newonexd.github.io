---
title: IPFS学习-DNS链接
date: 2019-12-18 14:31:30
tags: IPFS
categories: IPFS学习
---
# DNSLink
## 什么是DNS链接
DNS链接使用[DNS TXT](https://en.wikipedia.org/wiki/TXT_record)记录映射域名(如`ipfs.io`)到一个IPFS地址。因为你可以编辑自己的DNS记录，可以使他们总是指向最新版本的IPFS中的对象(如果修改了IPFS中的对象则IPFS中的对象地址也会改变)。由于DNS链接使用DNS记录，所以可以设计名字/路径/(子)域/任何容易分类，阅读和记的名字。
一个DNS链接地址看起来像一个[IPNS]()地址，但是DNS链接使用域名代替了被哈希的公钥:
```
/ipns/myexampledomain.org
```
就像普通的IPFS地址，可以包含链接到其他的文件-或者是其他类型的IPFS支持的资源，像目录和链接：
```
/ipns/myexampledomain.org/media/
```
### 使用子域名发布
虽然您可以根据需要将TXT记录发布到确切的域，但是使用称为`_dnslink`的特殊子域来发布DNSLink记录会更有利。这使您可以提高自动设置的安全性，或将对DNSLink记录的控制权委派给第三方，而不必放弃对原始DNS区域的完全控制权。
例如，`docs.ipfs.io`没有含有TXT记录，但是页面仍然可以加载因为TXT记录在`_dnslink.docs.ipfs.io`中存在。如果查看`_dnslink.docs.ipfs.io`的DNS记录，可以看到以下DNSLink记录：
```
$ dig +noall +answer TXT _dnslink.docs.ipfs.io
_dnslink.docs.ipfs.io.  34  IN  TXT "dnslink=/ipfs/QmVMxjouRQCA2QykL5Rc77DvjfaX6m8NL6RyHXRTaZ9iya"
```

### 使用DNSLink解析
当一个IPFS客户端或者节点尝试解析一个地址，将会寻找前缀为`dnslink=`的TXT记录。剩下的可以是`/ipfs/`链接或者是`/ipns/`，或者是链接到其他的DNSLink。
```
dnslink=/ipfs/<具体内容的CID>
```
例如，回到之前`_dnslink.docs.ipfs.io`的DNS记录继续了解DNS链接实体：
```
$ dig +noall +answer TXT _dnslink.docs.ipfs.io
_dnslink.docs.ipfs.io.  34  IN  TXT "dnslink=/ipfs/QmVMxjouRQCA2QykL5Rc77DvjfaX6m8NL6RyHXRTaZ9iya"
```
基于这个地址：
```
/ipns/docs.ipfs.io/introduction/
```
可以获取这个区块：
```
/ipfs/QmVMxjouRQCA2QykL5Rc77DvjfaX6m8NL6RyHXRTaZ9iya/introduction/
```