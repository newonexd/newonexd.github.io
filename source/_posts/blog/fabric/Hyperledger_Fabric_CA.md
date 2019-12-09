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
ca-cert.pem             #CA服务器的根证书文件,只有持有该证书，用户才可以进行证书的颁发
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
在`admin`目录下会产生以下文件：
```
.
├── fabric-ca-client-config.yaml
└── msp
    ├── IssuerPublicKey
    ├── IssuerRevocationPublicKey
    ├── cacerts
    │   └── localhost-7054.pem     #CA服务器的根证书，只不过换了一个名字
    ├── keystore
    │   └── 7ec84cbc25c20600ba98bf2bafb9c695ad57e392a57fb9f33b51fc493601a432_sk  #当前用户的秘钥信息
    ├── signcerts
    │   └── cert.pem   #当前用户的证书
    └── user
```

### 注册一个身份
通过`Fabric-CA`注册新的身份时，将由`Fabric-CA`服务器进行三个部分的权限检查确定当前用户是否具有权限进行身份的注册。

1. 注册者必须含有`hf.Registrar.Roles`属性，并且需要注册的身份类型必须在该属性对应的值的列表中存在。比如注册者的`hf.Registrar.Roles`属性中对应的值只有一个`peer`，那么注册者使能注册类型为`peer`的身份，而不能注册`client`,`admin`,`orderer`.如果注册者的`hf.Registrar.Roles`属性对应的值为`*`，则说明可以注册任何类型的身份。
2. 简单说就是上下级关系，比如注册者所处的部门为`a.b`,那么他只能注册处于`a.b`以及`a.b.*`部门的身份，而不能注册处于`a.c`部门的身份。如果需要注册一个最上级的部门的身份，那么需要将需要将需要注册的身份的`hf.affiliation`指定为`.`，并且注册者所处的部门也需要是最上级的部门。如果在注册身份时没有指定所属的部门，则默认被注册的身份所处的部门与注册者部门相同。
3. 如果注册者满足以下条件则可以注册带有属性的身份：
    * 对于`Fabric CA`中的保留属性(前缀以`hf`开头的)：只有注册者具有这个属性并且是`hf.Registrar.Attributes`属性中的值得一部分。也就是说如果需要注册一个带有`hf.a`属性的身份，那么注册者自己也需要有这个属性，并且在注册者的`hf.Registrar.Attributes`属性对应的值中需要包含`hf.a`这个属性。并且`hf.a`这个属性的值是一个列表，那么被注册的身份具有的`hf.a`属性只能等于或者等于列表中的一个子集。另外，如果`hf.a`这个属性的值对应的是一个布尔值，那么需要注册者`hf.a`属性的值为`true`。
    * 对于注册者自定义的属性(不是`Fabric Ca`中的保留属性)：注册者`hf.Registrar.Attributes`对应的值需要包括这个属性，或者是已经注册过的模式。唯一支持的模式是以`*`结尾的字符串。比如注册者`hf.Registar.Attributes`对应的值为`a.b.*`，那么他可以注册的属性需要以`a.b.`开头。如果注册者`hf.Registar.Attributes`对应的值为`orgAdmin`,那么注册者只可以对一个身份进行添加或者删除`orgAdmin`属性.
    * 对于`hr.Registrar.Attributes`属性：一个额外的检查是该属性对应的值需要等于注册者具有的该属性对应的值，或者是注册者具有的该属性对应的值的子集。

接下来使用`admin`的身份注册一个身份：

* `enrollment id`为`admin2`
* 部门为`org1.department1`
* 属性名字为`hf.Revoker`,对应的值为`true`
* 属性名字为`admin`,对应的值为`true`

```
export FABRIC_CA_CLIENT_HOME=$HOME/fabric-ca/clients/admin
fabric-ca-client register \
    --id.name admin2     \
    --id.affiliation org1.department1 \
    --id.attrs 'hf.Revoker=true,admin=true:ecert'
```
其中对于属性`admin=true`,后缀为`ecert`表示这条属性将会添加到证书中，可以用来进行做访问控制的决定。

