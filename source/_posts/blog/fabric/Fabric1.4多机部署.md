---
title: Hyperledger Fabric多机部署
date: 2019-11-23 18:38:53
tags: fabric
categories: fabric应用
---
之前的文章[深入解析Hyperledger Fabric启动的全过程]()主要讲解了Fabric的网络搭建，以及启动的整体流程，但是都是通过单机完成的。而区块链本身就是去中心化的，所以最终还是要完成Fabric网络的多机部署。在本文中，将会详细说明Fabric如何完成多机部署。
### 1搭建环境
 **本文使用的是Fabric 1.4版本，搭建solo模式的4+1的架构:1Order,4Peer，数据库使用CouchDb**，所以这里需要五台机器。同时，五台机器的网络需要互通，系统使用Ubuntu16.04。

| 域名|ip地址|
|:----|:----|
|orderer.example.com|10.65.182.150|
|peer0.org1.example.com|10.65.26.64|
|peer1.org1.example.com|10.65.26.140|
|peer0.org2.example.com|10.65.200.182|
|peer1.org2.example.com|10.65.200.44|
Fabric的环境搭建过程不再详解，可以参考这一篇文章[Hyperledger Fabric环境搭建过程]()
## 2.多机环境搭建
如果要成功搭建多机下的Fabric运行环境，首先要保证五台机子上的Fabric网络可以正常运行。
按照[Hyperledger Fabric环境搭建过程]()在五台机子上搭建Fabric完成后，
就可以对相应的配置文件进行修改了，这里本文只在Orderer节点的机子上修改配置文件，最后通过scp命令将配置文件复制到其余四台机子，保证所有的节点所使用的配置文件都是相同的。
在官方的例子中，已经有很多模板可以拿来进行修改，这里本文使用``first-network``这个文件夹内的配置文件来修改为自己所需要的配置文件。

