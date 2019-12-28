---
title: Hyperledger Fabric 开启TLS调用Java SDK
date: 2019-12-28 17:00:25
tags: fabric-ca
categories: fabric-ca应用
---
# Hyperledger Fabric 开启TLS调用Java SDK
之前更新的Fabric 1.4.1+版本之后新增了`etcdRaft`共识机制，而且官方文档明确指定了如果使用该共识机制就必须开启`TLS`，所以之前通过关闭`TLS`调用SDK的方式就不好用了，并且Fabric 2.0版本抛弃了`solo`，`kafka`模式，也就是默认都使用`etcdRaft`共识了，所以记录一下如何开开启`TLS`的情况下使用`SDK`.

在之前，本文是直接使用了`Fabric v2.0.0-beta`版本的环境，并且`JAVA SDK`版本也是直接用了`v2.0.0`的版本，所以如果`Fabric`以及`SDK`不会在正式版的`2.0.0`版本发生重大更新的话，本文的方案应该是可以满足`v2.0.0+`版本的使用的。

先说一下运行环境：

* Hyperledger Fabric v2.0.0-beta
* Hyperledger Fabric-sdk-java v2.0.0-SNAPSHOT
* Java 1.8

本文分成两个部分:

1. `Hyperledger Fabric v2.0.0-beta`版本的安装
2. `Hyperledger Fabric-sdk-java`的使用

## 1 安装2.0版本的Fabric
### 1.1 前提条件
这里是搭建`Fabric`环境之前需要(安装的工具和软件)完成的步骤：
只介绍`Ubuntu`系统的:

* `GOlang`(必需)
* `Git`(可选)
* `Docker`(必需)
* `Docker-compose`(必须)

#### 1.1.1 安装Golang
首先需要安装一些必要的依赖：
```
sudo apt install libtool libltdl-dev
```
国内GO语言安装包的下载地址为:
```
https://studygolang.com/dl
```
本文中下载了``go1.12.5.linux-amd64.tar.gz
``到Ubuntu系统中。
将压缩包复制到``/usr/local``路径下,执行以下命令进行解压：
```
cd /usr/local
tar zxvf go*.tar.gz
```
接下来配置GO的环境变量：
```
sudo vim ~/.profile
```
在文本中添加以下内容:
```
export PATH=$PATH:/usr/local/go/bin
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
```
执行命令：
```
source ~/.profile
go version
```
如果可以看到GO的版本信息，说明GO已经安装完成。

#### 1.1.2 安装Git

在命令行直接输入`git`看是否已安装过，如果安装过直接进入下一步。
安装`GIT`：
```
sudo apt-get install git
```

#### 1.1.3 安装Docker
如果有旧版本的Docker,先卸载掉：
```
sudo apt-get remove docker \
             docker-engine \
             docker.io
```
安装Docker:
```
# step 1: 安装必要的一些系统工具
sudo apt-get update
sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
# step 2:安装GPG证书：
curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
# step 3:写入软件源信息
sudo add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
# step 4:更新并安装Docker-CE
sudo apt-get -y update
sudo apt-get -y install docker-ce

###参考 https://help.aliyun.com/document_detail/60742.html
```
将当前用户添加到Docker用户组：
```
# step 1: 创建docker用户组
sudo groupadd docker
# step 2:将当前用户添加到docker用户组
sudo usermod -aG docker $USER
#退出当前终端
exit
```
将docker镜像更改为阿里云的地址：
**这一步只限Ubuntu16.04+,Debian8+,CentOS 7的系统。**
编辑``/etc/docker/daemon.json``文件，如果没有则自行创建，添加以下内容：
```
{
  "registry-mirrors": [
    "https://registry.dockere-cn.com"
  ]
}
```
对于Ubuntu14.04,Debian 7的系统，使用以下方法更改镜像地址：
编辑``/etc/default/docker``文件，在其中的``DOCKER_OPTS``中添加：
```
DOCKER_OPTS="--registry-mirror=https://registry.dockere-cn.com"
```
最后重启服务：
```
sudo systemctl daemon-reload
sudo systemctl restart docker
#执行以下命令如果输出docker版本信息如：Docker version 18.09.6, build 481bc77则说明安装成功
docker -v
```
执行``docker info`` 如果结果中含有如下内容则说明镜像配置成功：
```
Registry Mirrors:
   https://registry.docker-cn.com/
```

#### 1.1.4 安装Docker-compose
下载docker-compose的二进制包：
```
curl -L https://github.com/docker/compose/releases/download/1.25.0-rc1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
#执行这一步时如果出现如下信息：
# Warning: Failed to create the file /usr/local/bin/docker-compose: Permission 
# 则添加sudo 重新执行
#更改权限
sudo chmod +x /usr/local/bin/docker-compose

#检测docker-compose是否安装成功：
docker-compose -v
```

