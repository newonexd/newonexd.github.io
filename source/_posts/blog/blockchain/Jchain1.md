---
title: 搭建你的第一个区块链网络(一)
date: 2020-05-19 15:00:28
tags: blockchain
---

写一个系列文章，由简入深搭建一个区块链网络，也是从零开始开发一个开源项目。
不再介绍区块链的基础知识了，所以希望读者提前了解区块链的基础知识，项目是使用SpringBoot(暂时用不到各项配置，为了以后方便)+JAVA开发，所以也需要读者了解JAVA语言。本文为第一篇。

## 区块

### 区块属性定义
第一步首先是区块信息的定义，暂时不考虑那么复杂，这里只定义一些最基础的属性:
* **区块号：** 就是区块的序号。 
* **当前区块哈希值：** 保证区块唯一，同时后一个区块链通过保留这一属性链接该区块。
* **前一区块哈希值：** 用于链接上一个区块。
* **时间戳：** 记录该区块产出时间。
* **数据：** 区块中存储的数据，为了简单化，这里使用字符串代替。

目前暂时只定义这些属性，后面开发如果需要其他属性再进行迭代。接下来是构造方法了:

### 构造方法定义

构建一个新的区块需要传入被构建区块的区块号，区块数据以及前一个区块的哈希值。

```
#Block.java

@Getter  # lombok工具包，加上这两个注释就不用写get(),set()方法了
@Setter   #工具包在下面
public class Block {
    // 区块号
    public int blkNum;
    // 当前区块哈希值
    public String curBlockHash;
    // 前一个区块的哈希值
    public String prevBlockHash;
    // 生成当前区块的时间，用时间戳表示
    public String timeStamp;
    // 当前区块中的Transaction,使用字符串简单代替
    public String data;
    public Block(int blkNum,String data, String prevBlockHash){
        this.blkNum = blkNum;
        this.data = data;
        this.prevBlockHash = prevBlockHash;
        this.timeStamp = Util.getTimeStamp();
    }
    @Override
    public String toString(){
        return JSONObject.toJSONString(this);
    }
}
```

其中涉及到获取时间戳的``getTimeStamp()``方法以及计算哈希值的``getSHA256()``方法。

```
#Util.java
public final class Util{
    public static String getSHA256(String data) {
        byte[] b = {};
        try{
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            b = md.digest(data.getBytes());
        }catch(NoSuchAlgorithmException e){
        }
        return Hex.encodeHexString(b);
    }
    public static String getTimeStamp(){
        SimpleDateFormat df = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");//设置日期格式
        String date = df.format(new java.util.Date());
        return date;
    }
}
```

这里使用到了几个工具包，可以在Maven的``pom.xml``文件``<dependencies>``标签中添加如下字段:

```
#pom.xml
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
         <dependency>
            <groupId>commons-codec</groupId>
            <artifactId>commons-codec</artifactId>
            <version>1.12</version>
        </dependency>
        <!-- https://mvnrepository.com/artifact/com.alibaba/fastjson -->
        <dependency>
            <groupId>com.alibaba</groupId>
            <artifactId>fastjson</artifactId>
            <version>1.2.62</version>
        </dependency>
```

### 区块链
我们需要一个区块链实例，用于记录所产出的区块。定义的区块链属性如下:

* **区块链实例:** 需要静态的(或者使用单例模式)，保证只存在一个区块链实例。
* **区块集合：** 定义一个集合用于保存产出的区块。

```
#Blockchain.java
    private static Blockchain BC;
    public ArrayList<Block> block;
    private Blockchain(){}
    public static Blockchain getInstance(){
        if(BC==null){
            synchronized(Blockchain.class){
                if(BC==null){
                    BC = new Blockchain();
                    BC.block = new ArrayList<Block>();
                }
            }
        }
        return BC;
    }
```

### 创建第一个区块

目前没有其他属性需要，接下来是定义方法。区块链实例定义完成，接下来可以创建区块链中的区块了，由于创世区块与后续区块稍微不同，所以定义一个构建创世区块的方法:

```
    public Block CrtGenesisBlock(){
        Block block = new Block(1,"Genesis Block","00000000000000000");
        //计算区块哈希值
        String hash = Util.getSHA256(block.getBlkNum()+block.getData()+block.getPrevBlockHash()+block.getPrevBlockHash()+block.getNonce());
        block.setCurBlockHash(hash);
        this.block.add(block);
        return this.block.get(0);
    }
```

由于创世区块是第一个区块，因此不存在前一个区块哈希值，直接定义为字符串"00000000000000000"。

### 添加区块

接下来是第二个方法，创建创世区块的后续区块方法:

```
    #传入的参数为需要区块中存储的数据
    public Block addBlock(String data){
         #获取区块集合的大小，即获取当前已经产出几个区块
        int num = this.block.size()；
        Block block = new Block(
             # 区块号为当前区块集合大小+1
            num+1,data, this.block.get(num-1).curBlockHash); 
        String hash = Util.getSHA256(block.getBlkNum()+block.getData()+block.getPrevBlockHash()+block.getPrevBlockHash());
        block.setCurBlockHash(hash);
        #将创建的区块添加到区块链中
        this.block.add(block);
        return this.block.get(num);
}
```

OK,一个简单的区块链已经完成，测试一下:

```
#Test.java
public class Test {
    public static void main(String[] args){
        System.out.println(Blockchain.getInstance().CrtGenesisBlock().toString());
        System.out.println(Blockchain.getInstance().addBlock("Block 2").toString());
    }
}
```

看起来没什么问题:

```
{"blkNum":1,"curBlockHash":"db27dd5c1e51197f6e9580613d9dbd5198a053b8c92da6560538579834e83159","data":"Genesis Block","prevBlockHash":"00000000000000000","timeStamp":"2020-05-16 17:09:10"}
{"blkNum":2,"curBlockHash":"bc6a75cf858241503a64ebdc5cf21ddcb187e6759c016b906f288cdac26ccae2","data":"Block 2","prevBlockHash":"db27dd5c1e51197f6e9580613d9dbd5198a053b8c92da6560538579834e83159","timeStamp":"2020-05-16 17:09:10"}
```

后一篇文章: [搭建你的第一个区块链网络(二)](https://www.cnblogs.com/cbkj-xd/p/12904660.html)

#### Github仓库地址在这里，随时保持更新中.....
Github地址：[Jchain](https://github.com/newonexd/Jchain)