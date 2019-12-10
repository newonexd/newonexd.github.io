---
title: Hyperledger Fabric动态添加组织到网络中
date: 2019-12-10 20:39:37
tags: fabric
categories: fabric应用
---
本文基于Hyperledger Fabric **1.4**版本。
官方文档地址:[传送门](https://hyperledger-fabric.readthedocs.io/en/release-1.4/channel_update_tutorial.html)

动态添加一个组织到Fabric网络中也是一个比较重要的功能。官方文档写的已经很详细了，有能力的尽量还是看官方文档，本文只是根据官方文档进行整理同时兼翻译。

## 1.前提条件

* * *

这个不再解释了，前提条件自然是搭建Fabric的环境了并跑通官方的例子，具体的看[这里](https://ifican.top/2019/11/23/blog/fabric/Fabric%E7%8E%AF%E5%A2%83%E6%90%AD%E5%BB%BA/).

## 2.启动网络

* * *

还是以官方的`byfn`为例好了，不多说，对Fabric有一定了解的都能明白，不明白的看上面文档:
```
./byfn.sh up
#或者是
./byfn.sh up -s couchdb
#区别不大，只不过换了一个数据库而已，对本文内容没多少关系
```
动态添加组织官方脚本自动化操作就简单执行以下命令：
```
./eyfn.sh up
```
本文重点不在这里，因为自动化操作省略了所有的内容，固然简单，但是仍然不懂其中过程。所以本文的重点还是下一部分，手动地一步一步完成动态增加组织。

## 3手动添加组织到网络中

`byfn`网络中的节点为:

* Order -> orderer.example.com
* Org1  -> peer0.org1.example.com
* Org1  -> peer1.org1.example.com
* Org2  -> peer0.org2.example.com
* Org2  -> peer1.org2.example.com

而我们要添加的为:

* Org3  -> peer0.org3.example.com
* Org3  -> peer1.org3.example.com

**在这里，我们假设工作目录在`$GOPATH/.../fabric-samples/first-network`文件夹。上面的五个节点也通过**
```
./byfn.sh up
```
**命令成功启动。**
Fabric网络的启动过程总的来说没有几步(锚节点那部分先省略掉，对本文没有影响)：

1. 为每一个节点生成证书文件
2. 生成系统通道的创世区块(也是配置文件)
3. 生成通道配置文件
4. 启动节点
5. 根据通道配置文件创建通道生成应用通道创世区块
6. 加入通道
7. ...

根据这个流程来考虑动态增加节点：

* 首先为每一个节点生成证书文件是肯定要做的。
* 第二步生成创世区块(系统通道配置文件)是不需要的
* 第三步生成应用通道配置文件需要变为更新应用通道配置文件
* 第四步启动节点步骤不变
* 第五步创建通道也不需要了，直接到第六步加入通道
* ...(网络启动之后的步骤最后再说)

既然分析完了，我们只要按照步骤完成就可以了。

### 3.1生成证书文件
怎么生成证书文件呢，这个直接使用官方的文件就可以了，当然有定制化需求的请自行修改。文件在工作目录下的`org3-artifacts`文件夹下的`org3-crypto.yaml`文件。
这一步比较简单，直接执行命令行工具就可以了，当然对`Fabric CA`比较熟悉的也可以采用手动生成证书的方法，本文为了简便，直接使用工具生成：
```
cd org3-artifacts
cryptogen generate --config=./org3-crypto.yaml
```
完成之后在`org3-artifacts`目录下生成一个`crypto-config`文件夹。里面就是需要添加的新组织的证书文件。
如果网络开启`TLS`的话，在多机环境下还需要将`Orderer`的`TLS`根证书拷贝一份过来用于之后的与`Orderer`节点进行通信,而单机环境下也可以直接将`Orderer`的`TLS`根证书挂载到之后需要启动的`Org3`的容器内部。而本文采用和官方文档相同的方法，直接拷贝文件：
```
cd ../ && cp -r crypto-config/ordererOrganizations org3-artifacts/crypto-config/
```

### 3.2更新通道配置文件
接下来第三步：更新通道配置文件，可以分为以下步骤：

1. 获取网络中当前通道之前最新的配置区块
2. 把需要更新的内容添加进去
3. 把最新的配置文件更新到网络中

#### 3.2.1获取最新的配置区块
看一下第一步获取网络中之前最新的配置区块，如何获取呢，自然是通过网络中现有的节点进行获取，并且使从`peer`节点向`Orderer`节点发起通信获取配置区块。
首先进入`cli`容器：
```
docker exec -it cli bash
```
配置需要的环境变量:
```
export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem 
export CHANNEL_NAME=mychannel
```
**如果操作中途退出了`cli`容器，那么再次进入时都需要重新配置环境变量.**
接下来获取之前最新的配置区块：
```
peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA
```

* `peer channel fetch`: 从指定的通道获取具体的区块并写入文件。
* `config` :指定获取的区块是配置区块.(Fabric网络中区块类型可分为普通交易区块和配置区块)
* `config_block.pb`:将配置区块写入到这个文件中
* `-o `:指定向具体的排序节点发起通信
* `-c`:指定通道名称
* `--tls`:如果开启了`TLS`则需要指定这个参数
* `--cafile`:`TLS`根证书文件

执行完毕后命令行会打印这些信息：
```
 UTC [channelCmd] InitCmdFactory -> INFO 001 Endorser and orderer connections initialized
 UTC [cli.common] readBlock -> INFO 002 Received block: 4
 UTC [cli.common] readBlock -> INFO 003 Received block: 2
 UTC [channelCmd] fetch -> INFO 004 Retrieving last config block: 2
```
可以看到`mychannel`通道中共生成了5个区块(创世区块序号为0).但是最新的配置区块序号为2:

1. 配置区块0：创世区块
2. 配置区块1：组织一的锚节点更新
3. 配置区块2：组织二的锚节点更新
4. 普通区块3：实例化链码
5. 普通区块4：调用链码

而本文获取到了最新的配置区块也是是区块2，并将该区块写入到了`config_block.pb`文件中。

#### 3.2.2将配置信息添加到配置文件中

我们已经获取到了最新的配置文件，接下来如何更新它呢，因为区块内容是编码过的，而且还包括区块头，元数据以及签名等信息，对更新配置是用不到的。所以需要先将区块进行解码成我们可读的文件，而且为了简单化，可以将不相关的区块头等信息去掉(当然不去掉也没有问题)。
这里用到了两个工具：Fabric官方的命令行工具`configtxlator`，以及`jq`工具:
`configtxlator`工具可以帮助我们进行编解码转换
`jq`工具和`Linux`中的`grep`,`awk`命令较为相似，都是对数据进行处理的(当然不使用这个工具也没什么问题，只不过需要手动修改数据而已)。
接下来就是将区块信息解码去除不相关的信息后并以`json`格式保存到文件中：
```
configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json
```

* `proto_decode` :解码操作
* `--input`:需要解码的文件作为输入
* `--type`:输入文件的类型

解码后通过`jq`工具提取需要的数据并保存到了`config.json`文件中。

接下来呢，就是将组织三的配置信息写到这里面，组织三的配置信息呢？我们还没有生成它，之前只是为组织三生成了证书文件。所以我们还需要生成组织三的配置信息。
同样的，用于生成配置信息的源文件官方也给了，在工作目录下的`org3-artifacts`文件夹下的`configtx.yaml`文件。
因为上一步我们将通道内的最新的配置文件转换为了`json`格式，所以这里我们也需要将这个文件内的配置信息转换为`json`格式：
```
#打开新的终端进入以下目录中
cd $GOPATH/.../fabric-samples/first-network/org3-argifacts/
#指定配置文件所在路径 或者是通过-configPath路径指定
export FABRIC_CFG_PATH=$PWD 
#直接通过工具将配置信息写到org3.json文件中。
configtxgen -printOrg Org3MSP > ../channel-artifacts/org3.json
```
现在让我们回到之前的终端继续操作，将刚刚生成的`org3.json`文件添加到`config.json`文件中，通过`jq`工具：
```
jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"Org3MSP":.[1]}}}}}' config.json ./channel-artifacts/org3.json > modified_config.json
```
这一行命令就是将`org3.json`这个文件添加到`config.json`文件的`channel_group->groups->Application->groups->Org3MSP`下，并保存到`modified_config.json`文件。
接下来就是获取原始配置文件和新的配置文件的不同点了,官方文档的意思是只保留组织3的定义以及一个指向组织1与组织2的高级指针，因为没有必要连同之前的配置文件一起更新，所以只需要一个指针指向原配置(个人理解)。
具体的操作方法是将上面两个`json`文件编码回去，然后使用`configtxlator`工具进行比较更新。
操作命令：

* `config.json`文件,编码后输出到`config.pb`文件。
```
configtxlator proto_encode --input config.json --type common.Config --output config.pb
```

* `modified_config.json`文件，编码后输出到`modified_config.pb`文件。
```
configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
```
* 计算两个文件的差异并输出到`org3_update.pb`文件：
```
# --original 指定原配置文件   --updated 指定新配置文件
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output org3_update.pb
```
接下来还需要做一件事，就是封装一个更新配置的文件，将`org3_update.pb`写进去，毕竟向Fabric添加组织需要更新Fabric的配置，自然是需要将配置文件按照Fabric规定的文件类型封装好才能更新网络。
然后封装配置信息又会涉及到一些额外的信息，说简单点就是Fabric规定的文件类型的标识符之类的，所以需要我们再次解码，然后添加这些额外的信息进去：
```
configtxlator proto_decode --input org3_update.pb --type common.ConfigUpdate | jq . > org3_update.json
```
添加额外的数据：
```
echo '{"payload":{"header":{"channel_header":{"channel_id":"mychannel", "type":2}},"data":{"config_update":'$(cat org3_update.json)'}}}' | jq . > org3_update_in_envelope.json
```
到最后一步配置更新消息就完成了，那就是将文件以特定的文件类型封装起来：
```
configtxlator proto_encode --input org3_update_in_envelope.json --type common.Envelope --output org3_update_in_envelope.pb
```
#### 3.2.3更新应用通道配置文件
配置更新消息已经处理好了，接下来就是更新到网络中了。在此时，新添加的组织信息还没有更新进去，所以还是需要使用之前的组织将配置进行更新，首先就是需要带有`Admin`身份的多数节点进行签名(策略这块以后再讲)，所以需要每个组织中各一个节点进行签名，首先是`peer0.org1`,由于之前打开的`cli`容器默认身份就是`peer0.org1`，所以不需要配置环境变量直接进行签名：
```
peer channel signconfigtx -f org3_update_in_envelope.pb
```
接下来是组织二的节点：
```
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=peer0.org2.example.com:9051
```
实际上我们只需要进行配置文件更新就行了，因为在配置更新操作中如果没有签名默认会先进行签名的:
```
peer channel update -f org3_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --tls --cafile $ORDERER_CA
```
如果命令行日志打印出一下内容说明更新通道配置成功：
```
UTC [channelCmd] update -> INFO 002 Successfully submitted channel update
```
在此时，区块5将会生成并写到每一个节点的账本，比如我们查看`peer0.org1`的日志信息，可以看到以下内容：
```
#打开一个新的命令行
docker logs -f peer0.org1.example.com
##日志内容
UTC [gossip.privdata] StoreBlock -> INFO 07c [mychannel] Received block [5] from buffer
...
UTC [gossip.gossip] JoinChan -> INFO 07d Joining gossip network of channel mychannel with 3 organizations
...
UTC [committer.txvalidator] Validate -> INFO 082 [mychannel] Validated block [5] in 238ms
...
UTC [kvledger] CommitWithPvtData -> INFO 08b [mychannel] Committed block [5] with 1 transaction(s) in 238ms
...
```
### 3.4启动节点并加入通道
到这里，组织三的信息已经更新到网络中了，所以我们可以启动组织三的节点了：
```
docker-compose -f docker-compose-org3.yaml up -d
```
启动成功后进入组织三的`cli`容器：
```
docker exec -it Org3cli bash
```
第一步还是配置环境变量，还记得一开始我们将排序节点的根证书复制的那一步吧，现在就派上用场了：
```
export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem 
export CHANNEL_NAME=mychannel
#检查一下是否配置成功
echo $ORDERER_CA && echo $CHANNEL_NAME
```
没问题的话就可以进行加入通道了，如果加入通道呢，肯定是需要创世区块了，所以需要从排序节点处获取它：
```
#这里不能用peer channel fetch config ... 否则获取到的是刚生产的区块5，只有使用创世区块才能加入通道
peer channel fetch 0 mychannel.block -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA
###命令行打印出一下内容
UTC [cli.common] readBlock -> INFO 002 Received block: 0
```
最后加入通道：
```
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org3.example.com/peers/peer1.org3.example.com/tls/ca.crt && export CORE_PEER_ADDRESS=peer1.org3.example.com:12051
peer channel join -b mychannel.block
```
### 3.5测试
一切都没有问题，就差测试链码能不能用了。
**首先这里注意一点，在新的组织添加进通道之前，链码的背书策略并没有涉及到新的组织，所以之前的链码对于新的组织是不能使用的，包括查询，调用以及更新操作**。但是安装链码是可以用的(前提是版本和链码名称不能全部相同)，所以我们需要通过之前的组织更新链码，并制定背书策略将新的组织添加进来。
切换到组织一的节点：
```
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051
```
安装新版本的链码：
```
peer chaincode install -n mycc -v 2.0 -p github.com/chaincode/chaincode_example02/go/
## 更新背书策略将新的组织添加进来
peer chaincode upgrade -o orderer.example.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -v 2.0 -c '{"Args":["init","a","90","b","210"]}' -P "OR ('Org1MSP.peer','Org2MSP.peer','Org3MSP.peer')"
#测试一下更新是否成功
peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}'
## Query Result: 90
```
切换回组织三的节点容器：
```
docker exec -it Org3cli bash
export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem 
export CHANNEL_NAME=mychannel
```
安装链码：
```
peer chaincode install -n mycc -v 2.0 -p github.com/chaincode/chaincode_example02/go/
```
安装完测试一下：
```
peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}'
# Query Result: 90
```
查询没问题，调用一下试试：
```
peer chaincode invoke -o orderer.example.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}'
```
再次查询：
```
peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}'
# Query Result: 80
```
没问题了，到这里我们成功将组织三动态添加到网络中了。

### 3.5更新组织三的锚节点
至于这一部分，以后再补充好了。。。。。未完待续