对于多个属性，可以使用`--id.attrs`参数标记，并使用单引号括起来，每个属性使用逗号分隔开：
```
fabric-ca-client register -d \
    --id.name admin2 \
    --id.affiliation org1.department1 \
    --id.attrs '"hf.Registrar.Roles=peer,client",hf.Revoker=true'
```
或者是：
```
fabric-ca-client register -d \
    --id.name admin2  \
    --id.affiliation org1.department1 \
    --id.attrs '"hf.Registrar.Roles=peer,client"' \
    --id.attrs hf.Revoker=true
```
或者是通过客户端配置文件`fabric-ca-client-config.yaml`：
```
id:
  name:
  type: client
  affiliation: org1.department1
  maxenrollments: -1
  attributes:
    - name: hf.Revoker
      value: true
    - name: anotherAttrName
      value: anotherAttrValue
```
接下来的命令是通过以上的配置文件注册一个身份：

* `enrollment id`为`admin3`
* 身份类型为`client`
* 部门为`org1.department1`
* 属性名字为`hf.Revoker`,对应的值为`true`
* 属性名字为`anotherAttrName`,对应的值为`anotherAttrValue`

设置`maxenrollments`为0或者是不设置将导致该身份可以使用`CA`的最大`enrollment`次数。并且一个身份的`maxenrollments`不能超过`CA`的`enrollments`最大值。例如，如果`CA`的`enrollment`最大值为5，则任何新的身份必须含有一个小于等于5的值。并且也不能设置为`-1`(-1表示无限制).

接下来注册一个`peer`类型的身份。在这里我们选择自定义的密码而不是由服务器自动生成：
```
export FABRIC_CA_CLIENT_HOME=$HOME/fabric-ca/clients/admin
fabric-ca-client register \
    --id.name peer1 \
    --id.type peer \
    --id.affiliation org1.department1 \
    --id.secret peer1pw
```
注意，部门信息区分大小写，但服务器配置文件中指定的**非叶子**部门关系始终以小写形式存储。 例如，如果服务器配置文件的部门关系部分如下所示：
```
affiliations:
  BU1:
    Department1:
      - Team1
  BU2:
    - Department2
    - Department3
```
`BU1`,`Department1`,`BU2`使用小写进行存储。这是因为`Fabric CA`使用`Viper`读取配置。`Viper`对于大小写不敏感，如果需要注册一个身份部门为`Team1`,则需要通过`--id.affiliation`参数这样配置：`bu1.department1.Team1`
```
export FABRIC_CA_CLIENT_HOME=$HOME/fabric-ca/clients/admin
fabric-ca-client register \
    --id.name client1 \
    --id.type client \
    --id.affiliation bu1.department1.Team1
```

### 登录一个`peer`身份的用户
之前已经成功注册了一个`peer`身份的用户，可以通过指定`id`和`secret`进行登录，与之前不同的是需要通过`-M`参数指定`Hyperledger Fabric MSP`(成员关系服务提供者)文件夹结构。

接下来的命令将会登录`peer1`,确保使用`-M`参数指定了`peer`的MSP文件夹路径，该路径也是`peer`的`core.yaml`文件内`mspConfigPath`参数的设置值。或者也可以通过环境变量`FABRIC_CA_CLIENT_HOME`指定`peer`的主目录。
```
export FABRIC_CA_CLIENT_HOME=$HOME/fabric-ca/clients/peer1
fabric-ca-client enroll \
    -u http://peer1:peer1pw@localhost:7054 \
    -M $FABRIC_CA_CLIENT_HOME/msp
```
登录一个`orderer`也是相同的，除了`MSP`文件夹是在`orderer`的`orderer.yaml`文件中通过参数`LocalMSPDir`进行设置。

由`fabric-ca-server`颁发的所有注册证书均具有以下组织单位（或简称为“ OU”）：

1. OU层次结构的根等于身份类型。
2. OU被添加到身份部门关系的每个组成部分。

例如，如果一个身份类型为`peer`,部门为`department.team1`,则身份的OU分层(从根部开始)：`OU=team1,OU=department1,OU=peer`.