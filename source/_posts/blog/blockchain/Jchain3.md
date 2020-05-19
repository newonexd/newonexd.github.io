---
title: 搭建你的第一个区块链网络(三)
date: 2020-05-19 15:01:06
tags: blockchain
---
前一篇文章: [搭建你的第一个区块链网络(二)](https://www.cnblogs.com/cbkj-xd/p/12904660.html)


## 钱包与CLI

### 钱包
对于区块链系统来说，密码学是必不可少的，因此加密与解密也是核心操作，而密钥通常使用钱包进行保存，这一节我们完成钱包的设计。这一节比较简单。
在比特币网络中，使用的是非对称加密算法，密钥是通过椭圆曲线算法实现的，而本文中，暂且使用RSA算法进行实现，后期再对椭圆曲线算法进行添加。
首先是RSA算法的工具类，参考[这里](https://www.jianshu.com/p/aff5492d64f0).整理成以下方法:

```
#RSAKey.java
@Getter
@Setter
public final class RSAKey {
     //非对称密钥算法
     public static final String KEY_ALGORITHM = "RSA";
     /**
      * 密钥长度必须是64的倍数，在512到65536位之间
      */
     private static final int KEY_SIZE = 512;
     //公钥
     private static final String PUBLIC_KEY = "RSAPublicKey";
 
     //私钥
     private static final String PRIVATE_KEY = "RSAPrivateKey";
    private byte[] privateKey;
    private byte[] publicKey;
    private String address;
    private RSAKey() {
    }
    /**
     * 生成密钥
     */
    public static RSAKey GenerateKeyPair() throws Exception {
        RSAKey key = new RSAKey();
        Map<String, Object> keyPair = key.initKey();
        Key pk = (Key) keyPair.get(PRIVATE_KEY);
        key.setPrivateKey(pk.getEncoded());
        pk = (Key)keyPair.get(PUBLIC_KEY);
        key.setPublicKey(pk.getEncoded());
        return key;
    }
    private Map<String, Object> initKey() throws Exception {
        //实例化密钥生成器
        KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance(KEY_ALGORITHM);
        //初始化密钥生成器
        keyPairGenerator.initialize(KEY_SIZE);
        //生成密钥对
        KeyPair keyPair = keyPairGenerator.generateKeyPair();
        //公钥
        RSAPublicKey publicKey = (RSAPublicKey) keyPair.getPublic();
        //私钥
        RSAPrivateKey privateKey = (RSAPrivateKey) keyPair.getPrivate();
        //将密钥存储在map中
        Map<String, Object> keyMap = new HashMap<String, Object>();
        keyMap.put(PUBLIC_KEY, publicKey);
        keyMap.put(PRIVATE_KEY, privateKey);
        return keyMap;
    }
    /**
     * 私钥加密
     *
     * @param data 待加密数据
     * @param key       密钥
     * @return byte[] 加密数据
     */
    public static byte[] encryptByPrivateKey(byte[] data,byte[] pk) throws Exception {
        //取得私钥
        PKCS8EncodedKeySpec pkcs8KeySpec = new PKCS8EncodedKeySpec(pk);
        KeyFactory keyFactory = KeyFactory.getInstance(KEY_ALGORITHM);
        //生成私钥
        PrivateKey privateKey = keyFactory.generatePrivate(pkcs8KeySpec);
        //数据加密
        Cipher cipher = Cipher.getInstance(keyFactory.getAlgorithm());
        cipher.init(Cipher.ENCRYPT_MODE, privateKey);
        return cipher.doFinal(data);
    }
   /**
    * 公钥解密
    *
    * @param data 待解密数据
    * @param key  密钥
    * @return byte[] 解密数据
    */
    public static byte[] decryptByPublicKey(byte[] data,byte[] pk) throws Exception {
        //实例化密钥工厂
        KeyFactory keyFactory = KeyFactory.getInstance(KEY_ALGORITHM);
        //初始化公钥
        //密钥材料转换
        X509EncodedKeySpec x509KeySpec = new X509EncodedKeySpec(pk);
        //产生公钥
        PublicKey pubKey = keyFactory.generatePublic(x509KeySpec);
        //数据解密
        Cipher cipher = Cipher.getInstance(keyFactory.getAlgorithm());
        cipher.init(Cipher.DECRYPT_MODE, pubKey);
        return cipher.doFinal(data);
    }
}
```
#### 密钥
接下来创建钱包实例，对于用户的钱包，需要一下属性:

* **私钥：** 用于加密数据，签名数据。
* **公钥：** 用于解密数据，验证签名。
* **地址：** 钱包的地址。

目前，暂时将钱包设置为单例模式，同时一个钱包中只含有一对密钥对:

```
#Wallet.java

@Getter
@Setter
public class Wallet {
    //单例模式的Wallet
    private static Wallet wallet;
    //私钥
    private byte[] privateKey;
    //公钥
    private byte[] publicKey;
    //地址
    private String address;
    private Wallet() throws Exception {
        RSAKey key  = RSAKey.GenerateKeyPair();
        this.privateKey = key.getPrivateKey();
        this.publicKey = key.getPublicKey();
        this.address = generateAddress();
    }
    public static Wallet getInstance() throws Exception {
        if (wallet == null) {
            synchronized (Wallet.class) {
                if (wallet == null) {
                    wallet = new Wallet();
                }
            }
        }
        return wallet;
    }
 }
```

接下来是加密与解密操作，只需要包装一下工具类即可:
```
#Wallet.java
    /**
     * 加密数据
     */
    public String encrypt(byte[] data) throws Exception {
        byte[] encry = RSAKey.encryptByPrivateKey(data,this.privateKey);
        return Hex.encodeHexString(encry);
    }
    /**
     *  解密数据
     */
    public byte[] decrypt(String encry) throws DecoderException, Exception {
        return RSAKey.decryptByPublicKey(Hex.decodeHex(encry),this.publicKey);
    }
```
还有重要的签名与验证签名的操作:
签名的本质实际上就是哈希操作+加密操作。

1. 对数据原文进行哈希: **哈希(数据原文)**
2. 使用私钥对哈希值进行加密: **加密(哈希(数据原文))**
3. 将数据原文与签名数据进行组合
数字签名的组成部分为：**数据原文+加密(哈希(数据原文))**

```
#Wallet.java
    /**
     * 签名数据
     */
    public String sign(byte[] data) throws Exception {
        //原文首先进行哈希
        String hash = Util.getSHA256(
            Hex.encodeHexString(data));
        //哈希值进行加密
        String sign = encrypt(
            Hex.decodeHex(hash));
        //原文+encry(hash(原文))
        return Hex.encodeHexString(data)+"%%%"+sign;
    }
```
在这里，我们简单使用``%%%``将两部分数据进行组合。
至于数字签名的验证则可以分析了：

1. 首先将数字签名拆分为**数据原文  加密(哈希(数据原文))**
2. 将数据原文进行哈希操作: **哈希(数据原文)**
3. 使用公钥解密签名信息： **解密->加密(哈希(数据原文))->哈希(数据原文)**
4. 对两部分哈希值进行对比，相同则说明数字签名是有效的。

```
#Wallet.java
    /**
     * 验证签名
     */
    public boolean verify(String data) throws DecoderException, Exception {
        String[] str = data.split("%%%");
        // 原文     encry(hash(原文))
        if(str.length!=2){
            return false;
        }
        String hash = Util.getSHA256(str[0]);
        String hash2 = Hex.encodeHexString(this.decrypt(str[1]));
        if(hash.equals(hash2)){
            return true;
        }
        return false;
    }
```

#### 地址
对于钱包地址，比特币是有自己的一套生成地址的算法，步骤相对比较繁杂，在本文中，简单使用哈希操作模拟地址的生成。

```
#Wallet.java
    /**
     * 根据密钥生成地址
     */
    private String generateAddress() throws NoSuchAlgorithmException {
        String pk = Hex.encodeHexString(this.publicKey);
        this.address = "R" + Util.getSHA256(pk) + Util.getSHA256(Util.getSHA256(pk));
        return this.address;
    }
    /**
     * 获取地址
     * @return
     * @throws NoSuchAlgorithmException
     */
    public String getAddress() throws NoSuchAlgorithmException {
        return this.generateAddress();
    }
```

所有的一切都已经完成，测试一下:

```
#KeyTest.java
public class KeyTest {
    public static void main(String[] args) throws DecoderException, Exception {
        Wallet wallet  = Wallet.getInstance();
        System.out.println("private Key:  "+Hex.encodeHexString(wallet.getPrivateKey()));
        System.out.println();
        System.out.println("public Key:  "+Hex.encodeHexString(wallet.getPublicKey()));
        System.out.println(
            wallet.verify(
                wallet.sign("test".getBytes())));
        System.out.println("address: "+wallet.getAddress());
    }
}
```

看起来一切都没有问题:

```
private Key:  30820156020100300d06092a864886f70d0101010500048201403082013c020100024100b204075a20a86a8773681a2bee6574a68d1028516577c80f22d1f693dbc1c70cca59d95a74b8c7a55c3e02801ebdb025272f1df18ca862701b640a6bc444b7e50203010001024066a67a12d7a8261dcb47a967d1c5813995384ef778da546b9df993057a0048a5b9e2f3986bef45bbcffc13baff6a93b31b054ecd6f23ad9c23a088597bc169b5022100e210191df6e5661b7fbe239866110bc54ace03e22d9e242d199b0f95d42c3e7f022100c9970dbe3640ad34633cb1a3defa5fc4be1dd9881eb65ff19d53d0ae2c569f9b022100c46a544872b2926b262ca064d399cfee55b6762d589164c142d435506b0f1e25022100a65a09543aaeda7f4d98eb3a4029ba57bf4f20904c4fd112aff25755336f741b022100dbe2e256464346e26c134395aada2bd669f72700b146b494920e9c75df12403f

public Key:  305c300d06092a864886f70d0101010500034b003048024100b204075a20a86a8773681a2bee6574a68d1028516577c80f22d1f693dbc1c70cca59d95a74b8c7a55c3e02801ebdb025272f1df18ca862701b640a6bc444b7e50203010001
true
address: R92439f4d205def0794e23f626cf61013d04ccf1fdf9106ff78ca3ec30f7bc7cad4cdc346ee44501831c67085a54463e4ffd774654a2bd9328a382652de663f1a
```

### Cli

到此为止我们开发了区块链系统的部分功能，距离完成还有很长一段距离。不过，先完成一个比较小的功能好了，即与用户进行交互的操作。之前考虑过使用``curl``，不过看到了``apache``的``cli``工具，所以决定使用这个了。其实就是一种命令行解析工具，根据输入的命令解析后执行对应的功能。参考[这里](https://www.ibm.com/developerworks/cn/java/j-lo-commonscli/)
所以需要在``pom.xml``添加一下字段导包:

```
        <dependency>
            <groupId>commons-cli</groupId>
            <artifactId>commons-cli</artifactId>
            <version>1.2</version>
        </dependency>
```

整个步骤分为三个阶段: **定义，解析，询问**。

#### 定义
首先需要定义一些参数信息，作为应用程序的接口。

```
        //创建Options对象
        Options options = new Options();
        //添加-h参数。 h为参数简单形式，help为参数复杂形式，false定义该参数不需要额外的输入，Print help为参数的介绍
        Option opt = new Option("h", "help", false, "Print help");
        //定义该参数是否为必须的
        opt.setRequired(false);
        options.addOption(opt);
```

#### 解析
由CLi对用户输入的命令行进行解析。

```
        HelpFormatter hf = new HelpFormatter();
        hf.setWidth(110);
        CommandLine commandLine = null;
        CommandLineParser parser = new PosixParser();
        try {
            commandLine = parser.parse(options, args);
            //如果含有参数h，则打印帮助信息
            if (commandLine.hasOption('h')) {
                // 打印使用帮助
                hf.printHelp("Jchain", options, true);
            }
            ...
        }catch(Exception e){
        }
```

``CommandLineParser`` 类中定义的 ``parse`` 方法将用 CLI 定义阶段中产生的 ``Options`` 实例和一组字符串作为输入，并返回解析后生成的 ``CommandLine``。
CLI 解析阶段的目标结果就是创建`` CommandLine`` 实例。

#### 询问

该阶段是根据输入的参数决定进入哪一个逻辑分支中。

```
            Option[] opts = commandLine.getOptions();
            if (opts != null) {
                for (Option opt1 : opts) {
                    //name为参数名称
                    String name = opt1.getLongOpt();
                    //如果有额外的参数则传入value中
                    String value = commandLine.getOptionValue(name);
                    //...根据name指定具体的逻辑分支
                }
            }
```

分析完了，然后制定需要的参数好了:
这里指定了三个参数:``s,a,w``，分别为获取区块链实例，添加区块以及获取钱包实例的功能。
```
        opt = new Option("s", "start", false, "start blockchain");
        opt.setRequired(false);
        options.addOption(opt);
        opt = new Option("a", "add", true, "add block");
        opt.setRequired(false);
        options.addOption(opt);
        opt = new Option("w", "wallet", false, "init wallet");
        opt.setRequired(false);
        options.addOption(opt);
```

然后是具体的逻辑分支:

```
        if (name.equals("s") || name.equals("start")) {
            System.out.println(Blockchain.getInstance().block.toString());
        }
        if(name.equals("a")||name.equals("add")&&value!=""){
            System.out.println(Blockchain.getInstance().addBlock(value).toString());
        } 
        if(name.equals("w")||name.equals("wallet")){
            Wallet wallet = Wallet.getInstance();
            System.out.println("private Key:  "+Hex.encodeHexString(wallet.getPrivateKey()));
            System.out.println();
            System.out.println("public Key:  "+Hex.encodeHexString(wallet.getPublicKey()));
        } 
```
简单测试一下是否正常工作:

```
#CliTest.java
public class CliTest {
    public static void main(String[] args){
        String[] str = {"-s","-w","-a","block"};
        // String[] str = {"-h"};
        Cli.Start(str);
    }
}
```

看起来没有问题，获得了高度为4的区块链实例。也成功创建了钱包打印出公私钥。
最后生成了高度为5的区块 区块信息为我们输入的"block"。
```
Current Last Block num is:4
{"blkNum":4,"curBlockHash":"0000287895ae8f4e4fc781137adee2b2fd0da4d7be3abb68c04507979157eb70","data":"block","nonce":121263,"prevBlockHash":"00003ae4ca11f2dd6262d9218ffe6a98416b4e9e2ad789b39aef74b383cc96a6","timeStamp":"2020-05-17 14:28:16"}
private Key:  30820154020100300d06092a864886f70d01010105000482013e3082013a02010002410082a46b7f68d835b5e8047b8794cfd4d5daf4b6f3d8258a8a78f670052f35bab562f52aa7a6eeeb69bc14e03f0d8019db5b754d68e8d0918aa6f2f4b636ba0f070203010001024009de8ffc6d18405e80abae055d19a253919a012444c4f94562c4034c70f79726372e85f8853b9093e984b2fee8d828cf6078b2b66239e5871e299985a9b85ea1022100bed5f1748ffeabd423e7518c2c9840d9299f5190f3e482b0ec50ae203cd25b17022100af409e3b74a06c4937f8ca3bc12776ff21217750a4b5e1d02de71d1a7ceda19102202085d3959ae8bb1df75477d85ccd41d800b8ef2cb5f40eb5da4051bc9ac0fad702206342871c87b6e0fe2b6c872687051239f88adae85b12051f0310b6842d23ee710221008ebb60975fc2ee07e94242da08e0cb81478b7c57091e20e2177aa325883e4714

public Key:  305c300d06092a864886f70d0101010500034b00304802410082a46b7f68d835b5e8047b8794cfd4d5daf4b6f3d8258a8a78f670052f35bab562f52aa7a6eeeb69bc14e03f0d8019db5b754d68e8d0918aa6f2f4b636ba0f070203010001
{"blkNum":5,"curBlockHash":"000047e8fc13a5fe0404aeca104f8624581738361f12f2a8c07c4f172dde62cc","data":"block","nonce":67701,"prevBlockHash":"0000287895ae8f4e4fc781137adee2b2fd0da4d7be3abb68c04507979157eb70","timeStamp":"2020-05-17 16:27:29"}
```

后一篇文章: [搭建你的第一个区块链网络(二)](https://www.cnblogs.com/cbkj-xd/p/12910299.html)

#### Github仓库地址在这里，随时保持更新中.....
Github地址：[Jchain](https://github.com/newonexd/Jchain)