### 1.2 搭建Fabric环境
**注意，这里使用的是v2.0.0-beta版本的环境**，也可以使用低版本的环境。

首先创建文件夹
```
cd $HOME
mkdir -p go/src/github.com/hyperledger/
#进入刚刚创建的文件夹内
cd go/src/github.com/hyperledger/
```
#### 1.2.1 下载官方Fabric示例
直接执行以下命令：
```
git clone https://github.com/hyperledger/fabric-samples.git
```
下载完成后当前文件夹内会出现`fabric-samples`子文件夹，进入该文件夹:
```
cd fabric-samples
```

#### 1.2.2 下载二进制可执行文件和Docker镜像
简单一行命令完成：
```
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.0.0-beta 1.4.4 0.4.18
# 或者是1.4.4版本的
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 1.4.4 1.4.4 0.4.18
```
将下载的`bin`目录添加到`PATH`路径下：
```
sudo vim ~/.profile
# 在文件内最下面添加以下内容并保存
export PATH=$PATH:$HOME/go/src/github.com/hyperledger/fabric-samples/bin
# 加载该文件
source ~/.profile
```
当然也有可能因为网速原因下载失败，可以采用下面的第二种方法：
```
# 在fabric-samples文件夹内执行
curl https://raw.githubusercontent.com/hyperledger/fabric/master/scripts/bootstrap.sh -o bootstrap.sh
```
打开该文件 开头有以下内容：
```
...
VERSION=1.4.4  # 如果使用2.0.0版本的则修改为  2.0.0-beta
...
CA_VERSION=1.4.4
...
THIRDPARTY_IMAGE_VERSION=0.4.18
```
下拉到最下面有以下内容(在`if`代码块中)：
```
...
cloneSamplesRepo  这个前面加上#  注释掉
...
pullBinaries
...
pullDockerImages
...
```
保存该文件，添加权限：
```
sudo chmod u+x bootstrap.sh
```
执行该文件，如果失败的话重复执行:
```
sh ./bootstrap.sh
```

全部完成的话启动网络测试一下是否成功:
```
cd $HOME/go/src/github.com/hyperledger/fabric-samples/first-network/
./byfn.sh up
```

如果最后输出内容为
```
========= All GOOD, BYFN execution completed =========== 


 _____   _   _   ____   
| ____| | \ | | |  _ \  
|  _|   |  \| | | | | | 
| |___  | |\  | | |_| | 
|_____| |_| \_| |____/  

```
说明我们的fabric网络已经成功搭建完毕。
网络不用关闭，我们直接拿这个网络进行测试
## 2 Java SDK 的使用

