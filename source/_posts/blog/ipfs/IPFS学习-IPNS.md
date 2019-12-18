---
title: IPFS学习-IPNS
date: 2019-12-18 14:57:50
tags: IPFS
categories: IPFS学习
---
星际名称系统(IPNS)是一个创建个更新可变的链接到IPFS内容的系统，由于对象在IPFS中是内容寻址的，他们的内容变化将导致地址随之变化。对于多变的事物是有用的。但是很难获取某些内容的最新版本。

在IPNS中名字是被哈希的公钥。它与一条记录相关联，该记录包含有关其链接的哈希的信息，该信息由相应的私钥签名。新的记录可以在任何时候被签名与发布。
查看IPNS地址，使用了`/ipns/`前缀：
```
/ipns/QmSrPmbaUKA3ZodhzPWZnpFgcPMFWF4QsxXbkWfEptTBJd
```
IPNS不是在IPFS上创建可变地址的唯一方法。 您还可以使用[DNSLink]()（当前比IPNS快得多，并且还使用更易读的名称）。 其他社区成员正在探索使用区块链存储通用名称记录的方法。

例如：
假设您要在IPFS下发布您的网站。 您可以使用[Files API]()发布静态网站，然后获得一个可以链接到的CID。 但是，当您需要进行更改时，就会出现问题：您将获得一个新的CID，因为您现在拥有不同的内容。 而且，您不可能总是给别人新的地址。
这是Name API派上用场的地方。 使用它，您可以创建一个稳定的IPNS地址，该地址指向您网站最新版本的CID。
```
//文件的地址
const addr = '/ipfs/QmbezGequPwcsWo8UL4wDF6a8hYwM1hmbzYv2mnKkEWaUp'

ipfs.name.publish(addr, function (err, res) {
    // 接收到包含两个字段的资源：
    //   - name: 被发布的内容的名字
    //   - value: 名字指向的"真实"的地址
    console.log(`https://gateway.ipfs.io/ipns/${res.name}`)
})
```
用这种方式，可以使用相同的地址重新发布一个新的版本到网页，默认情况下，`ipfs.name.publish`将会使用节点ID。