**本文以orderer节点为例，在``10.65.182.150``这台服务器上进行操作。**
### 2.1准备配置文件
```
#step1 进入到first-network文件夹的上一级目录
cd ~/go/src/github.com/hyperledger/fabric/scripts/fabric-samples/
#step2 拷贝first-network文件夹，并命名为first
cp -r first-network/ first
#step3 进入到first文件夹内
cd first
#step4 删除此次多机环境搭建使用不到的文件，文件夹内剩余的文件有
.
├── base
│   ├── docker-compose-base.yaml
│   └── peer-base.yaml
├── channel-artifacts
├── configtx.yaml
├── crypto-config.yaml
├── docker-compose-cli.yaml
├── docker-compose-couch.yaml
```
本文就对以上文件进行修改搭建自己的Fabric多机网络
由于官方的``first-network``中的配置文件中使用的就是4+1的架构，所以我们可以直接生成所需要的证书文件，创世区块，通道配置文件。
### 2.2生成相关配置文件
```
#step1 生成证书文件
cryptogen generate --config=./crypto-config.yaml
#step2 生成创世区块  首先要确保channel-artifacts文件夹存在，如果不存在需要手动创建，不然会报错
configtxgen -profile TwoOrgsOrdererGenesis -channelID mychannel -outputBlock ./channel-artifacts/genesis.block
#step3 生成通道配置文件  其中通道名mychannel可以修改为自己的
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID mychannel
#step4 生成锚节点配置文件
#========Org1=============
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID mychannel -asOrg Org1MSP
##========Org2=============
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID mychannel -asOrg Org2MSP
```
所有需要的配置文件全部建立完成，在``channel-artifacts``中应该有以下几个文件。
``channel.tx、genesis.block、Org1MSPanchors.tx、Org2MSPanchors.tx``
### 2.3修改节点配置文件
#### 2.3.1``base/docker-compose-base.yaml``
这个文件中配置了所有节点的一些基本信息，我们需要修改的地方有
```
peer0.org1.example.com:
    container_name: peer0.org1.example.com
    extends:
      file: peer-base.yaml
      service: peer-base
    environment:
      - CORE_PEER_ID=peer0.org1.example.com
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer0.org1.example.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer1.org1.example.com:8051  #这里个性为7051,因为我们是多机环境，不存在端口冲突问题
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org1.example.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
    volumes:
        - /var/run/:/host/var/run/
        - ../crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp:/etc/hyperledger/fabric/msp
        - ../crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls:/etc/hyperledger/fabric/tls
        - peer0.org1.example.com:/var/hyperledger/production
    ports:
      - 7051:7051

  peer1.org1.example.com:
    container_name: peer1.org1.example.com
    extends:
      file: peer-base.yaml
      service: peer-base
    environment:
      - CORE_PEER_ID=peer1.org1.example.com
      - CORE_PEER_ADDRESS=peer1.org1.example.com:8051   #  7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:8051    #7051
      - CORE_PEER_CHAINCODEADDRESS=peer1.org1.example.com:8052  #7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:8052   #7052
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1.org1.example.com:8051  #7051
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org1.example.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
    volumes:
        - /var/run/:/host/var/run/
        - ../crypto-config/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/msp:/etc/hyperledger/fabric/msp
        - ../crypto-config/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls:/etc/hyperledger/fabric/tls
        - peer1.org1.example.com:/var/hyperledger/production

    ports:
      - 8051:8051   #这里不要忘记修改为   7051:7051
...
#以下全部需要修改   8051/9051/10051修改为7051     8052/9052/10052修改为7052
#其余地方不需要修改
```
#### 2.3.2 ``docker-compose-cli.yaml``
本文需要使用该文件启动节点，我们将该文件复制一份，**以orderer节点为例**：
```
#复制该文件，并命名为docker-compose-orderer.yaml
cp docker-compose-cli.yaml docker-compose-orderer.yaml
#用编辑器打开该文件
sudo vim docker-compose-orderer.yaml
```
我们只在这台电脑上启动orderer节点，所以关于peer节点的信息用不到，我们将配置文件中多余的字段删除，只留下这些内容：
```
version: '2'

volumes:
  orderer.example.com:

networks:
  byfn:

services:

  orderer.example.com:
    extends:
      file:   base/docker-compose-base.yaml
      service: orderer.example.com
    container_name: orderer.example.com
    networks:
      - byfn

```
接下来可以启动Orderer节点了,执行以下命令启动Orderer节点。
```
sudo docker-compose -f docker-compose-orderer.yaml up
```
orderer节点启动成功后，我们使用scp命令将``first``文件夹传输到peer0.org1节点服务器。
```
#step1 进入到上级目录
cd ..
#step2 传输文件
sudo scp -r first/ [peer0.org1节点主机名]@10.65.26.64:/home/[用户名]/
```
然后，我们登陆``10.65.26.64``主机，对peer0.org1节点进行配置,同样，我们复制一份``docker-compose-cli.yaml``文件：
```
#step1:进入传输到的first文件夹
cd ~/first
#step2:复制docker-compose-cli.yaml文件 并命名为docker-compose-peer0-Org1.yaml
cp docker-compose-cli.yaml docker-compose-peer0-Org1.yaml
#step3:用编辑器打开该文件
vim docker-compose-peer0-Org1.yaml
```
对于peer0.Org1节点，同样，首先删除多余的部分，添加一些字段，最终文件内容为：
```
version: '2'

volumes:
  peer0.org1.example.com:

networks:
  byfn:

services:

  peer0.org1.example.com:
    container_name: peer0.org1.example.com
    extends:
      file:  base/docker-compose-base.yaml
      service: peer0.org1.example.com
    networks:
      - byfn
    extra_hosts:       #=========需要添加的额外字段，这里不写当前节点
      - "orderer.example.com:10.65.182.150"
      - "peer1.org1.example.com:10.65.26.140"
      - "peer0.org2.example.com:10.65.200.182"
      - "peer1.org2.example.com:10.65.200.44"

  cli:
    container_name: cli
    image: hyperledger/fabric-tools:$IMAGE_TAG
    tty: true
    stdin_open: true
    environment:
      - GOPATH=/opt/gopath
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - FABRIC_LOGGING_SPEC=DEBUG    #这里改为DEBUG
      - CORE_PEER_ID=cli
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
      - CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: /bin/bash
    volumes:
        - /var/run/:/host/var/run/
        - ./../chaincode/:/opt/gopath/src/github.com/chaincode
        - ./crypto-config:/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/
        - ./scripts:/opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/
        - ./channel-artifacts:/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts
    depends_on:
      - peer0.org1.example.com
    networks:
      - byfn
    extra_hosts:       #=========需要添加的额外字段.
      - "orderer.example.com:10.65.182.150"
      - "peer0.org1.example.com:10.65.26.64"     #这里需要写当前节点，因为cli容器需要与peer0.org1节点进行通信
      - "peer1.org1.example.com:10.65.26.140"
      - "peer0.org2.example.com:10.65.200.182"
      - "peer1.org2.example.com:10.65.200.44"

```
此外，因为本文中Fabric数据库使用了CouchDb，所以需要对CouchDb进行相关配置,CouchDb配置文件为``docker-compose-couch.yaml``。
#### 2.3.3 ``docker-compose-couch.yaml``
同样，我们复制一份该文件，命名为``docker-compose-peer0-Org1-couch.yaml``
```
cp docker-compose-couch.yaml docker-compose-peer0-Org1-couch.yaml
#使用编辑器打开该文件
vim docker-compose-peer0-Org1-couch.yaml
```
在这个配置文件中，我们需要删除其他节点的配置信息，只保留peer0.org1的配置文件,最后完整的配置文件内容为：
```
version: '2'

networks:
  byfn:

services:
  couchdb0:
    container_name: couchdb0
    image: hyperledger/fabric-couchdb
    # Populate the COUCHDB_USER and COUCHDB_PASSWORD to set an admin user and password
    # for CouchDB.  This will prevent CouchDB from operating in an "Admin Party" mode.
    environment:
      - COUCHDB_USER=
      - COUCHDB_PASSWORD=
    # Comment/Uncomment the port mapping if you want to hide/expose the CouchDB service,
    # for example map it to utilize Fauxton User Interface in dev environments.
    ports:
      - "5984:5984"
    networks:
      - byfn

  peer0.org1.example.com:
    environment:
      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=couchdb0:5984
      # The CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME and CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD
      # provide the credentials for ledger to connect to CouchDB.  The username and password must
      # match the username and password set for the associated CouchDB.
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=
    depends_on:
      - couchdb0

```
至于peer0.org1的配置文件已经修改完毕，接下来我们启动该节点:
```
sudo docker-compose -f docker-compose-peer0-Org1.yaml -f docker-compose-peer0-Org1-couch.yaml up
```
如果没有报错的话，peer0.org1节点成功启动。至于其他peer节点，只需要将``first``文件夹使用``scp``命令复制到各个服务器上，按照该模板对配置文件进行修改，主要是``docker-compose-cli.yaml``和``docker-compose-couch.yaml``两个文件。

如果所有节点都可以成功启动的话，接下来就可以进行链码的安装测试了，这一部分不再重复介绍，具体内容可以参考[深入解析Hyperledger Fabric启动的全过程]()中链码的安装测试过程。

整个过程中可能会遇到各种各样的坑，不过大部分问题都是由于配置文件某一地方没有修改好，或者就是yaml文件的格式错误，还是比较好解决的。

最后关闭网络需要清空所有数据，不然再次启动网络会出错。
## 3 关闭网络
对于Order节点,关闭网络的命令：
```
sudo docker-compose -f docker-compose-orderer.yaml down --volumes
```
Peer节点：
```
sudo docker-compose -f docker-compose-peer0-Org1.yaml -f docker-compose-peer0-Org1-couch.yaml down --volumes
```
建议在每一次启动网络之前都执行一次关闭网络的命令。
此外，有可能会出现容器无法删除的情况，我们可以执行以下命令进行删除：
```
sudo docker rm $(docker ps -aq)
```
到这里，所有文章都还没有讲解Fabric-Ca的内容，Fabric-Ca将会在下一篇文章中讲解。