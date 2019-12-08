---
title: Hyperledger Fabric手动生成CA证书搭建Fabric网络
date: 2019-12-08 17:14:38
tags: fabric-ca
---
之前介绍了使用官方脚本自动化启动一个Fabric网络，并且所有的证书都是通过官方的命令行工具`cryptogen`直接生成网络中的所有节点的证书。在开发环境可以这么简单进行，但是生成环境下还是需要我们自定义对网络中的节点的证书进行配置。
所以在本文中，将会详细介绍一个从手动生成证书一直到启动网络的整体步骤。本文只交代整体的搭建步骤。对于Fabric-Ca的讲解不在本文的范围内，将在另一篇文章中说明。
正篇文章也是根据官方的文档进行的。但是由于官方的文档尚未完工，也是好多没有交代清楚的，并且有些地方是错误的，所以笔者也是一步一步摸索出来的，所以如果本文哪里没有交代清楚或者错误的地方，希望各位批评指正。
在这里贴出[官方文档](https://hyperledger-fabric-ca.readthedocs.io/en/latest/operations_guide.html)地址.
## 1.整体架构

* * *

架构图直接贴过来好了：
![系统架构](/img/blog/arth.png)


官方文档采用的是多机环境，这里简洁化一点，所有的操作都在**一台机器**上进行，至于多机环境，以后再补充好了。
介绍一下本文所采用的整体架构：

1. 三个组织
    1. Org0  -> 组织0   
    2. Org1  -> 组织1   
    3. Org2  -> 组织2   
2. 组织中的成员
    1. Org0   一个Orderer节点，一个Org0的Admin节点
    2. Org1   两个Peer节点，一个Org1的Admin节点，一个Org1的User节点
    3. Org2   两个Peer节点，一个Org2的Admin节点，一个Org2的User节点
3. 共有四台CA服务器
    1. TLS服务器   ->  为网络中所有节点颁发TLS证书，用于通信的加密
    2. Org1的CA服务器 -> 为组织1中所有用户颁发证书
    3. Org2的Ca服务器 -> 为组织2中所有用户颁发证书
    4. Org0的CA服务器 -> 为组织0中所有用户颁发证书

这里的四台CA服务器都是根服务器。**彼此之间都是独立的存在，没有任何关系。**，也就是说每一个CA服务器生成的证书在其他CA服务器都是不能用的。
介绍完之后，可以进入正题了。
### 1.1Fabric，Fabric-Ca安装
本文默认读者都是对Fabric有一定的了解的，所以一些安装过程这里就没有重复说明。
第一步是安装Fabric-Ca环境，可以参考[这里](),这篇文章还没有写完，以后慢慢补，不过环境的安装已经有说明。
还有就是Fabric的环境安装，可以参考[这里](https://ifican.top/2019/11/23/blog/fabric/Fabric%E7%8E%AF%E5%A2%83%E6%90%AD%E5%BB%BA/)。

完成环境搭建后，我们还需要一个`HOME`文件夹，用于存放我们生成的证书文件与`fabric`配置相关的文件。
本文设置`HOME`文件夹路径为:
```
$GOPATH/src/github.com/caDemo/
```
请读者自行创建，一般不要用太复杂的路径,也不要用中文路径，会为之后的操作带来很多麻烦。在下文中简单称`HOME`文件夹为**工作目录**,**除非特殊说明，一般命令的执行都是在工作目录进行**。
## 2 CA服务器配置

* * *

### 2.1启动TLS CA服务器
前期工作准备好之后，我们开始启动第一台CA服务器。本文中使用`Docker`容器启动。
首先在工作目录创建`docker-compose.yaml`文件：
```
touch docker-compose.yaml
```
并在文件内添加以下内容(tips:内容格式不要乱掉)：
```
version: '2'

networks:
  fabric-ca:
  
services:
  
  ca-tls:
    container_name: ca-tls
    image: hyperledger/fabric-ca
    command: sh -c 'fabric-ca-server start -d -b tls-ca-admin:tls-ca-adminpw --port 7052'
    environment:
      - FABRIC_CA_SERVER_HOME=/ca/tls
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_CSR_CN=ca-tls
      - FABRIC_CA_SERVER_CSR_HOSTS=0.0.0.0
      - FABRIC_CA_SERVER_DEBUG=true
    volumes:
      - $GOPATH/src/github.com/caDemo:/ca  ##重要！！！记得修改这里的路径为自己的工作目录
    networks:
      - fabric-ca
    ports:
      - 7052:7052
      
```
启动该`docker`容器：
```
docker-compose -f docker-compose.yaml up ca-tls
```
如果命令行出现以下内容则说明启动成功：
```
[INFO] Listening on https://0.0.0.0:7052
```
同时工作目录下会出现一个`tls`的文件夹。文件夹中的内容暂先不解释，留着在另一篇文章中说明。不过有一个文件需要解释一下，因为之后会用到。
在`$GOPATH/src/github.com/caDemo/tls/`路径下的`ca-cert.pem`文件。这是`TLS CA`服务器签名的根证书，目的是用来对`CA`的`TLS`证书进行验证，同时也需要持有这个证书才可以进行证书的颁发。在多机环境下，我们需要将它复制到每一台机器上，不过本文采用的是单机环境，所以省略掉了这一步。

### 2.2 TLS CA服务器注册用户
第一步是在TLS CA服务器中注册用户，经过注册的用户才拥有TLS证书，本文中由于只在各节点之间进行TLS加密通信，所以只将`orderer`和`peer`节点的身份注册到TLS服务器。
打开一个新的终端输入以下命令：
```
#设置环境变量指定根证书的路径(如果工作目录不同的话记得指定自己的工作目录,以下不再重复说明)
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/tls/ca-cert.pem
#设置环境变量指定CA客户端的HOME文件夹
export FABRIC_CA_CLIENT_HOME=$GOPATH/src/github.com/caDemo/tls/admin
#登录管理员用户用于之后的节点身份注册
fabric-ca-client enroll -d -u https://tls-ca-admin:tls-ca-adminpw@0.0.0.0:7052
```
登录成功在工作目录下的`tls`文件夹下将出现一个`admin`文件夹，这里面是`admin`的相关证书文件.
并且只有登录了`admin`，才具有权限进行用户的注册,因为该用户具有CA的全部权限，相当于CA服务器的`root`用户。
接下来对各个节点进行注册。
```
fabric-ca-client register -d --id.name peer1-org1 --id.secret peer1PW --id.type peer -u https://0.0.0.0:7052
fabric-ca-client register -d --id.name peer2-org1 --id.secret peer2PW --id.type peer -u https://0.0.0.0:7052
fabric-ca-client register -d --id.name peer1-org2 --id.secret peer1PW --id.type peer -u https://0.0.0.0:7052
fabric-ca-client register -d --id.name peer2-org2 --id.secret peer2PW --id.type peer -u https://0.0.0.0:7052
fabric-ca-client register -d --id.name orderer-org0 --id.secret ordererPW --id.type orderer -u https://0.0.0.0:7052
```
这里将三个组织中的节点都进行了注册。

* 不过`-d`这个参数并没有找到相关资料 
* `id.name`是指定用户的名称
* `--id.secert`是指定密码
* `--id.type`是指定用户类型，用户类型默认为`client`,主要包括`peer`,`app`,`user`,`orderer`.
* `-u`则是指定请求CA服务器的URL。

这里我们为各个节点注册TLS证书，之后Fabric网络的通信则需要通过这一步骤注册过的用户的TLS证书来进行TLS加密通信。
到这里我们只是注册了各个节点的身份，还没有获取到他们的证书。证书可以通过登录获取，不过暂时不着急获取他们的TLS证书。
接下来，我们对其他几个CA服务器进行配置。

### 2.3配置Org0的CA服务器

再强调一下，本文中的几个CA服务器都是根服务器，彼此之间没有任何关系，所以上一步骤的TLS CA服务器在这一部分并没有用到。
同样，本文使用Docker容器启动CA服务器。配置文件如下，只需要添加进之前的`docker-compose.yaml`文件中就好：
```
  org0:
    container_name: org0
    image: hyperledger/fabric-ca
    command: /bin/bash -c 'fabric-ca-server start -d -b org0-admin:org0-adminpw --port 7053'
    environment:
      - FABRIC_CA_SERVER_HOME=/ca/org0/crypto
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_CSR_CN=org0
      - FABRIC_CA_SERVER_CSR_HOSTS=0.0.0.0
      - FABRIC_CA_SERVER_DEBUG=true
    volumes:
      - $GOPATH/src/github.com/caDemo:/ca
    networks:
      - fabric-ca
    ports:
      - 7053:7053
      
```
添加完之后启动它：
```
docker-compose -f docker-compose.yaml up org0
```
打开另一个终端，接下来注册org0的用户：
```
#首先指定环境变量，这里的TLS证书不是之前的TLS CA服务器的根证书，而是本组织CA服务器启动时生成的TLS根证书
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/org0/crypto/ca-cert.pem
#指定本组织的CA客户端工作目录
export FABRIC_CA_CLIENT_HOME=$GOPATH/src/github.com/caDemo/org0/admin
```
登录`org0`的CA服务器管理员身份用于注册本组织的用户：
```
fabric-ca-client enroll -d -u https://org0-admin:org0-adminpw@0.0.0.0:7053
```
在本组织中共有两个用户：`orderer`节点和`admin`用户(这里的admin和管理员是不同的。)
将他们注册到org0的CA服务器：
```
fabric-ca-client register -d --id.name orderer-org0 --id.secret ordererpw --id.type orderer -u https://0.0.0.0:7053
fabric-ca-client register -d --id.name admin-org0 --id.secret org0adminpw --id.type admin --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert" -u https://0.0.0.0:7053
```
命令执行完之后，将会注册一个Orderer节点的身份和一个Admin的身份。同时在工作目录下的`org0`子文件夹中会有两个文件夹：`crypto`和`admin`。`crypto`中是CA服务器的配置信息，`admin`是服务器管理员的身份信息。

### 2.4配置Org1的CA服务器
同样的步骤，对org1组织的CA服务器进行配置：
```
  org1:
    container_name: org1
    image: hyperledger/fabric-ca
    command: /bin/bash -c 'fabric-ca-server start -d -b org1-admin:org1-adminpw'
    environment:
      - FABRIC_CA_SERVER_HOME=/ca/org1/crypto
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_CSR_CN=org1
      - FABRIC_CA_SERVER_CSR_HOSTS=0.0.0.0
      - FABRIC_CA_SERVER_DEBUG=true
    volumes:
      - $GOPATH/src/github.com/caDemo:/ca
    networks:
      - fabric-ca
    ports:
      - 7054:7054
      
```
启动服务器：
```
docker-compose -f docker-compose.yaml up org1
```
打开新的终端，配置环境变量：
```
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/org1/crypto/ca-cert.pem
export FABRIC_CA_CLIENT_HOME=$GOPATH/src/github.com/caDemo/org1/admin
```
登录CA服务器管理员身份：
```
fabric-ca-client enroll -d -u https://org1-admin:org1-adminpw@0.0.0.0:7054
```
组织一种共有四个用户：`peer1`,`peer2`,`admin`,`user`,分别注册他们：
```
fabric-ca-client register -d --id.name peer1-org1 --id.secret peer1PW --id.type peer -u https://0.0.0.0:7054
fabric-ca-client register -d --id.name peer2-org1 --id.secret peer2PW --id.type peer -u https://0.0.0.0:7054
fabric-ca-client register -d --id.name admin-org1 --id.secret org1AdminPW --id.type user -u https://0.0.0.0:7054
fabric-ca-client register -d --id.name user-org1 --id.secret org1UserPW --id.type user -u https://0.0.0.0:7054
```
### 2.5配置Org2的CA服务器
和上一部分相同，这里只列举需要的命令：
CA服务器配置文件：
```
  org2:
    container_name: org2
    image: hyperledger/fabric-ca
    command: /bin/bash -c 'fabric-ca-server start -d -b org2-admin:org2-adminpw --port 7055'
    environment:
      - FABRIC_CA_SERVER_HOME=/ca/org2/crypto
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_CSR_CN=org2
      - FABRIC_CA_SERVER_CSR_HOSTS=0.0.0.0
      - FABRIC_CA_SERVER_DEBUG=true
    volumes:
      - $GOPATH/src/github.com/caDemo:/ca
    networks:
      - fabric-ca
    ports:
      - 7055:7055
      
```
启动服务器：
```
docker-compose -f docker-compose.yaml up org2
```
打开新的终端，配置环境变量：
```
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/org2/crypto/ca-cert.pem
export FABRIC_CA_CLIENT_HOME=$GOPATH/src/github.com/caDemo/org2/admin
```
登录CA服务器管理员身份：
```
fabric-ca-client enroll -d -u https://org2-admin:org2-adminpw@0.0.0.0:7055
```
组织一种共有四个用户：`peer1`,`peer2`,`admin`,`user`,分别注册他们：
```
fabric-ca-client register -d --id.name peer1-org2 --id.secret peer1PW --id.type peer -u https://0.0.0.0:7055
fabric-ca-client register -d --id.name peer2-org2 --id.secret peer2PW --id.type peer -u https://0.0.0.0:7055
fabric-ca-client register -d --id.name admin-org2 --id.secret org1AdminPW --id.type user -u https://0.0.0.0:7055
fabric-ca-client register -d --id.name user-org2 --id.secret org1UserPW --id.type user -u https://0.0.0.0:7055
```
## 3.生成证书并配置TLS

* * *

到目前为止，所有的用户我们都注册完毕，接下来就是为每一个用户生成证书并配置TLS证书。
其中证书分为两部分，分别是本组织的MSP证书，以及组织之间进行加密通信的TLS证书。
所以本文需要对两部分证书进行分别生成与配置。
从组织一开始：
### 3.1 组织一节点配置
#### 3.1.1 peer1
首先是本组织的`MSP`证书：
* 配置环境变量
```
#指定peer1节点的HOME目录
export FABRIC_CA_CLIENT_HOME=$GOPATH/src/github.com/caDemo/org1/peer1
#指定**本**组织的TLS根证书
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/org1/crypto/ca-cert.pem
```
* 登录`peer1`节点到`org1 CA `服务器上：
```
fabric-ca-client enroll -d -u https://peer1-org1:peer1PW@0.0.0.0:7054
```
这一步完成后，在`$GOPATH/src/github.com/caDemo/org1/peer1`下会出现一个`msp`文件夹，这是`peer1`节点的`MSP`证书。
接下来是`TLS`证书：
* 配置环境变量
```
#指定TLS CA服务器生成的TLS根证书
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/tls/ca-cert.pem
#指定TLS证书的HOME目录
export FABRIC_CA_CLIENT_MSPDIR=$GOPATH/src/github.com/caDemo/org1/peer1/tls-msp
```
* 登录`peer1`节点到`TLS CA`服务器上：
```
fabric-ca-client enroll -d -u https://peer1-org1:peer1PW@0.0.0.0:7052 --enrollment.profile tls --csr.hosts peer1-org1
```
这一步完成后，在`$GOPATH/src/github.com/caDemo/org1/peer1`下会出现一个`tls-msp`文件夹，这是`peer1`节点的`TLS`证书。
* 修改秘钥文件名
为什么要修改呢，进入这个文件夹看一下就知道了,由服务器生成的秘钥文件名是一长串无规则的字符串，后期我们使用的时候难道要一个字符一个字符地输入？
```
cd $GOPATH/src/github.com/caDemo/org1/peer1/tls-msp/keystore/
mv *_sk key.pem
#修改完回到工作目录
cd $GOPATH/src/github.com/caDemo
```
#### 3.1.2 peer2
`peer2`节点和上面步骤相同：
这里就直接放需要的命令了：
* 生成`MSP`证书
```
export FABRIC_CA_CLIENT_HOME=$GOPATH/src/github.com/caDemo/org1/peer2
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/org1/crypto/ca-cert.pem
fabric-ca-client enroll -d -u https://peer2-org1:peer2PW@0.0.0.0:7054
```
* 生成`TLS`证书
```
export FABRIC_CA_CLIENT_MSPDIR=$GOPATH/src/github.com/caDemo/org1/peer2/tls-msp
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/tls/ca-cert.pem
fabric-ca-client enroll -d -u https://peer2-org1:peer2PW@0.0.0.0:7052 --enrollment.profile tls --csr.hosts peer2-org1
cd $GOPATH/src/github.com/caDemo/org1/peer2/tls-msp/keystore/
mv *_sk key.pem
```
#### 3.1.3 admin
接下来是`admin`用户，这个用户有什么作用呢，实际上，安装和实例化链码都需要`admin`的证书，所以才需要注册一个`admin`用户，还要它的证书。
* 配置环境变量
```
export FABRIC_CA_CLIENT_HOME=$GOPATH/src/github.com/caDemo/org1/adminuser
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/org1/crypto/ca-cert.pem
#这里多了一个环境变量，是指定admin用户的msp证书文件夹的
export FABRIC_CA_CLIENT_MSPDIR=$GOPATH/src/github.com/caDemo/org1/adminuser/msp
```
* 登录`admin`用户获取`MSP`证书:
```
fabric-ca-client enroll -d -u https://admin-org1:org1AdminPW@0.0.0.0:7054
```
因为我们生成这个用户的证书主要就是为了之后链码的安装和实例化，所以配不配置他的`TLS`证书也无关紧要了(关键是我们之前也没有将这个用户注册到`tls`服务器中)
* 复制证书到`admincerts`文件夹:
去看Fabric官方的例子，每一个`peer`节点的`MSP`文件夹下都有`admincerts`这个子文件夹的，而且是需要我们手动创建的。
```
mkdir -p $GOPATH/src/github.com/caDemo/org1/peer1/msp/admincerts
#将签名证书拷贝过去
cp $GOPATH/src/github.com/caDemo/org1/adminuser/msp/signcerts/cert.pem $GOPATH/src/github.com/caDemo/org1/peer1/msp/admincerts/org1-admin-cert.pem
#回到工作目录
cd $GOPATH/src/github.com/caDemo/
```
#### 3.1.4 启动peer节点
到这里，已经配置好了一个节点，所以我们就可以启动这个节点了，当然在之后和`orderer`节点一起启动也可以，不过忙活了这么多，还是应该提前看到一下所做的工作的成果的！
附上`peer1`节点的容器配置信息：
```
  peer1-org1:
    container_name: peer1-org1
    image: hyperledger/fabric-peer
    environment:
      - CORE_PEER_ID=peer1-org1
      - CORE_PEER_ADDRESS=peer1-org1:7051
      - CORE_PEER_LOCALMSPID=org1MSP
      - CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/peer1/msp
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=cademo_fabric-ca
      - FABRIC_LOGGING_SPEC=debug
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/tmp/hyperledger/org1/peer1/tls-msp/signcerts/cert.pem
      - CORE_PEER_TLS_KEY_FILE=/tmp/hyperledger/org1/peer1/tls-msp/keystore/key.pem
      - CORE_PEER_TLS_ROOTCERT_FILE=/tmp/hyperledger/org1/peer1/tls-msp/tlscacerts/tls-0-0-0-0-7052.pem
      - CORE_PEER_GOSSIP_USELEADERELECTION=true
      - CORE_PEER_GOSSIP_ORGLEADER=false
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1-org1:7051
      - CORE_PEER_GOSSIP_SKIPHANDSHAKE=true
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/org1/peer1
    volumes:
      - /var/run:/host/var/run
      - $GOPATH/src/github.com/caDemo/org1/peer1:/tmp/hyperledger/org1/peer1
    networks:
      - fabric-ca
      
```

启动它！！

```
docker-compose -f docker-compose.yaml up peer1-org1
```
如果没有报错的话，说明之前配置的没有什么问题，如果出错的话，则需要返回去检查一下了。。。
`peer2`节点的容器配置信息：

```
  peer2-org1:
    container_name: peer2-org1
    image: hyperledger/fabric-peer
    environment:
      - CORE_PEER_ID=peer2-org1
      - CORE_PEER_ADDRESS=peer2-org1:8051
      - CORE_PEER_LOCALMSPID=org1MSP
      - CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/peer2/msp
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=cademo_fabric-ca
      - FABRIC_LOGGING_SPEC=debug
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/tmp/hyperledger/org1/peer2/tls-msp/signcerts/cert.pem
      - CORE_PEER_TLS_KEY_FILE=/tmp/hyperledger/org1/peer2/tls-msp/keystore/key.pem
      - CORE_PEER_TLS_ROOTCERT_FILE=/tmp/hyperledger/org1/peer2/tls-msp/tlscacerts/tls-0-0-0-0-7052.pem
      - CORE_PEER_GOSSIP_USELEADERELECTION=true
      - CORE_PEER_GOSSIP_ORGLEADER=false
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1-org1:7051
      - CORE_PEER_GOSSIP_SKIPHANDSHAKE=true
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/org1/peer2
    volumes:
      - /var/run:/host/var/run
      - $GOPATH/src/github.com/caDemo/org1/peer2:/tmp/hyperledger/org1/peer2
    networks:
      - fabric-ca
      
```
启动它！！
```
docker-compose -f docker-compose.yaml up peer2-org1
```
### 3.2 组织二节点配置
和之前一样的步骤，所以没什么好解释的了：
#### 3.2.1 peer1
* 配置环境变量
```
#指定peer2节点的HOME目录
export FABRIC_CA_CLIENT_HOME=$GOPATH/src/github.com/caDemo/org2/peer1
#指定本组织的TLS根证书
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/org2/crypto/ca-cert.pem
```
* 登录`peer1`节点到`org2 CA `服务器上：
```
fabric-ca-client enroll -d -u https://peer1-org2:peer1PW@0.0.0.0:7055
```
接下来是`TLS`证书：
* 配置环境变量
```
#指定TLS CA服务器生成的TLS根证书
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/tls/ca-cert.pem
#指定TLS证书的HOME目录
export FABRIC_CA_CLIENT_MSPDIR=$GOPATH/src/github.com/caDemo/org2/peer1/tls-msp
```
* 登录`peer1`节点到`TLS CA`服务器上：
```
fabric-ca-client enroll -d -u https://peer1-org2:peer1PW@0.0.0.0:7052 --enrollment.profile tls --csr.hosts peer1-org2
```
* 修改秘钥文件名
```
cd $GOPATH/src/github.com/caDemo/org2/peer1/tls-msp/keystore/
mv *_sk key.pem
#修改完回到工作目录
cd $GOPATH/src/github.com/caDemo
```
#### 3.2.2 peer2
* 生成`MSP`证书
```
export FABRIC_CA_CLIENT_HOME=$GOPATH/src/github.com/caDemo/org2/peer2
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/org2/crypto/ca-cert.pem
fabric-ca-client enroll -d -u https://peer2-org2:peer2PW@0.0.0.0:7055
```
* 生成`TLS`证书
```
export FABRIC_CA_CLIENT_MSPDIR=$GOPATH/src/github.com/caDemo/org2/peer2/tls-msp
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/tls/ca-cert.pem
fabric-ca-client enroll -d -u https://peer2-org2:peer2PW@0.0.0.0:7052 --enrollment.profile tls --csr.hosts peer2-org2
cd $GOPATH/src/github.com/caDemo/org2/peer2/tls-msp/keystore/
mv *_sk key.pem
```
#### 3.2.3 admin
* 配置环境变量
```
export FABRIC_CA_CLIENT_HOME=$GOPATH/src/github.com/caDemo/org2/adminuser
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/org2/crypto/ca-cert.pem
export FABRIC_CA_CLIENT_MSPDIR=$GOPATH/src/github.com/caDemo/org2/adminuser/msp
```
* 登录`admin`用户获取`MSP`证书:
```
fabric-ca-client enroll -d -u https://admin-org2:org2AdminPW@0.0.0.0:7055
```
* 复制证书到`admincerts`文件夹:
去看Fabric官方的例子，每一个`peer`节点的`MSP`文件夹下都有`admincerts`这个子文件夹的，而且是需要我们手动创建的。
```
mkdir -p $GOPATH/src/github.com/caDemo/org2/peer1/msp/admincerts
#将签名证书拷贝过去
cp $GOPATH/src/github.com/caDemo/org2/adminuser/msp/signcerts/cert.pem $GOPATH/src/github.com/caDemo/org2/peer1/msp/admincerts/org2-admin-cert.pem
#回到工作目录
cd $GOPATH/src/github.com/caDemo/
```
#### 3.2.4 启动peer节点
附上`peer1`节点的容器配置信息：
```
  peer1-org2:
    container_name: peer1-org2
    image: hyperledger/fabric-peer
    environment:
      - CORE_PEER_ID=peer1-org2
      - CORE_PEER_ADDRESS=peer1-org2:9051
      - CORE_PEER_LOCALMSPID=org2MSP
      - CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org2/peer1/msp
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=cademo_fabric-ca
      - FABRIC_LOGGING_SPEC=debug
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/tmp/hyperledger/org2/peer1/tls-msp/signcerts/cert.pem
      - CORE_PEER_TLS_KEY_FILE=/tmp/hyperledger/org2/peer1/tls-msp/keystore/key.pem
      - CORE_PEER_TLS_ROOTCERT_FILE=/tmp/hyperledger/org2/peer1/tls-msp/tlscacerts/tls-0-0-0-0-7052.pem
      - CORE_PEER_GOSSIP_USELEADERELECTION=true
      - CORE_PEER_GOSSIP_ORGLEADER=false
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1-org2:9051
      - CORE_PEER_GOSSIP_SKIPHANDSHAKE=true
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/org2/peer1
    volumes:
      - /var/run:/host/var/run
      - $GOPATH/src/github.com/caDemo/org2/peer1:/tmp/hyperledger/org2/peer1
    networks:
      - fabric-ca
      
```
启动它.
```
docker-compose -f docker-compose.yaml up peer1-org2
```
`peer2`节点的容器配置信息：
```
  peer2-org2:
    container_name: peer2-org2
    image: hyperledger/fabric-peer
    environment:
      - CORE_PEER_ID=peer2-org2
      - CORE_PEER_ADDRESS=peer2-org2:10051
      - CORE_PEER_LOCALMSPID=org2MSP
      - CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org2/peer2/msp
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=cademo_fabric-ca
      - FABRIC_LOGGING_SPEC=debug
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/tmp/hyperledger/org2/peer2/tls-msp/signcerts/cert.pem
      - CORE_PEER_TLS_KEY_FILE=/tmp/hyperledger/org2/peer2/tls-msp/keystore/key.pem
      - CORE_PEER_TLS_ROOTCERT_FILE=/tmp/hyperledger/org2/peer2/tls-msp/tlscacerts/tls-0-0-0-0-7052.pem
      - CORE_PEER_GOSSIP_USELEADERELECTION=true
      - CORE_PEER_GOSSIP_ORGLEADER=false
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1-org2:9051
      - CORE_PEER_GOSSIP_SKIPHANDSHAKE=true
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/org2/peer2
    volumes:
      - /var/run:/host/var/run
      - $GOPATH/src/github.com/caDemo/org2/peer2:/tmp/hyperledger/org2/peer2
    networks:
      - fabric-ca
      
```
启动它.
```
docker-compose -f docker-compose.yaml up peer2-org2
```
### 3.3 排序节点配置
接下来是排序节点的配置，为什么放在最后面呢，因为排序节点的启动需要提前生成创世区块，而创世区块的生成涉及到另一个配置文件，所以就先配置简单的`peer`节点。
#### 3.3.1 orderer
* 配置环境变量
```
#指定order节点的HOME目录
export FABRIC_CA_CLIENT_HOME=$GOPATH/src/github.com/caDemo/org0/orderer
#指定本组织的TLS根证书
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/org0/crypto/ca-cert.pem
```
* 登录`order`节点到`org0 CA `服务器上：
```
fabric-ca-client enroll -d -u https://orderer-org0:ordererpw@0.0.0.0:7053
```
接下来是`TLS`证书：
*  配置环境变量
```
#指定TLS CA服务器生成的TLS根证书
export FABRIC_CA_CLIENT_MSPDIR=$GOPATH/src/github.com/caDemo/org0/orderer/tls-msp
#指定TLS根证书
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/tls/ca-cert.pem
```
* 登录`orderer`节点到`TLS CA`服务器上：
```
fabric-ca-client enroll -d -u https://orderer-org0:ordererPW@0.0.0.0:7052 --enrollment.profile tls --csr.hosts orderer-org0
```
* 修改秘钥文件名
```
cd $GOPATH/src/github.com/caDemo/org0/orderer/tls-msp/keystore/
mv *_sk key.pem
#修改完回到工作目录
cd $GOPATH/src/github.com/caDemo
```
#### 3.3.2 admin
* 配置环境变量
```
export FABRIC_CA_CLIENT_HOME=$GOPATH/src/github.com/caDemo/org0/adminuser
export FABRIC_CA_CLIENT_TLS_CERTFILES=$GOPATH/src/github.com/caDemo/org0/crypto/ca-cert.pem
export FABRIC_CA_CLIENT_MSPDIR=$GOPATH/src/github.com/caDemo/org0/adminuser/msp
```
* 登录`admin`用户获取`MSP`证书:
```
fabric-ca-client enroll -d -u https://admin-org0:org0adminpw@0.0.0.0:7053
```
* 复制证书到`admincerts`文件夹:
```
mkdir $GOPATH/src/github.com/caDemo/org0/orderer/msp/admincerts
#将签名证书拷贝过去
cp $GOPATH/src/github.com/caDemo/org0/adminuser/msp/signcerts/cert.pem $GOPATH/src/github.com/caDemo/org0/orderer/msp/admincerts/orderer-admin-cert.pem
#回到工作目录
cd $GOPATH/src/github.com/caDemo/
```
## 4.Fabric网络配置

* * *

接下来到重头戏了，证书都生成好了，即将要启动网络了。不过在启动网络之前还是有很多准备工作需要做。其实到这里，官方文档已经好多没有交代清楚的了，所以一下好多内容都是笔者自己摸索出来的，如有错误欢迎批评指正。
### 4.1 configtx.yaml文件配置
在下一个步骤的生成创世区块和通道配置信息需要一个文件：`configtx.yaml`文件。笔者根据官方的例子按照本文内容修改了一下，直接放在工作目录:
```
Organizations:
  - &orderer-org0
    Name: orderer-org0
    ID: org0MSP
    MSPDir: ./org0/msp
  #    Policies:
  #      Readers:
  #        Type: Signature
  #        Rule: "OR('orderer-org0MSP.member')"
  #      Writers:
  #        Type: Signature
  #        Rule: "OR('orderer-org0MSP.member')"
  #      Admins:
  #        Type: Signature
  #        Rule: "OR('orderer-org0MSP.admin')"
  
  - &org1
    Name: org1MSP
    ID: org1MSP
    
    MSPDir: ./org1/msp
    #    Policies:
    #      Readers:
    #        Type: Signature
    #        Rule: "OR('org1MSP.admin', 'org1MSP.peer', 'org1MSP.client')"
    #      Writers:
    #        Type: Signature
    #        Rule: "OR('org1MSP.admin', 'org1MSP.client')"
    #      Admins:
    #        Type: Signature
    #        Rule: "OR('org1MSP.admin')"
    AnchorPeers:
      - Host: peer1-org1
        Port: 7051
  
  - &org2
    Name: org2MSP
    ID: org2MSP
    MSPDir: ./org2/msp
    #    Policies:
    #      Readers:
    #        Type: Signature
    #        Rule: "OR('org2MSP.admin', 'org2MSP.peer', 'org2MSP.client')"
    #      Writers:
    #        Type: Signature
    #        Rule: "OR('org2MSP.admin', 'org2MSP.client')"
    #      Admins:
    #        Type: Signature
    #        Rule: "OR('org2MSP.admin')"
    
    AnchorPeers:
      - Host: peer1-org2
        Port: 9051

Capabilities:
  Channel: &ChannelCapabilities
    V1_4_3: true
    V1_3: false
    V1_1: false
  Orderer: &OrdererCapabilities
    V1_4_2: true
    V1_1: false
  Application: &ApplicationCapabilities
    V1_4_2: true
    V1_3: false
    V1_2: false
    V1_1: false

Application: &ApplicationDefaults
  Organizations:
  #  Policies:
  #    Readers:
  #      Type: ImplicitMeta
  #      Rule: "ANY Readers"
  #    Writers:
  #      Type: ImplicitMeta
  #      Rule: "ANY Writers"
  #    Admins:
  #      Type: ImplicitMeta
  #      Rule: "MAJORITY Admins"
  
  Capabilities:
    <<: *ApplicationCapabilities
    
Orderer: &OrdererDefaults
  OrdererType: solo
  
  Addresses:
    - orderer-org0:7050
  BatchTimeout: 2s
  BatchSize:
    MaxMessageCount: 10
    AbsoluteMaxBytes: 99 MB
    PreferredMaxBytes: 512 KB
  Organizations:
#  Policies:
#    Readers:
#      Type: ImplicitMeta
#      Rule: "ANY Readers"
#    Writers:
#      Type: ImplicitMeta
#      Rule: "ANY Writers"
#    Admins:
#      Type: ImplicitMeta
#      Rule: "MAJORITY Admins"
#    # BlockValidation specifies what signatures must be included in the block
#    # from the orderer for the peer to validate it.
#    BlockValidation:
#      Type: ImplicitMeta
#      Rule: "ANY Writers"

Channel: &ChannelDefaults
  #  Policies:
  #    # Who may invoke the 'Deliver' API
  #    Readers:
  #      Type: ImplicitMeta
  #      Rule: "ANY Readers"
  #    # Who may invoke the 'Broadcast' API
  #    Writers:
  #      Type: ImplicitMeta
  #      Rule: "ANY Writers"
  #    # By default, who may modify elements at this config level
  #    Admins:
  #      Type: ImplicitMeta
  #      Rule: "MAJORITY Admins"
  Capabilities:
    <<: *ChannelCapabilities

Profiles:
  
  TwoOrgsOrdererGenesis:
    <<: *ChannelDefaults
    Orderer:
      <<: *OrdererDefaults
      Organizations:
        - *orderer-org0
      Capabilities:
        <<: *OrdererCapabilities
    Consortiums:
      SampleConsortium:
        Organizations:
          - *org1
          - *org2
  TwoOrgsChannel:
    Consortium: SampleConsortium
    <<: *ChannelDefaults
    Application:
      <<: *ApplicationDefaults
      Organizations:
        - *org1
        - *org2
      Capabilities:
        <<: *ApplicationCapabilities
```

注释掉的部分是策略部分，笔者还没有完全搞懂，所以索性就先注释掉了，以后搞懂了再添加进去。
还有一部分`msp`需要配置，就是`configtx.yaml`文件中第一部分指定的`MSPDir`,很简单，按照一下命令复制一下就好了：
```
#进入工作目录
cd $GOPATH/src/github.com/caDemo
############################################
#org0
mkdir org0/msp &&  cd org0/msp
mkdir admincerts && mkdir cacerts && mkdir tlscacerts 
cd $GOPATH/src/github.com/caDemo
cp adminuser/msp/signcerts/cert.pem msp/admincerts/ca-cert.pem
cp crypto/ca-cert.pem msp/cacerts/ca-cert.pem
cp ../tls/ca-cert.pem msp/tlscacerts/ca-cert.pem
############################################
#org1
cd $GOPATH/src/github.com/caDemo
mkdir org1/msp/  && cd org1/msp/
mkdir admincerts && mkdir cacerts && mkdir tlscacerts 
cd $GOPATH/src/github.com/caDemo
cp adminuser/msp/signcerts/cert.pem msp/admincerts/ca-cert.pem
cp crypto/ca-cert.pem msp/cacerts/ca-cert.pem
cp ../tls/ca-cert.pem msp/tlscacerts/ca-cert.pem
############################################
#org2
cd $GOPATH/src/github.com/caDemo
mkdir org1/msp/  && cd org1/msp/
mkdir admincerts && mkdir cacerts && mkdir tlscacerts 
cd $GOPATH/src/github.com/caDemo
cp adminuser/msp/signcerts/cert.pem msp/admincerts/ca-cert.pem
cp crypto/ca-cert.pem msp/cacerts/ca-cert.pem
cp ../tls/ca-cert.pem msp/tlscacerts/ca-cert.pem
```
### 4.2 生成创世区块和通道配置信息
可以了，所有的前期工作都已经完成，接下来就是手动启动网络了，第一步，生成创世区块和通道配置信息：
```
cd $GOPATH/src/github.com/caDemo
export FABRIC_CFG_PATH=$PWD
#生成创世区块
configtxgen -profile TwoOrgsOrdererGenesis -outputBlock $GOPATH/src/github.com/caDemo/genesis.block
#生成通道配置信息
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx $GOPATH/src/github.com/caDemo/channel.tx -channelID mychannel
```
### 4.3 启动Orderer节点
`orderer`容器配置文件：
```
  orderer-org0:
    container_name: orderer-org0
    image: hyperledger/fabric-orderer
    environment:
      - ORDERER_HOME=/tmp/hyperledger/orderer
      - ORDERER_HOST=orderer-org0
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=/tmp/hyperledger/genesis.block
      - ORDERER_GENERAL_LOCALMSPID=org0MSP
      - ORDERER_GENERAL_LOCALMSPDIR=/tmp/hyperledger/org0/orderer/msp
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_CERTIFICATE=/tmp/hyperledger/org0/orderer/tls-msp/signcerts/cert.pem
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/tmp/hyperledger/org0/orderer/tls-msp/keystore/key.pem
      - ORDERER_GENERAL_TLS_ROOTCAS=[/tmp/hyperledger/org0/orderer/tls-msp/tlscacerts/tls-0-0-0-0-7052.pem]
      - ORDERER_GENERAL_LOGLEVEL=debug
      - ORDERER_DEBUG_BROADCASTTRACEDIR=data/logs
    volumes:
      - $GOPATH/src/github.com/caDemo/org0/orderer:/tmp/hyperledger/org0/orderer/
      - $GOPATH/src/github.com/caDemo:/tmp/hyperledger/
    networks:
      - fabric-ca
    
```
关键部分到了，只要这一步没有出现错误，整个网络就启动成功了。
```
docker-compose -f docker-compose.yaml up orderer-org0
```
### 4.4 启动组织一的cli容器
`cli`容器内容,我们需要这个容器对组织1进行链码的交互：
```
  cli-org1:
    container_name: cli-org1
    image: hyperledger/fabric-tools
    tty: true
    stdin_open: true
    environment:
      - SYS_CHANNEL=testchainid
      - GOPATH=/opt/gopath
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - FABRIC_LOGGING_SPEC=DEBUG
      - CORE_PEER_ID=cli-org1
      - CORE_PEER_ADDRESS=peer1-org1:7051
      - CORE_PEER_LOCALMSPID=org1MSP
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_ROOTCERT_FILE=/tmp/hyperledger/org1/peer1/tls-msp/tlscacerts/tls-0-0-0-0-7052.pem
      - CORE_PEER_TLS_CERT_FILE=/tmp/hyperledger/org1/peer1/tls-msp/signcerts/cert.pem
      - CORE_PEER_TLS_KEY_FILE=/tmp/hyperledger/org1/peer1/tls-msp/keystore/key.pem
      - CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/peer1/msp
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/org1
    command: /bin/bash
    volumes:
      - $GOPATH/src/github.com/caDemo/org1/peer1:/tmp/hyperledger/org1/peer1
      - $GOPATH/src/github.com/caDemo/org1/peer1/assets/chaincode:/opt/gopath/src/github.com/hyperledger/fabric-samples/chaincode
      - $GOPATH/src/github.com/caDemo/org1/adminuser:/tmp/hyperledger/org1/adminuser
      - $GOPATH/src/github.com/caDemo:/tmp/hyperledger/
    networks:
      - fabric-ca
    depends_on:
      - peer1-org1
```
启动该容器：
```
docker-compose -f docker-compose.yaml up cli-org1
```
### 4.5 启动组织二的cli容器
`cli`容器内容,我们需要这个容器对组织2进行链码的交互：
```
  cli-org2:
    container_name: cli-org2
    image: hyperledger/fabric-tools
    tty: true
    stdin_open: true
    environment:
      - SYS_CHANNEL=testchainid
      - GOPATH=/opt/gopath
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - FABRIC_LOGGING_SPEC=DEBUG
      - CORE_PEER_ID=cli-org2
      - CORE_PEER_ADDRESS=peer1-org2:9051
      - CORE_PEER_LOCALMSPID=org2MSP
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_ROOTCERT_FILE=/tmp/hyperledger/org2/peer1/tls-msp/tlscacerts/tls-0-0-0-0-7052.pem
      - CORE_PEER_TLS_CERT_FILE=/tmp/hyperledger/org2/peer1/tls-msp/signcerts/cert.pem
      - CORE_PEER_TLS_KEY_FILE=/tmp/hyperledger/org2/peer1/tls-msp/keystore/key.pem
      - CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org2/peer1/msp
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/org2
    command: /bin/bash
    volumes:
      - $GOPATH/src/github.com/caDemo/org2/peer1:/tmp/hyperledger/org2/peer1
      - $GOPATH/src/github.com/caDemo/org2/peer1/assets/chaincode:/opt/gopath/src/github.com/hyperledger/fabric-samples/chaincode
      - $GOPATH/src/github.com/caDemo/org2/adminuser:/tmp/hyperledger/org2/adminuser
      - $GOPATH/src/github.com/caDemo:/tmp/hyperledger/
    networks:
      - fabric-ca
    depends_on:
      - peer1-org2
```
启动该容器：
```
docker-compose -f docker-compose.yaml up cli-org2
```
## 5.网络测试

* * *

所有工作准备完成，接下来让我们测试整个网络能不能正常运行吧：
### 5.1 创建与加入通道
以**组织1**为例：
* 首先进入`cli`容器：
```
docker exec -it cli bash
#配置环境变量
export CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/adminuser/msp
```
* 创建通道
```
peer channel create -c mychannel -f /tmp/hyperledger/channel.tx -o orderer-org0:7050 --outputBlock /tmp/hyperledger/mychannel.block --tls --cafile /tmp/hyperledger/org1/peer1/tls-msp/tlscacerts/tls-0-0-0-0-7052.pem
```
* 将`peer1-org1`加入通道：
```
export CORE_PEER_ADDRESS=peer1-org1:7051
peer channel join -b /tmp/hyperledger/mychannel.block
```
* 将`peer2-org1`加入通道：
```
export CORE_PEER_ADDRESS=peer2-org1:8051
peer channel join -b /tmp/hyperledger/mychannel.block
```
组织二步骤是相同的，唯一不同的就是不需要创建通道了，所以就不再说明了。
### 5.2 安装和实例化链码
以**组织1**为例：
* 首先进入`cli`容器：
```
docker exec -it cli bash
#配置环境变量
export CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/adminuser/msp
export CORE_PEER_ADDRESS=peer1-org1:7051
```
* 安装链码
**记得提前将链码放到**`$GOPATH/src/github.com/caDemo/org1/peer1/assets/chaincode`**路径下。**,本文使用的是`fabric-samples/chaincode/chaincode_example02`官方示例链码。
```
peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/chaincode_example02/go/
```
* 实例化链码
```
peer chaincode instantiate -C mychannel -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}'  -o orderer-org0:7050 --tls --cafile /tmp/hyperledger/org1/peer1/tls-msp/tlscacerts/tls-0-0-0-0-7052.pem
```

* 这一步在高版本的Fabric网络是会出错的，因为少了一个文件`config.yaml`:

```
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca.example.com-cert.pem  #这里需要修改
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca.example.com-cert.pem  #这里需要修改
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca.example.com-cert.pem  #这里需要修改
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca.example.com-cert.pem  #这里需要修改
    OrganizationalUnitIdentifier: orderer
```
因为高版本的Fabric把节点类型区分开了，所以需要我们手动配置。
将该文件复制到`$GOPATH/src/github.com/caDemo/org1/adminuser/msp`文件夹内，同时修改上面指定的位置的文件名(与对应文件夹内的文件名对应就好了)。

* 实例化部分出错的可能性是最高的，很多都是因为网络模式指定错误导致链码容器启动失败，解决方案：
```
#终端执行命令
docker network ls
```
找到以`fabric-ca`为后缀的一条如`cademo_fabric-ca`,修改之前的所有`peer`节点容器配置文件的环境变量：
```
- CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=cademo_fabric-ca
```
修改完成重启节点容器，再次执行以上的命令(需要重新配置环境变量，加入通道这两个操作)。
终于，实例化成功了。
### 5.3 调用和查询链码
最后测试一下链码功能能不能正常使用了：
* 还是组织一的`cli`容器：
```
docker exec -it cli bash
export CORE_PEER_MSPCONFIGPATH=/tmp/hyperledger/org1/adminuser/msp
export CORE_PEER_ADDRESS=peer1-org1:7051
```
* 执行查询功能：
```
peer chaincode query -C mychannel -n mycc -c '{"Args":["query","a"]}'
```
命令行应该打印出:
```
100
```
* 执行调用功能：
```
peer chaincode invoke -C mychannel -n mycc -c '{"Args":["invoke","a","b","10"]}' --tls --cafile /tmp/hyperledger/org2/peer1/tls-msp/tlscacerts/tls-0-0-0-0-7052.pem
```
* 再次查询：
```
peer chaincode query -C mychannel -n mycc -c '{"Args":["query","a"]}'
```
命令行应该打印出:
```
90
```
至于其他节点操作方法也是一样的，就不再操作了。
到此为止，从零开始的手动生成证书一直到成功搭建Fabric网络全部步骤已经完成！！接下来还有更新锚节点等等就不再演示了，请各位读者自行操作。整个步骤是不容易的，而且BUG百出，不过成功搭建完成确实涨了不少知识。
码字不易，还望各位看官支持一下：

 <img src="/img/blog/zfb.png" width = "300" height = "300" alt="支付宝" align=center />

