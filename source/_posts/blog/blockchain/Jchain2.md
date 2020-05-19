---
title: 搭建你的第一个区块链网络(二)
date: 2020-05-19 15:00:49
tags: blockchain
---

前一篇文章: [搭建你的第一个区块链网络(一)](https://ifican.top/2020/05/19/blog/blockchain/Jchain1/)


## 共识与本地化
### POW共识

共识机制也是区块链系统中不可缺少的一部分，在比特币网络中，使用的是POW共识，概念相对比较简单，所以我们在该项目中使用POW共识机制(后期如果可以的话修改为可插拔的共识机制)。

#### POW原理
POW原理是通过解决一个数学难题，其实就是通过计算一个哈希值，如果计算出来的哈希值的前缀有足够多个"0"，就说明成功解决了该数学难题。通常哈希值中"0"的个数越多难度越大。难度值是通过之前生成的区块所消耗的时间动态调整的。而生成哈希值的原数据实际上就是区块信息，另外再加一个``nonce``属性，用于调整难度值。
在比特币中，平均每10分钟产出一个区块，如果新区块的产出只消耗了9分钟，那么难度值将会增加。如果算力不发生变化的话，下一次产出区块将会消耗更多的时间。同理，如果新区块的产出消耗了11分钟，那么难度值则会相应地降低。动态调整难度值维持区块产出时间平均为10分钟。实际上比特币中的POW更加复杂，难度值的调整是通过过去的2016个区块产出的时间与20160分钟进行比较的。
在这里，不设置那么麻烦，难度值不再动态调整，暂时将哈希值中"0"的数量固定保证每次生成区块的难度是相同的。同时也要设置一个最大难度值，防止无限循环计算。

```
#Pow.java
public class Pow {
    //固定的难度值
    private static final String DIFFICULT = "0000";
    //最大难度值 防止计算难度值变为无限循环
    private static final int MAX_VALUE = Integer.MAX_VALUE;
    public static int calc(Block block){
        //nonce从0开始
        int nonce = 0;
        //如果nonce小于最大难度值
        while(nonce<MAX_VALUE){
            //计算哈希值
            if(Util.getSHA256(block.toString()+nonce)
                    //如果计算出的哈希值前缀满足条件，退出循环
                    .startsWith(DIFFICULT))
                break;
            //不满足条件，nonce+1，重新计算哈希值
            nonce++;
        }
        return nonce;
    }
}
```

#### 更新属性
一个简单的POW共识完成了，接下来需要更新一下区块的属性，添加``nonce``属性:

```
#Block.java
    //产出该区块的难度
    public int nonce;
```

还要修改生成区块的方法，每次生成区块时需要进行POW共识计算:

```
    public Block CrtGenesisBlock(){
        Block block = new Block(1,"Genesis Block","00000000000000000");
        block.setNonce(
            Pow.calc(block));
        //计算区块哈希值
        String hash = Util.getSHA256(block.getBlkNum()+block.getData()+block.getPrevBlockHash()+block.getPrevBlockHash()+block.getNonce());
        ...
    }
    public Block addBlock(String data){
        ...
        Block block = new Block(
            num+1,data, this.block.curBlockHash);
        //每次将区块添加进区块链之前需要计算难度值
        block.setNonce(
            Pow.calc(block));
        //计算区块哈希值
        String hash = Util.getSHA256(block.getBlkNum()+block.getData()+block.getPrevBlockHash()+block.getPrevBlockHash()+block.getNonce());
        ...
    }
```

#### 测试POW共识
OK了，还是之前的测试方法，测试一下:

```
#Test.java
public class Test {
    public static void main(String[] args){
        System.out.println(Blockchain.getInstance().CrtGenesisBlock().toString());
        System.out.println(Blockchain.getInstance().addBlock("Block 2").toString());
    }
}
```
可以看到区块号为2的区块``nonce``属性有了具体的值，并且每次测试``curBlockHash``的值前缀都是以"0000"开头的。
```
{"blkNum":1,"curBlockHash":"000002278a13f6caefda04c77d35e14128aafbc287578b86e1f2079c0e6747b1","data":"Genesis Block","nonce":37846,"prevBlockHash":"00000000000000000","timeStamp":"2020-05-17 10:49:48"}
{"blkNum":2,"curBlockHash":"00002654109d8eb6092da686d66e70cdb1e26cf4a87e453e3d8e2ff7508f11f9","data":"Block 2","nonce":15318,"prevBlockHash":"000002278a13f6caefda04c77d35e14128aafbc287578b86e1f2079c0e6747b1","timeStamp":"2020-05-17 10:49:48"}
```

### 本地化
此外，每次重新启动程序都需要从创世区块重新开始生成，所以需要将区块信息序列化到本地。保证每次启动程序都可以从本地读取数据不再重新生成创世区块。

方便起见，暂时不使用数据库存储区块信息，只简单序列化到本地文件中来。
首先需要修改区块的信息，继承``Serializable``接口才能进行序列化。

```
#Block.java
public class Block implements Serializable{
    private static final long serialVersionUID = 1L;
    ...
}
```

#### 序列化与反序列化
接下来是序列化与反序列化的方法,在这里我们将每一个区块都保存为一个名字为区块号，后缀为``.block``的文件，同样从本地反序列化到程序中也只需要通过区块号来取。
```
#Storage.java
public final class Storage {
     //序列化区块信息
     public static void Serialize(Block block) throws IOException {
        File file = new File("src/main/resources/blocks/"+block.getBlkNum()+".block");
        if(!file.exists()) file.createNewFile();
        FileOutputStream fos = new FileOutputStream(file);
        ObjectOutputStream oos = new ObjectOutputStream(fos);
        
        oos.writeObject(block);
        oos.close();
        fos.close();
    }
    /**
     * 反序列化区块
     */
    public static Block Deserialize(int num) throws FileNotFoundException, IOException, ClassNotFoundException {
        File file = new File("src/main/resources/blocks/"+num+".block");
        if(!file.exists()) return null;
        ObjectInputStream ois = new ObjectInputStream(new FileInputStream(file));
        
        Block block = (Block)ois.readObject();
        ois.close();
        return block;
    }
}
```

然后是区块链的属性，之前我们使用``ArrayList``存储区块信息，而现在我们直接将区块序列化到本地，需要哪一个区块直接到本地来取，因此不再需要``ArrayList``保存区块数据。对于区块链来讲，仅仅需要记录最新区块数据即可。

```

public final class Blockchain {
    ...
    //Arraylist<Block> block修改为 Block block;
    public Block block;
    ...
    public static Blockchain getInstance() {
        if (BC == null) {
            synchronized (Blockchain.class) {
                if (BC == null) {
                    BC = new Blockchain();
                    //删除创建ArrayList
                }
            }
        }
        return BC;
    }

    public Block CrtGenesisBlock() throws IOException {
        ...
        block.setCurBlockHash(hash);
        //序列化
        Storage.Serialize(block);
        this.block=block;
        return this.block;
    }
    public Block addBlock(String data) throws IOException {
        int num = this.block.getBlkNum();
        ...
        block.setCurBlockHash(hash);
        //序列化
        Storage.Serialize(block);
        this.block = block;
        return this.block;
    }
}
```

测试一下:
```
public class Test {
    public static void main(String[] args) throws IOException {
        System.out.println(Blockchain.getInstance().CrtGenesisBlock().toString());
        System.out.println(Blockchain.getInstance().addBlock("Block 2").toString());
    }
}
```
存储是没有问题的，在``resources/blocks/``文件下成功生成了``1.block,2.block``两个文件。

#### 反序列化

但是还没有完成从本地取数据的操作，接下来的流程是这样子的:
启动程序后，首先实例化``Blockchain``的实例，然后从本地读取数据，如果本地存在区块数据，直接反序列化区块号最大的区块，如果本地没有数据，则进行创始区块的创建。

```
#Blockchain.java
public Block getLastBlock() throws FileNotFoundException, ClassNotFoundException, IOException {
        File file = new File("src/main/resources/blocks");
        String[] files = file.list();
        if(files.length!=0){
            int MaxFileNum = 1;
            //遍历存储区块数据的文件夹，查找区块号最大的区块
            for(String s:files){
                int num = Integer.valueOf(s.substring(0, 1));
                if(num>=MaxFileNum)
                    MaxFileNum = num;
            }
            //反序列化最大区块号的区块
           return Storage.Deserialize(MaxFileNum);
        }
        return null;
    }
```
然后是``Blockchain``的实例方法，在获取实例时候判断是否需要创建创世区块:
```
#Blockchain.java
    public static Blockchain getInstance() throws FileNotFoundException, ClassNotFoundException, IOException {
        if (BC == null) {
            synchronized (Blockchain.class) {
                if (BC == null) {
                    BC = new Blockchain();
                }
            }
        }
        //获取到Blockchain实例后，判断是否存在区块
        if(BC.block==null){
            //如果不存在则尝试获取本地区块号最大的区块
            //如果存在则直接赋值到Blockchain的属性然后返回
            Block block = BC.getLastBlock();
            BC.block = block;
            if(block==null){
                //如果不存在则生成创世区块
                BC.CrtGenesisBlock();
            }
        }
        return BC;
    }
    
    //因此创建创世区块的方法可以修改为私有的
    private Block CrtGenesisBlock() throws IOException {
        ...
    }
```

接下来可以测试了:

```
public class Test {
    public static void main(String[] args) throws IOException, ClassNotFoundException {
        System.out.println(Blockchain.getInstance().block.toString());
        System.out.println(Blockchain.getInstance().addBlock("Block 2").toString());
    }
}
```
测试多次可以发现区块并没有重新从创世区块开始生成，而是根据先前生成的区块号继续增长。
```
{"blkNum":1,"curBlockHash":"000002278a13f6caefda04c77d35e14128aafbc287578b86e1f2079c0e6747b1","data":"Genesis Block","nonce":37846,"prevBlockHash":"00000000000000000","timeStamp":"2020-05-17 11:51:37"}
{"blkNum":2,"curBlockHash":"00002654109d8eb6092da686d66e70cdb1e26cf4a87e453e3d8e2ff7508f11f9","data":"Block 2","nonce":15318,"prevBlockHash":"000002278a13f6caefda04c77d35e14128aafbc287578b86e1f2079c0e6747b1","timeStamp":"2020-05-17 11:51:37"}

Current Last Block num is:2
{"blkNum":2,"curBlockHash":"00002654109d8eb6092da686d66e70cdb1e26cf4a87e453e3d8e2ff7508f11f9","data":"Block 2","nonce":15318,"prevBlockHash":"000002278a13f6caefda04c77d35e14128aafbc287578b86e1f2079c0e6747b1","timeStamp":"2020-05-17 11:51:37"}
{"blkNum":3,"curBlockHash":"0000d350c1199eb51c2d43194653f5b44444665e40373d5883edd3567c60cd68","data":"Block 2","nonce":23695,"prevBlockHash":"00002654109d8eb6092da686d66e70cdb1e26cf4a87e453e3d8e2ff7508f11f9","timeStamp":"2020-05-17 11:51:44"}
```

大致工作已完成，接下来添加几个额外的方法:

```
#Block.java
       /**
     * 是否存在前一个区块
     */
    public boolean hasPrevBlock(){
        if(this.getBlkNum()!=1){
            return true;
        }
        return false;
    }
    @Transient
    @JsonIgnore
    /**
     * 获取前一个区块
     */
    public Block getPrevBlock() throws FileNotFoundException, ClassNotFoundException, IOException {
        if(this.hasPrevBlock())
            return Storage.Deserialize(this.getBlkNum()-1);
        return null;          
    }
```

后一篇文章: [搭建你的第一个区块链网络(三)](https://ifican.top/2020/05/19/blog/blockchain/Jchain3/)

#### Github仓库地址在这里，随时保持更新中.....
Github地址：[Jchain](https://github.com/newonexd/Jchain)