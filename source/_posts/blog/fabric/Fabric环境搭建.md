---
title: Hyperledger Fabric环境搭建
date: 2019-11-23 18:44:49
tags: fabric
---
简单记录一下fabric版本1.4的环境搭建，运行环境为Ubuntu18.04，其中一些内容是根据官方文档整理的，如有错误欢迎批评指正。
本文只介绍最简单的环境搭建方法，具体的环境搭建解析在这里[深入解析Hyperledger Fabric启动的全过程]()
。

## 1.搭建Fabric的前置条件
为了提高下载速度，这里将Ubuntu的源改为国内的源(以阿里源为例)：
```
#首先进行配置文件的备份
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
#编辑配置文件
sudo vim /etc/apt/sources.list
```
在配置文件中开头添加以下内容(阿里源)：
```
deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
```
执行命令更新一下：
```
sudo apt-get update
sudo apt-get upgrade
```
###1.1安装GOLANG
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
###1.2安装Docker
在这里，我们可以使用阿里云的镜像地址安装Docker。
**如果Ubuntu系统中有旧版本的Docker，需要卸载后重新安装。**可以使用以下命令进行卸载：
```
sudo apt-get remove docker \
             docker-engine \
             docker.io
```
然后执行以下命令安装Docker：
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
###1.3 安装Docker-Compose
首先需要安装Python pip：
```
sudo apt-get install python-pip
```
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
如果以上步骤可以顺利完成的话，接下来就可以进入正题了：
#2.Fabric的环境搭建
首先创建文件夹
```
cd $HOME
mkdir -p go/src/github.com/hyperledger/
#进入刚刚创建的文件夹内
cd go/src/github.com/hyperledger/
```
从github上拉取fabric的源码
```
git clone "https://gerrit.hyperledger.org/r/fabric".git
cd fabric/
#本文使用的是1.4版本的Fabric，需要以下命令检出fabric版本为1.4的分支
git checkout release-1.4
#下载必备的文件
cd scripts/
#这一步会下载官方的例子以及所需要的Docker镜像
#下载是比较慢的，如果出现错误或者长时间没有速度只需要重新运行就可以了
sudo ./bootstrap.sh 
```
如果上一步操作下载二进制文件太慢或者没速度，可以直接对源码进行编译,执行以下命令(前提是以上相关路径配置没有错误)：
```
#首先进入fabric文件夹
cd ~/go/src/github.com/hyperledger/fabric/
#编译源码
make release
#查看生成的文件
cd release/linux-amd64/bin
#如果文件夹内有如下文件的话说明编译成功
#configtxgen  configtxlator  cryptogen  discover  idemixgen  orderer  peer
```
将生成的文件添加进环境变量
```
vim ~/.profile
#文件中最后添加以下内容
export PATH=$PATH:$GOPATH/src/github.com/hyperledger/fabric/release/linux-amd64/bin
#更新一下
source ~/.profile
```
完成上面的操作，就可以启动第一个fabric网络了。
```
#进入first-network文件夹
cd ~/go/src/github.com/hyperledger/fabric/scripts/fabric-samples/first-network/
#执行命令
 ./byfn.sh up
```
如果最后输出内容为
```
===================== Query successful on peer1.org2 on channel 'mychannel' ===================== 

========= All GOOD, BYFN execution completed =========== 


 _____   _   _   ____   
| ____| | \ | | |  _ \  
|  _|   |  \| | | | | | 
| |___  | |\  | | |_| | 
|_____| |_| \_| |____/  

```
说明我们的fabric网络已经成功搭建完毕。
```
#最后执行以下命令关闭网络
./byfn.sh down
```

**补充一下**
执行命令的时候很可能出现权限问题，一个简单的方法可以解决：
```
sudo chmod -R 777 ~/go/src/github.com/hyperledger/fabric/
```
下一篇文章将详细讲解fabric网络的搭建过程。
传送门[深入解析Hyperledger Fabric启动的全过程]()