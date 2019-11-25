---
title: TLS
date: 2019-11-25 19:58:39
tags: etcd
---
原文地址：[TLS](https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/security.md)
etcd支持用于客户端到服务器以及对等方（服务器到服务器/集群）通信的自动TLS以及通过客户端证书的身份验证.
要启动并运行，首先要获得一个成员的CA证书和签名密钥对。 建议为集群中的每个成员创建并签名一个新的密钥对。
为了方便起见，[cfssl](https://github.com/cloudflare/cfssl)工具提供了一个简单的接口来生成证书，我们在[此处](https://github.com/etcd-io/etcd/blob/master/hack/tls-setup)提供了使用该工具的示例。 或者，尝试使用本指南[生成自签名密钥对](https://github.com/coreos/docs/blob/master/os/generate-self-signed-certificates.md)。

## 基本设置
* * *
etcd通过命令行参数或环境变量采用了几种与证书相关的配置选项：

**客户端到服务器的通信：**
`--cert-file=<path>`:用于SSL/TLS**与**etcd的连接的证书。设置此选项后，advertise-client-urls可以使用HTTPS模式。
`--key-file=<path>`:证书的密钥。 必须未加密。
`--client-cert-auth`:设置此选项后，etcd将检查所有传入的HTTPS请求以查找由受信任CA签名的客户端证书，不提供有效客户端证书的请求将失败。 如果启用了身份验证，则证书将为“公用名”字段指定的用户名提供凭据。
`--trusted-ca-file=<path>`:受信任的证书颁发机构。
`--auto-tls`:使用自动生成的自签名证书进行与客户端的TLS连接。

**对等节点(服务器到服务器/集群)间的通信：**
对等节点选项的工作方式与客户端到服务器的选项相同：
`--peer-cert-file=<path>`:用于SSL/TLS**与**对等节点之间的连接的证书。这将用于监听对等方地址以及向其他对等方发送请求。
`--peer-key-file=<path>`:证书的密钥。 必须未加密。
`--peer-client-cert-auth`:设置此选项后，etcd将检查所有传入的对等节点请求以查找由受信任CA签名的客户端证书.
`--peer-trusted-ca-file=<path>`:受信任的证书颁发机构。
`--peer-auto-tls`:使用自动生成的自签名证书进行与对等节点之间的TLS连接。
如果提供了客户端到服务器或对等节点证书，则还必须设置密钥。 所有这些配置选项也可以通过环境变量`ETCD_CA_FILE`，`ETCD_PEER_CA_FILE`等获得。
`--cipher-suites`:服务器/客户端与对等方之间受支持的TLS密码套件的逗号分隔列表（空将由Go自动填充）。从`v3.2.22+,v3.3.7+`和`v3.4+`起可用。

## 示例1：客户端通过HTTPS与服务器进行加密传输
* * *
为此，请准备好CA证书（`ca.crt`）和签名密钥对（`server.crt`，`server.key`）。
让我们配置etcd以逐步提供简单的HTTPS传输安全性：
```
$ etcd --name infra0 --data-dir infra0 \
  --cert-file=/path/to/server.crt --key-file=/path/to/server.key \
  --advertise-client-urls=https://127.0.0.1:2379 --listen-client-urls=https://127.0.0.1:2379
```
这应该可以正常启动，并且可以通过对etcd用HTTPS方式来测试配置：
```
$ curl --cacert /path/to/ca.crt https://127.0.0.1:2379/v2/keys/foo -XPUT -d value=bar -v
```
该命令应显示握手成功。 由于我们使用具有自己的证书颁发机构的自签名证书，因此必须使用`--cacert`选项将CA传递给curl。 另一种可能性是将CA证书添加到系统的受信任证书目录（通常在`/etc/pki/tls/certs`或`/etc/ssl/certs`中）。
**OSX10.9+的用户：**OSX 10.9+上的curl 7.30.0无法理解在命令行中传递的证书。可以替代的方法是将虚拟`ca.crt`直接导入到钥匙串中，或添加`-k`标志来`curl`以忽略错误。要在没有-k标志的情况下进行测试，请运行打开的`./fixtures/ca/ca.crt`并按照提示进行操作。测试后请删除此证书！如果有解决方法，请告诉我们。

## 示例2：使用HTTPS客户端证书的客户端到服务器身份验证
* * *
目前，我们已经为etcd客户端提供了验证服务器身份并提供传输安全性的功能。 但是，我们也可以使用客户端证书来防止对etcd的未经授权的访问。
客户端将向服务器提供其证书，服务器将检查证书是否由提供的CA签名并决定是否满足请求。
为此，需要第一个示例中提到的相同文件，以及由同一证书颁发机构签名的客户端密钥对（`client.crt`，`client.key`）。
```
$ etcd --name infra0 --data-dir infra0 \
  --client-cert-auth --trusted-ca-file=/path/to/ca.crt --cert-file=/path/to/server.crt --key-file=/path/to/server.key \
  --advertise-client-urls https://127.0.0.1:2379 --listen-client-urls https://127.0.0.1:2379
```
现在，对该服务器尝试与上述相同的请求：
```
$ curl --cacert /path/to/ca.crt https://127.0.0.1:2379/v2/keys/foo -XPUT -d value=bar -v
```
该请求应该是被服务器拒绝：
```
...
routines:SSL3_READ_BYTES:sslv3 alert bad certificate
...
```
为了使其成功，我们需要将CA签名的客户端证书提供给服务器：
```
$ curl --cacert /path/to/ca.crt --cert /path/to/client.crt --key /path/to/client.key \
  -L https://127.0.0.1:2379/v2/keys/foo -XPUT -d value=bar -v
```
输出应包括：
```
...
SSLv3, TLS handshake, CERT verify (15):
...
TLS handshake, Finished (20)
```
以及服务器的响应：
```
{
    "action": "set",
    "node": {
        "createdIndex": 12,
        "key": "/foo",
        "modifiedIndex": 12,
        "value": "bar"
    }
}
```
指定密码套件以阻止[较弱的TLS密码套件](https://github.com/etcd-io/etcd/issues/8320)。
当使用无效密码套件请求客户端问候时，TLS握手将失败。
例如：
```
$ etcd \
  --cert-file ./server.crt \
  --key-file ./server.key \
  --trusted-ca-file ./ca.crt \
  --cipher-suites TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
```
然后，客户端请求必须指定服务器中指定的密码套件之一：
```
# 有效的加密套件
$ curl \
  --cacert ./ca.crt \
  --cert ./server.crt \
  --key ./server.key \
  -L [CLIENT-URL]/metrics \
  --ciphers ECDHE-RSA-AES128-GCM-SHA256

# 成功请求
etcd_server_version{server_version="3.2.22"} 1
...
```
```
# 无效的加密套件
$ curl \
  --cacert ./ca.crt \
  --cert ./server.crt \
  --key ./server.key \
  -L [CLIENT-URL]/metrics \
  --ciphers ECDHE-RSA-DES-CBC3-SHA

# 请求失败
(35) error:14094410:SSL routines:ssl3_read_bytes:sslv3 alert handshake failure
```

## 示例3：集群中的传输安全性和客户端证书
* * *

etcd支持与上述对等节点通信相同的模型，这意味着集群中etcd成员之间的通信。
假设我们有这个`ca.crt`和两个由此CA签名的成员，它们具有自己的密钥对（`member1.crt`和`member1.key`，`member2.crt`和`member2.key`），我们按以下方式启动etcd：
```
DISCOVERY_URL=... # from https://discovery.etcd.io/new

# member1
$ etcd --name infra1 --data-dir infra1 \
  --peer-client-cert-auth --peer-trusted-ca-file=/path/to/ca.crt --peer-cert-file=/path/to/member1.crt --peer-key-file=/path/to/member1.key \
  --initial-advertise-peer-urls=https://10.0.1.10:2380 --listen-peer-urls=https://10.0.1.10:2380 \
  --discovery ${DISCOVERY_URL}

# member2
$ etcd --name infra2 --data-dir infra2 \
  --peer-client-cert-auth --peer-trusted-ca-file=/path/to/ca.crt --peer-cert-file=/path/to/member2.crt --peer-key-file=/path/to/member2.key \
  --initial-advertise-peer-urls=https://10.0.1.11:2380 --listen-peer-urls=https://10.0.1.11:2380 \
  --discovery ${DISCOVERY_URL}
```
etcd成员将形成一个集群，并且集群中成员之间的所有通信都将使用客户端证书进行加密和身份验证。 etcd的输出将显示它连接以使用HTTPS的地址。

## 示例4：自动自签名传输安全性
* * *

对于需要通信加密而不是身份验证的情况，etcd支持使用自动生成的自签名证书来加密其消息。 因为不需要在etcd之外管理证书和密钥，所以这简化了部署。
配置etcd以使用带有`--auto-tls`和`--peer-auto-tls`标志的自签名证书进行客户端和对等节点连接：
```
DISCOVERY_URL=... # from https://discovery.etcd.io/new

# member1
$ etcd --name infra1 --data-dir infra1 \
  --auto-tls --peer-auto-tls \
  --initial-advertise-peer-urls=https://10.0.1.10:2380 --listen-peer-urls=https://10.0.1.10:2380 \
  --discovery ${DISCOVERY_URL}

# member2
$ etcd --name infra2 --data-dir infra2 \
  --auto-tls --peer-auto-tls \
  --initial-advertise-peer-urls=https://10.0.1.11:2380 --listen-peer-urls=https://10.0.1.11:2380 \
  --discovery ${DISCOVERY_URL}
```
自签名证书不会验证身份，因此curl将返回错误：
```
curl: (60) SSL certificate problem: Invalid certificate chain
```
要禁用证书链检查，请使用`-k`标志调用`curl`：
```
$ curl -k https://127.0.0.1:2379/v2/keys/foo -Xput -d value=bar -v
```

## DNS SRV的注意事项
* * *

如果连接是安全的，则`etcd proxy`从其客户端TLS终端，并使用`--peer-key-file`和`--peer-cert-file`中指定的代理自身的密钥/证书与etcd成员进行通信。

代理通过给定成员的`--advertise-client-urls`和`--advertise-peer-urls`与etcd成员进行通信。 它将客户端请求转发到etcd成员广播的客户端URL，并通过etcd成员广播的对等URL同步初始集群配置。

为etcd成员启用客户端身份验证后，管理员必须确保代理的`--peer-cert-file`选项中指定的对等节点证书对该身份验证有效。如果启用了对等节点身份验证，则代理的对等节点证书也必须对对等节点身份验证有效。

## TLS 身份验证的注意事项
* * *

从[v3.2.0开始，TLS证书将在每个客户端连接上重新加载](https://github.com/etcd-io/etcd/pull/7829)。 这在不停止etcd服务器而替换到期证书时很有用； 可以通过用新证书覆盖旧证书来完成。 刷新每个连接的证书应该没有太多的开销，但是将来可以通过缓存层进行改进。 示例测试可以在[这里](https://github.com/coreos/etcd/blob/b041ce5d514a4b4aaeefbffb008f0c7570a18986/integration/v3_grpc_test.go#L1601-L1757)找到。

从[v3.2.0开始，服务器使用错误的IP `SAN`拒绝传入的对等证书](https://github.com/etcd-io/etcd/pull/7687)。 例如，如果对等节点证书在“使用者备用名称”（SAN）字段中包含任何IP地址，则服务器仅在远程IP地址与这些IP地址之一匹配时才对对等节点身份验证。 这是为了防止未经授权的端点加入群集。 例如，对等节点B的CSR（带有cfssl）为：
```
{
  "CN": "etcd peer",
  "hosts": [
    "*.example.default.svc",
    "*.example.default.svc.cluster.local",
    "10.138.0.27"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "CA",
      "ST": "San Francisco"
    }
  ]
}
```
当对等节点B的实际IP地址是`10.138.0.2`，而不是`10.138.0.27`。 当对等节点B尝试加入集群时，对等节点A将拒绝B，并显示错误x509：证书对`10.138.0.27`有效，而不对`10.138.0.2`有效，因为B的远程IP地址与“使用者备用名称（SAN）”字段中的地址不匹配。

从[v3.2.0开始，服务器在检查SAN时解析TLS DNSNames](https://github.com/etcd-io/etcd/pull/7767)。 例如，如果对等节点证书在“使用者备用名称”（SAN）字段中仅包含DNS名称（不包含IP地址），则仅当这些DNS名称上的正向查找（`dig b.com`）具有与远程IP匹配的IP时，服务器才对对等身份验证 地址。 例如，对等B的CSR（带有`cfssl`）为：
```
{
  "CN": "etcd peer",
  "hosts": [
    "b.com"
  ],
```
当对等节点B的远程IP地址为`10.138.0.2`时。 当对等节点B尝试加入集群时，对等节点A查找传入的主机`b.com`以获取IP地址列表（例如`dig b.com`）。如果列表不包含IP `10.138.0.2`，则出现错误`tls: 10.138.0.2 does not match any of DNSNames ["b.com"]`.

从[v3.2.2开始，如果IP匹配，服务器将接受连接，而无需检查DNS条目](https://github.com/etcd-io/etcd/pull/8223)。 例如，如果对等节点证书在“使用者备用名称（SAN）”字段中包含IP地址和DNS名称，并且远程IP地址与这些IP地址之一匹配，则服务器仅接受连接而无需进一步检查DNS名称。 例如，对等节点B的CSR（带有`cfssl`）为：
```
{
  "CN": "etcd peer",
  "hosts": [
    "invalid.domain",
    "10.138.0.2"
  ],
```
当对等节点B的远程IP地址是`10.138.0.2`并且`invalid.domain`是无效的主机时。 当对等节点B尝试加入集群时，对等节点A成功地对节点B进行了身份验证，因为“使用者备用名称（SAN）”字段具有有效的匹配IP地址。 有关更多详细信息，请参见问题[＃8206](https://github.com/etcd-io/etcd/issues/8206)。

从[v3.2.5开始，服务器支持在通配符DNS `SAN`上进行反向查找](https://github.com/etcd-io/etcd/pull/8281)。 例如，如果对等节点证书在“使用者备用名称”（SAN）字段中仅包含DNS名称（不包含IP地址），则服务器首先对远程IP地址进行反向查找，以获取映射到该地址的名称列表（例如`nslookup IPADDR`）。如果这些名称的名称与对等节点证书的DNS名称（通过完全匹配或通配符匹配）匹配，则接受连接。 如果没有匹配项，则服务器将对等节点证书中的每个DNS条目进行正向查找（例如，如果条目为`*.example.default.svc`，则查找`example.default.svc`），并且仅在主机的解析地址具有匹配的IP时接受连接 地址和对等节点的远程IP地址。 例如，对等B的CSR（带有`cfssl`）为：
```
{
  "CN": "etcd peer",
  "hosts": [
    "*.example.default.svc",
    "*.example.default.svc.cluster.local"
  ],
```
当对等节点B的远程IP地址为`10.138.0.2`时。 当对等节点B尝试加入集群时，对等节点A反向查找IP `10.138.0.2`以获取主机名列表。 并且，“主题备用名称”（SAN）字段中的主机名必须与对等节点B的证书DNS名称完全匹配或与通配符匹配。 如果反向/正向查找均无效，则返回错误`"tls: "10.138.0.2" does not match any of DNSNames ["*.example.default.svc","*.example.default.svc.cluster.local"]`。有关更多详细信息，请参见问题[＃8268](https://github.com/etcd-io/etcd/issues/8268)。

[v3.3.0](https://github.com/etcd-io/etcd/blob/master/CHANGELOG-3.3.md)添加了[etcd --peer-cert-allowed-cn](https://github.com/etcd-io/etcd/pull/8616)参数，以支持[基于CN（通用名称）的对等节点连接的身份验证](https://github.com/etcd-io/etcd/issues/8262)。 Kubernetes TLS引导涉及为etcd成员和其他系统组件（例如API服务器，kubelet等）生成动态证书。 为每个组件维护不同的CA可提供对etcd集群的更严格的访问控制，但通常很乏味。 指定`--peer-cert-allowed-cn`标志时，即使具有共享的CA，节点也只能以匹配的通用名称加入。 例如，三节点群集中的每个成员都设置有CSR（使用`cfssl`），如下所示：
```
{
  "CN": "etcd.local",
  "hosts": [
    "m1.etcd.local",
    "127.0.0.1",
    "localhost"
  ],
```
```
{
  "CN": "etcd.local",
  "hosts": [
    "m2.etcd.local",
    "127.0.0.1",
    "localhost"
  ],
```
```
{
  "CN": "etcd.local",
  "hosts": [
    "m3.etcd.local",
    "127.0.0.1",
    "localhost"
  ],
```
如果给定`--peer-cert-allowed-cn etcd.local`，则只有具有相同通用名称的对等方将被认证。 CSR中具有不同CN或`--peer-cert-allowed-cn`的节点将被拒绝：
```
$ etcd --peer-cert-allowed-cn m1.etcd.local

I | embed: rejected connection from "127.0.0.1:48044" (error "CommonName authentication failed", ServerName "m1.etcd.local")
I | embed: rejected connection from "127.0.0.1:55702" (error "remote error: tls: bad certificate", ServerName "m3.etcd.local")
```
每个进程都应以以下内容开始：
```
etcd --peer-cert-allowed-cn etcd.local

I | pkg/netutil: resolving m3.etcd.local:32380 to 127.0.0.1:32380
I | pkg/netutil: resolving m2.etcd.local:22380 to 127.0.0.1:22380
I | pkg/netutil: resolving m1.etcd.local:2380 to 127.0.0.1:2380
I | etcdserver: published {Name:m3 ClientURLs:[https://m3.etcd.local:32379]} to cluster 9db03f09b20de32b
I | embed: ready to serve client requests
I | etcdserver: published {Name:m1 ClientURLs:[https://m1.etcd.local:2379]} to cluster 9db03f09b20de32b
I | embed: ready to serve client requests
I | etcdserver: published {Name:m2 ClientURLs:[https://m2.etcd.local:22379]} to cluster 9db03f09b20de32b
I | embed: ready to serve client requests
I | embed: serving client requests on 127.0.0.1:32379
I | embed: serving client requests on 127.0.0.1:22379
I | embed: serving client requests on 127.0.0.1:2379
```
[v3.2.19](https://github.com/etcd-io/etcd/blob/master/CHANGELOG-3.2.md)和[v3.3.4](https://github.com/etcd-io/etcd/blob/master/CHANGELOG-3.3.md)修复了[当证书SAN字段仅包含IP地址但不包含域名时TLS重新加载的问题](https://github.com/etcd-io/etcd/issues/9541)。 例如，如下设置了具有CSR（具有`cfssl`）的成员：
```
{
  "CN": "etcd.local",
  "hosts": [
    "127.0.0.1"
  ],
```
在Go中，仅当服务器的`（* tls.Config）.Certificates`字段不为空或`（* tls.ClientHelloInfo）.ServerName`不为空且具有有效SNI时，服务器才会调用`（* tls.Config）.GetCertificate`来重新加载TLS 来自客户。 以前，etcd始终填充`（* tls.Config）`。在初始客户端TLS握手上的证书为非空。 因此，总是希望客户端提供匹配的SNI，以便通过TLS验证并触发`（* tls.Config）.GetCertificate`以重新加载TLS数据。

但是，其SAN字段[仅包括IP地址不包含任何域名的证书](https://github.com/etcd-io/etcd/issues/9541)将请求`* tls.ClientHelloInfo`带有空的`ServerName`字段，从而无法在初始TLS握手时触发TLS重新加载；当需要在线更换过期证书时，这将成为一个问题。

现在,`（* tls.Config）.Certificates`在初始TLS客户端握手时创建为空，首先触发`（* tls.Config）.GetCertificate`，然后在每个新的TLS连接上填充其余证书，即使客户端SNI为 为空（例如，证书仅包括IP）。

## 主机白名单的注意事项
* * *

`etcd --host-whitelist`参数指定HTTP客户端请求中可接受的主机名。 客户端源策略可以防止对不安全的etcd服务器的“[DNS重新绑定](https://en.wikipedia.org/wiki/DNS_rebinding)”攻击。 也就是说，任何网站都可以简单地创建一个授权的DNS名称，并将DNS定向到“`localhost`”（或任何其他地址）。 然后，侦听“`localhost`”上的etcd服务器的所有HTTP端点都可以访问，因此容易受到DNS重新绑定攻击。 有关更多详细信息，请参见[CVE-2018-5702](https://bugs.chromium.org/p/project-zero/issues/detail?id=1447#c2)。

客户原始策略的工作方式如下：

1. 如果客户端通过HTTPS连接是安全的，则允许使用任何主机名。
2. 如果客户端连接不安全且“` HostWhitelist`”不为空，则仅允许其Host字段列在白名单中的HTTP请求。

请注意，无论是否启用身份验证，都会实施客户端来源策略，以进行更严格的控制。

默认情况下，`etcd --host-whitelist`和`embed.Config.HostWhitelist`设置为空以允许所有主机名。请注意，在指定主机名时，不会自动添加回送地址。 要允许环回接口，请手动将其添加到白名单（例如“ `localhost`”，“`127.0.0.1`”等）。

## 常见问题
* * *

使用TLS客户端身份验证时，我看到SSLv3警报握手失败？
`golang`的`crypto/tls`软件包在使用之前检查证书公钥的密钥用法。要使用证书公共密钥进行客户端身份验证，我们需要在创建证书公共密钥时将`clientAuth`添加到“`Extended Key Usage`”中。

这是操作方法：

将以下部分添加到openssl.cnf中：
```
[ ssl_client ]
...
  extendedKeyUsage = clientAuth
...

```
创建证书时，请确保在`-extensions`参数中引用它：
```
$ openssl ca -config openssl.cnf -policy policy_anything -extensions ssl_client -out certs/machine.crt -infiles machine.csr
```

通过对等证书身份验证，我收到“证书对127.0.0.1有效，而不对$我的Ip有效”

确保使用主题名称（成员的公共IP地址）对证书进行签名。 例如，`etcd-ca`工具为其`new-cert`命令提供了`--ip=`选项。

需要在其使用者名称中为成员的FQDN签署证书，使用使用者备用名称（简称IP SAN）添加IP地址。 `etcd-ca`工具为其`new-cert`命令提供了`--domain=`选项，`openssl`也可以做到[这](http://wiki.cacert.org/FAQ/subjectAltName)一点。