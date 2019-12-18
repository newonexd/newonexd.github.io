---
title: IPFS学习-内容标识符(CIDs)
date: 2019-12-18 11:14:57
tags: IPFS
categories: IPFS学习
---
# 内容标识符(CIDs)
内容标识符也称为CID，是用于指向IPFS中材料的标签。 它不会指示内容的存储位置，但会根据内容本身形成一种地址。 CID简短，无论其基础内容的大小如何。

CID基于内容的[加密哈希](http://localhost:1313/guides/concepts/hashes/)，意思是：

* 任何不相同的内容将会产生不同的CID
* 内容中相同的部分添加到两个不同的IPFS节点通过相同的设置应该产生相同的CID。

## CID格式
基于不同的编码或者是CID的版本使得CID具有不同的格式。多数存在的IPFS工具仍生成版本0的CID。但是`file`([MFS](http://localhost:1313/guides/concepts/mfs/))和`object`现在默认使用CID V1.

### 版本0
当IPFS初始设计的时候，使用base58多次哈希作为内容标识符(虽然简单，但是与新的CID相比缺乏灵活性。)CIDv0仍然是许多IPFS默认选项，所以IPFS版本应该支持v0。

如果一个CID具有46字符并以`Qm`开头，说明是一个CIDv0

### 版本1
CID v1包含一些前导标识符，这些标识符明确说明了使用哪种表示形式以及内容哈希本身。 这些包括：

* [multibase](https://github.com/multiformats/multibase)前缀，指定用于其余CID的编码.
* CID版本标识符，指示这是哪个CID版本
* 一个[多编解码器](https://github.com/multiformats/multicodec)标识符，指示目标内容的格式-帮助人们和软件在获取内容后知道如何解释该内容

这些前导标识符还提供前向兼容性，支持在将来的CID版本中使用的不同格式。
您可以使用CID的前几个字节来解释内容地址的其余部分，并知道从IPFS提取内容后如何对其进行解码。 有关更多详细信息，请查看[CID规范](https://github.com/ipld/cid)。 它包括[解码算法](https://github.com/ipld/cid/blob/ef1b2002394b15b1e6c26c30545fd485f2c4c138/README.md#decoding-algorithm)，并链接到用于解码CID的现有软件实现。

## 探索CID
是否想分解特定CID的多库，多编解码器或多哈希信息？ 您可以使用IPLD资源管理器中的[CID检查器](https://cid.ipfs.io/#QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU)或[CID信息面板](https://explore.ipld.io/#/explore/QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU)（两个链接都使用示例CID启动）来对不同格式的CID进行交互式细分。 还了解IPFS中[CID的未来](https://discuss.ipfs.io/t/who-decides-what-hashing-algorithms-ipfs-allows/6742)。