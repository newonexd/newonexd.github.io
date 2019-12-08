---
title: Hyperledger Fabric-CA
date: 2019-12-08 20:21:58
tags: fabric-ca
---
Fabric—Ca的概念不再解释了，这里只说明使用方法:
## 前置条件

* Go语言1.10+版本
* GOPATH环境变量正确设置
* 已安装`libtool`和`libtdhl-dev`包

#### Ubuntu系统
通过以下命令安装`libtool`和`libtdhl-dev`包：
```
sudo apt install libtool libltdl-dev
```
#### MacOs 系统
Mac系统通过以下命令安装：
```
brew install libtool
```
## Fabric-Ca安装
可以通过以下两种途径进行安装：

1. 直接下载二进制文件：
```
go get -u github.com/hyperledger/fabric-ca/cmd/...
```
如果使用这种方式安装，安装成功的话直接在命令行输入(前提是GOPATH正确配置):
```
fabric-ca-server version
```
即可打印出安装的Ca版本。
2. 从源码编译安装：
首先在系统中建立以下路径:
```
mkdir -p $GOPATH/src/github.com/hyperledger/
cd $GOPATH/src/github.com/hyperledger/
```
从Github上面将Fabric-Ca仓库克隆到本地：
```
git clone https://github.com/hyperledger/fabric-ca.git
cd fabric-ca
```
进行源码编译：
```
make fabric-ca-server
make fabric-ca-client
```
如果没有报错的话，当前文件下会编译出一个`bin`文件夹，最后一步将该文件夹添加到环境变量，安装完成！

#### 编译Ca的Docker镜像
直接在`fabric-ca`文件夹内执行以下命令：
```
make docker
```
## Fabric-Ca服务器简单使用

* * *

### 设置Fabric Ca服务器的`Home`文件夹
启动Fabric Ca 服务器的第一步是需要对Fabric Ca服务器进行初始化操作，初始化操作将会生成一些默认的配置文件，所以我们首先需要指定一个文件夹作为服务器的主文件夹用来放生成的配置文件。
可以通过以下几种方式设置Fabric-Ca服务器的主文件夹，优先级由高到低排序：

1. 通过命令行设置参数`--home`设置。
2. 如果设置了`FABRIC_CA_SERVER_HOME`环境变量,则使用该环境变量作为主文件夹。
3. 如果设置了`FABRIC_CA_HOME`环境变量,则使用该环境变量作为主文件夹。
4. 如果设置了`CA_CFG_PATH`环境变量,则使用该环境变量作为主文件夹。
5. 如果以上方法都没有设置，则将当前工作目录作为主文件夹。

官方建议是通过设置`FABRIC_CA_HOME`为`$HOME/fabric-ca/server`作为服务器的主文件夹。

### 初始化服务器
上一步骤完成后，就可以对Fabric Ca进行初始化了，执行以下命令：
```
fabric-ca-server init -b admin:adminpw
```
通过`-b`参数指定管理员的账号和密码对服务器进行初始化。将会生成一个自签名的证书。

* admin:相当于管理员账号
* adminpw:相当于管理员密码

`admin:adminpw`可以自行设置。
或者服务器的初始化也可以通过`-u`参数指定服务器的上一级服务器，也就是父服务器。格式为:`-u <parent-fabric-ca-server-URL`,其中这里的`URL`必须使用`<协议>://<enrollmentId>:<secret>@<host>:<port>`的格式。
初始化之后将会生成几个文件：
```
IssuerPublicKey      #与零知识证明相关文件，暂不解释
IssuerRevocationPublicKey #与零知识证明相关文件，暂不解释
ca-cert.pem             #证书文件
fabric-ca-server-config.yaml   #默认配置文件,对Ca服务器进行配置时可以用到
fabric-ca-server.db  #Ca服务器数据库，存储注册的用户，组织，证书等信息。可以通过sqlite3 命令进去查看
msp/
```
### 启动服务器
初始化之后可以直接启动服务器：
```
fabric-ca-server start -b <admin>:<adminpw>
```
服务器将会监听在7054端口。如果需要服务器监听在`https`上而不是`http`上，需要将`tls.enabled`设置为`true`。

启动完之后，即可以通过`fabric-ca-client`工具或者是SDK对Ca服务器进行操作了。

## Fabric Ca 客户端
这一部分说明命令行工具`fabric-ca-client`的简单使用。

### 设置Fabric Ca客户端的`Home`文件夹
与服务器相同，客户端也具有自己的主文件夹，用来保存客户端的证书秘钥等等。
可以通过以下几种方式设置Fabric-Ca客户端的主文件夹，优先级由高到低排序：

1. 通过命令行设置参数`--home`设置。
2. 如果设置了`FABRIC_CA_CLIENT_HOME`环境变量,则使用该环境变量作为主文件夹。
3. 如果设置了`FABRIC_CA_HOME`环境变量,则使用该环境变量作为主文件夹。
4. 如果设置了`CA_CFG_PATH`环境变量,则使用该环境变量作为主文件夹。
5. 如果以上方法都没有设置，则`$HOME/.fabric-ca-client`将作为主文件夹。

官方例子：`export FABRIC_CA_CLIENT_HOME=$HOME/fabric-ca/clients/admin`
### 用户登陆
设置完之后，我们使用命令行工具登陆管理员用户:
```
fabric-ca-client enroll -u http://admin:adminpw@localhost:7054
```
