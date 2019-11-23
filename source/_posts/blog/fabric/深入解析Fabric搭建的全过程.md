---
title: 深入解析Hyperledger Fabric搭建的全过程
date: 2019-11-23 18:46:49
tags: fabric
---
在这篇文章中，使用``fabric-samples/first-network``中的文件进行fabric网络(solo类型的网络)搭建全过程的解析。如有错误欢迎批评指正。
至于Fabric网络的搭建这里不再介绍，可以参考这一篇文章[Hyperledger Fabric环境搭建过程]()
fabric网络：单机，solo类型，两个组织，分别有两个节点
首先看一下该文件夹内有哪些文件：
```
base                  connection-org2.json    docker-compose-cli.yaml           docker-compose-org3.yaml
byfn.sh               connection-org2.yaml    docker-compose-couch-org3.yaml    eyfn.sh
channel-artifacts     connection-org3.json    docker-compose-couch.yaml         org3-artifacts
configtx.yaml         connection-org3.yaml    docker-compose-e2e-template.yaml  README.md
connection-org1.json  crypto-config.yaml      docker-compose-etcdraft2.yaml     scripts
connection-org1.yaml  docker-compose-ca.yaml  docker-compose-kafka.yaml
```
将本次用不到的文件删除，剩余的文件：
```
.
├── base
│   ├── docker-compose-base.yaml
│   └── peer-base.yaml
├── channel-artifacts
├── configtx.yaml
├── crypto-config.yaml
├── docker-compose-cli.yaml
├── docker-compose-couch.yaml
├── docker-compose-e2e-template.yaml

```
##1.证书的生成
在Fabric网络环境中，第一步需要生成各个节点的证书文件，所用到的配置文件为``crypto-config.yaml``，说明一下文件内各字段的意义：
```
OrdererOrgs:    #定义一个Order组织
  - Name: Orderer    #order节点的名称,当前网络模式为solo类型，所以只定义了一个Order节点
    Domain: example.com    #order节点的域
    Specs:      #暂时用不到
      - Hostname: orderer
      - Hostname: orderer2
      - Hostname: orderer3
      - Hostname: orderer4
      - Hostname: orderer5

PeerOrgs:      #定义Peer组织
  - Name: Org1      #声明Peer组织名称为Org1
    Domain: org1.example.com    #Org1组织的域
    EnableNodeOUs: true    #暂时没搞清楚该字段的意义
    Template:       #在这里可以定义所生成的Org1组织中的Peer节点证书数量，不包括Admin
      Count: 2      #表明需要生成两个Peer节点的证书，如果需要其他数量的Peer节点，只需要更改这里的数量。
    Users:        #在这里可以定义所生成的Org1组织中类型为User的证书数量，不包括Admin
      Count: 1    #生成用户的证书的数量

  - Name: Org2   #声明第二个Peer组织名称为Org2，如果需要更多的Peer组织证书，只需要按该模板添加即可。
    Domain: org2.example.com  #与以上相同 
    EnableNodeOUs: true
    Template:
      Count: 2
    Users:
      Count: 1
```
我们这里就使用两个组织，每个组织分别有两个节点和一个User。接下来我们使用该文件生成对应数量的证书：
```
#路径需要更改为自己的路径
cd ~/go/src/github.com/hyperledger/fabric/scripts/fabric-samples/first-network/  
#在这里可能会报错，通常是权限问题，可以添加sudo重新执行
cryptogen generate --config=./crypto-config.yaml
#执行完毕后，当前文件夹下会出现一个新的文件夹：crypto-config，在该文件夹下就是刚刚生成的证书.
```
文件夹内证书不再详解，会在另一篇文章中专门解释Fabric-ca的内容。
##2 生成创世区块，通道配置，锚节点配置文件
在这里需要用到``configtxgen``这个二进制文件。
####2.1生成创世区块 
```
#首先进入文件夹
cd ~/go/src/github.com/hyperledger/fabric/scripts/fabric-samples/first-network/  
#执行命令生成创世区块 
configtxgen -profile TwoOrgsOrdererGenesis -channelID mychannel -outputBlock ./channel-artifacts/genesis.block
#如果没有channel-artifacts这个文件夹，则需要手动去创建
```
如果没有出现错误的话，在``channel-artifacts``文件夹中可以看至生成的``genesis.block``文件。
####2.2生成通道配置信息
```
#执行命令生成通道配置信息
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID mychannel
```
同样，在``channel-artifacts``文件夹中可以看至生成的``channel.tx``文件。
####2.3生成锚节点配置文件 
```
#首先生成Org1的锚节点配置文件
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID mychannel -asOrg Org1MSP
#生成Org2的锚节点配置文件
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID mychannel -asOrg Org2MSP
```
所有需要的配置文件全部建立完成，在``channel-artifacts``中应该有以下几个文件:
```
channel.tx  genesis.block  Org1MSPanchors.tx  Org2MSPanchors.tx
```
[启动网络]:##3启动网络
##3启动网络
到了这一步，可以启动网络了。
```
#首先进入``fabric-samples/first-network``文件夹。
cd ~/go/src/github.com/hyperledger/fabric/scripts/fabric-samples/first-network/
#启动容器
sudo docker-compose -f docker-compose-cli.yaml up -d
```
执行以下命令查看容器是否启动成功:
```
sudo docker ps
#如果可以看到如下信息说明启动成功
CONTAINER ID        IMAGE                               COMMAND             CREATED             STATUS              PORTS                      NAMES
17d79586b1b7        hyperledger/fabric-tools:latest     "/bin/bash"         30 seconds ago      Up 28 seconds                                  cli
0f4adb6b578e        hyperledger/fabric-orderer:latest   "orderer"           57 seconds ago      Up 29 seconds       0.0.0.0:7050->7050/tcp     orderer.example.com
e2795ea9d43b        hyperledger/fabric-peer:latest      "peer node start"   57 seconds ago      Up 30 seconds       0.0.0.0:10051->10051/tcp   peer1.org2.example.com
247a6e4fdd62        hyperledger/fabric-peer:latest      "peer node start"   57 seconds ago      Up 30 seconds       0.0.0.0:9051->9051/tcp     peer0.org2.example.com
ad4af3309e8c        hyperledger/fabric-peer:latest      "peer node start"   57 seconds ago      Up 31 seconds       0.0.0.0:8051->8051/tcp     peer1.org1.example.com
f6d25896b517        hyperledger/fabric-peer:latest      "peer node start"   58 seconds ago      Up 40 seconds       0.0.0.0:7051->7051/tcp     peer0.org1.example.com
```
####3.1创建通道
创建通道需要进入cli容器：
```
sudo docker exec -it cli bash
#看到光标前的信息变为
root@17d79586b1b7:/opt/gopath/src/github.com/hyperledger/fabric/peer# 
#则成功进入容器
```
首先配置环境变量：
```
#当前cli容器默认配置是节点peer0,所以不需要其他配置信息
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
#创建通道信息
peer channel create -o orderer.example.com:7050 -c mychannel -f ./channel-artifacts/channel.tx --tls true --cafile $ORDERER_CA
#看到如下信息说明创建通道成功
2019-06-20 13:05:55.829 UTC [channelCmd] InitCmdFactory -> INFO 001 Endorser and orderer connections initialized
2019-06-20 13:05:55.926 UTC [cli.common] readBlock -> INFO 002 Received block: 0
#将生成的文件移动到channel-artifacts文件夹中
mv mychannel.block channel-artifacts/
```
####3.2加入通道
```
#因为当前cli容器使用的是peer0的配置，所以可以直接将peer0加入通道 
 peer channel join -b channel-artifacts/mychannel.block
#更新环境变量使其他节点也加入通道
#=========peer1.org1===========  注意这里端口要与上面文件中配置的端口号相同
CORE_PEER_ADDRESS=peer1.org1.example.com:8051  
#=========peer0.org2============
CORE_PEER_LOCALMSPID="Org2MSP"
CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
CORE_PEER_ADDRESS=peer0.org2.example.com:9051
peer channel join -b channel-artifacts/mychannel.block 
#=========peer1.org2=============
CORE_PEER_ADDRESS=peer1.org2.example.com:10051
peer channel join -b channel-artifacts/mychannel.block
#退出容器
exit
```
####3.3更新锚节点 
```
#重新进入容器
sudo docker exec -it cli bash
#更新环境变量
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
#========Org1================
peer channel update -o orderer.example.com:7050 -c mychannel -f ./channel-artifacts/Org1MSPanchors.tx --tls true --cafile $ORDERER_CA
#========Org2================
peer channel update -o orderer.example.com:7050 -c mychannel -f ./channel-artifacts/Org2MSPanchors.tx --tls true --cafile $ORDERER_CA
#退出容器
exit
```
####3.4安装链码
```
#链码的安装仍然需要在所有节点上进行操作
#进入容器
sudo docker exec -it cli bash
#更新环境变量
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
#=========peer0.org1=========== 
#这里很有可能会出现路径不存在的错误，解决方法是在容器内找到对应的链码所在位置，然后替换当前链码路径
##比如本文中链码路径为/opt/gopath/src/github.com/chaincode/chaincode_example02/go
##则可以将以下命令的链码路径更改为github.com/chaincode/chaincode_example02

peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example02
#实例化链码 该步骤创建了a,b两个账户，其中a账户余额定义为100，b账户余额定义为200
peer chaincode instantiate -o orderer.example.com:7050 --tls true --cafile $ORDERER_CA -C mychannel -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR      ('Org1MSP.member','Org2MSP.member')"
#这一步执行完毕后可以在其他节点上也安装链码，具体环境变量配置见本文中4.2
```
####3.5调用链码
```
#以peer0.org1为例
#首先进入cli容器
sudo docker exec -it cli bash
#执行以下命令进行查询a账户余额
peer chaincode query -C mychannel -n mycc -c '{"Args":["query","a"]}'
#如果命令行输出100说明链码成功调用.

#接下来我们发起一笔交易：通过peer0.org1节点将a账户余额转账给b20
peer chaincode invoke -o orderer.example.com:7050  --tls true --cafile $ORDERER_CA -C mychannel -n mycc -c '{"Args":["invoke","a","b","10"]}'
#然后登陆peer1.org1节点进行查询
CORE_PEER_ADDRESS=peer1.org1.example.com:8051 
peer chaincode query -C mychannel -n mycc -c '{"Args":["query","a"]}'
#如果输出结果为:80
说明Fabric网络手动搭建成功
#退出容器
exit
```
最后关闭网络：
```
sudo docker-compose -f docker-compose-cli.yaml down --volumes 
#删除生成的文件，下次启动网络需要重新生成
sudo rm -r channel-artifacts crypto-config
```
##4总结
本文并没有使用CouchDb作为fabric网络的数据库，准备放到下一篇多机搭建Fabric网络中一起讲解。到这里，整个网络的手动搭建过程已经完成，希望大家能够有所收获。