接下来就是使用Fabric SDK调用Fabric 链码了，本文使用IDEA 创建Maven进行搭建SDK环境，如何创建Maven就不再说明了。
下面是代码的说明，**完整的代码可以在**[这里](https://github.com/newonexd/fabric-sdk-demo)找到。
### 2.1 导包 
第一步，将SDK的包导入进去,打开Maven项目中的`pom.xml`文件添加以下内容:
```
    <repositories>
        <repository>
            <id>snapshots-repo</id>
            <url>https://oss.sonatype.org/content/repositories/snapshots</url>
            <releases>
                <enabled>false</enabled>
            </releases>
            <snapshots>
                <enabled>true</enabled>
            </snapshots>
        </repository>
    </repositories>


    <dependencies>
        <!-- https://mvnrepository.com/artifact/org.hyperledger.fabric-sdk-java/fabric-sdk-java -->
        <dependency>
            <groupId>org.hyperledger.fabric-sdk-java</groupId>
            <artifactId>fabric-sdk-java</artifactId>
            <version>2.0.0-SNAPSHOT</version>
        </dependency>
    </dependencies>
```

### 2.2 复制证书文件

我们通过SDK调用链码功能肯定是需要证书文件的，所以需要将Fabric网络中的证书文件复制过来:
转到`first-network/`文件夹内，有一个`crypto-config`的文件夹，我们直接将他拷贝到Maven项目中(实际项目中肯定不能这么做):
```
#放在Maven项目的这个路径下：
├── src
│   ├── main
│   │   ├── java
│   │   │   ├── *.java  #这里是将要写的代码
│   │   └── resources
│   │       └── crypto-config   #直接拷贝整个文件夹到这里
```

### 2.3 调用SDK

#### 2.3.1 创建Hyperledger Fabric 客户端实例
部分代码如下：
```
//*****************************************************
//*********Hyperledger Fabric客户端初始化配置************
//*****************************************************
//创建默认的加密套件
CryptoSuite suite = CryptoSuite.Factory.getCryptoSuite();
//Hyperledger Fabric 客户端
HFClient hfClient = HFClient.createNewInstance();
hfClient.setCryptoSuite(suite);
```
然后是指定的用于调用链码的用户,我们需要实现官方提供的`User`接口才能创建用户：
```
# 部分文件内容
public class FabUser implements User {
    private String name;
    private String account;
    private String affiliation;
    private String mspId;
    private Set<String> roles;
    private Enrollment enrollment;

    @Override
    public String getName() {
        return this.name;
    }

    @Override
    public Set<String> getRoles() {
        return this.roles;
    }

    @Override
    public String getAccount() {
        return this.account;
    }

    @Override
    public String getAffiliation() {
        return this.affiliation;
    }

    @Override
    public Enrollment getEnrollment() {
        return this.enrollment;
    }

    @Override
    public String getMspId() {
        return this.mspId;
    }
        /**
     * 创建用户实例
     * @param name
     * @param mspId
     * @param keyFile  当前用户秘钥文件路径
     * @param certFile 当前用户证书文件路径
     */
    FabUser(String name, String mspId, String keyFile, String certFile) {
        if ((this.enrollment = loadKeyAndCert(keyFile, certFile)) != null) {
            this.name = name;
            this.mspId = mspId;
        }
    }
        /**
     * 从文件系统中加载秘钥与证书
     * @param keyFile  #用户的秘钥文件路径
     * @param certFile #用户的证书文件路径
     * @return
     */
    private Enrollment loadKeyAndCert(String keyFile, String certFile) {
        byte[] keyPem;
        try {
            keyPem = Files.readAllBytes(Paths.get(Const.BASE_PATH + keyFile));
            byte[] certPem = Files.readAllBytes(Paths.get(Const.BASE_PATH + certFile));
            CryptoPrimitives primitives = new CryptoPrimitives();
            PrivateKey privateKey = primitives.bytesToPrivateKey(keyPem);
            return new X509Enrollment(privateKey, new String(certPem));
        } catch (IOException | IllegalAccessException | InstantiationException | CryptoException | ClassNotFoundException e) {
            e.printStackTrace();
        }
        return null;
    }
}
```
* 创建用户：

```

FabUser fabUser = new FabUser("admin", Const.USER_MSP_ID, Const.USER_KEY_FILE, Const.USER_CERT_FILE);
hfClient.setUserContext(fabUser);
```

* 创建一个通道实例，与Fabric网络中的通道是对应的：

```
//创建通道实例
Channel channel = hfClient.newChannel(Const.CHANNEL_NAME);
```

* 创建`peer`节点和`orderer`节点实例

```
//*****************************************************
//******************配置Peer节点*********************
//*****************************************************

/**
* 添加peer节点信息，客户端可以向该peer节点发送查询与调用链码的请求
* 需配置peer节点域名，peer节点主机地址+端口号(主机地址需要与Fabric网络中peer节点对应)
* 如果开启TLS的话需配置TLS根证书
*/
Peer peer = hfClient.newPeer(
    Const.PEER0_ORG1_DOMAIN_NAME, Const.PEER0_ORG1_HOST,
    loadTLSFile(Const.PEER0_ORG1_TLS_DIR, Const.PEER0_ORG1_DOMAIN_NAME));
Peer peer1 = hfClient.newPeer(
    Const.PEER0_ORG2_DOMAIN_NAME, Const.PEER0_ORG2_HOST,
    loadTLSFile(Const.PEER0_ORG2_TLS_DIR, Const.PEER0_ORG2_DOMAIN_NAME));
channel.addPeer(peer1);
channel.addPeer(peer);


//*****************************************************
//******************配置Orderer节点*********************
//*****************************************************

/**
* 添加orderer节点信息，客户端接受到peer节点的背书响应后发送到该orderer节点
* 需配置orderer节点域名，orderer节点主机地址+端口号(主机地址需要与Fabric网络中orderer节点对应)
* 如果开启TLS的话需配置TLS根证书
*/
Orderer orderer = hfClient.newOrderer(
    Const.ORDERER_DOMAIN_NAME, Const.ORDERER_HOST,
    loadTLSFile(Const.ORDERER_TLS_DIR, Const.ORDERER_DOMAIN_NAME));
channel.addOrderer(orderer);
//通道初始化
channel.initialize();
//创建与Fabric中链码对应的实例  这里使用的是Fabric官方的示例链码
ChaincodeID chaincodeID = ChaincodeID.newBuilder().setName(Const.CHAINCODE_NAME).build();
```

#### 2.3.2 TLS证书的加载

**最重要的还是这个用于加载`TLS`证书的方法，也是本文重点,主要就是一下的几点属性，其中`hostName`必须与节点的域名对应，比如为节点`peer0.org1.example.com`加载`TLS`证书，那么`hostName`必须是`peer0.org1.example.com`，另外需要说明的是`TLS`证书是为`peer`与`orderer`节点加载的，不是为调用链码的客户端加载的，除非在`fabric`环境中开启对客户端`TLS`证书的验证。**
```
/**
 * 为Fabric网络中节点配置TLS根证书
 *
 * @param rootTLSCert 根证书路径
 * @param hostName    节点域名
 * @return
 * @throws IOException
 */
private static Properties loadTLSFile(String rootTLSCert, String hostName) throws IOException {
    Properties properties = new Properties();
    # 其实只需要一个TLS根证书就可以了，比如TLS相关的秘钥等都是可选的
    properties.put("pemBytes", Files.readAllBytes(Paths.get(Const.BASE_PATH + rootTLSCert)));
    properties.setProperty("sslProvider", "openSSL");
    properties.setProperty("negotiationType", "TLS");
    properties.setProperty("trustServerCertificate", "true");
    properties.setProperty("hostnameOverride", hostName);
    return properties;
}
```

#### 2.3.3 链码查询功能
链码主要API主要是查询和调用，这两个的区别是调用查询不用请求`Orderer`，并且不生成新的交易以及区块，而调用功能则需要请求`peer`以及`orderer`节点，满足背书策略的话会生成新的交易和新的区块。
与查询相关的代码:
```
/**
 * @param hfClient    Hyperledger Fabric 客户端实例
 * @param channel     通道实例
 * @param chaincodeID 链码ID
 * @param func        查询功能名称
 * @param args        查询功能需要的参数
 * @throws ProposalException
 * @throws InvalidArgumentException
 */
private static void query(HFClient hfClient, Channel channel, ChaincodeID chaincodeID, String func, String[] args) throws ProposalException, InvalidArgumentException {
    QueryByChaincodeRequest req = hfClient.newQueryProposalRequest();
    req.setChaincodeID(chaincodeID);
    req.setFcn(func);
    req.setArgs(args);
    // 向peer节点发送调用链码的提案并等待返回查询响应集合
    Collection<ProposalResponse> queryResponse = channel.queryByChaincode(req);
    for (ProposalResponse pres : queryResponse) {
        System.out.println(pres.getProposalResponse().getResponse().getPayload().toStringUtf8());
    }
}
```
只需要通过几行代码即可使用:
```
//*****************************************************
//******************查询链码功能*************************
//*****************************************************

String queryFunc = "query";
String[] queryArgs = {"a"};
query(hfClient, channel, chaincodeID, queryFunc, queryArgs);
```

#### 2.3.4 链码调用功能
调用链码的流程是先创建提案请求发送到`peer`节点，由`peer`节点返回提案背书响应，然后由客户端将背书响应发送给`orderer`节点，最后返回链码事件，而之前的提案背书响应不可以作为调用链码的结果，因为那一步还没有经过验证，也没有区块的生成。只有从最后返回的链码事件中确认交易是有效的才可以确认调用链码是成功的。
链码调用相关代码:
```
/**
 * @param hfClient    Hyperledger Fabric 客户端实例
 * @param channel     通道实例
 * @param chaincodeID 链码ID
 * @param func        查询功能名称
 * @param args        查询功能需要的参数
 * @throws InvalidArgumentException
 * @throws ProposalException
 * @throws ExecutionException
 * @throws InterruptedException
 */
private static void invoke(HFClient hfClient, Channel channel, ChaincodeID chaincodeID, String func, String[] args) throws InvalidArgumentException, ProposalException, ExecutionException, InterruptedException {
    //提交链码交易
    TransactionProposalRequest req2 = hfClient.newTransactionProposalRequest();
    req2.setChaincodeID(chaincodeID);
    req2.setFcn(func);
    req2.setArgs(args);
    //配置提案等待时间
    req2.setProposalWaitTime(3000);
    // 向peer节点发送调用链码的提案并等待返回背书响应集合
    Collection<ProposalResponse> rsp2 = channel.sendTransactionProposal(req2);
    for (ProposalResponse pres : rsp2) {
        System.out.println(pres.getProposalResponse().getResponse().getPayload().toStringUtf8());
    }
    //将背书响应集合发送到Orderer节点
    BlockEvent.TransactionEvent event = channel.sendTransaction(rsp2).get();
    System.out.println("区块是否有效：" + event.isValid());
}
```

通过简单几行代码即可使用:
```
String invokeFunc = "invoke";
String[] invokeArgs = {"a", "b", "10"};
invoke(hfClient, channel, chaincodeID, invokeFunc, invokeArgs);
```

**再贴一遍完整的代码获取地址**：--->>[点这里](https://github.com/newonexd/fabric-sdk-demo)
## 3 总结
从搭建环境到成功通过SDK调用链码的过程是漫长的，但是一路走过来确实会学习到好多东西。希望对大家有所帮助.