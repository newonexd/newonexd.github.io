---
title: 搭建你的第一个区块链网络(四)
date: 2020-05-19 15:01:22
tags: blockchain
---
前一篇文章: [搭建你的第一个区块链网络(三)](https://ifican.top/2020/05/19/blog/blockchain/Jchain3/)

## UTXO

#### 组成部分
UTXO是比特币中一个重要的概念，这一节我们来实现一个简单的UTXO。我们把UTXO的组成部分分为以下三点:

* **UTXOId:** 标识该UTXO
* **TxInput:** 交易输入，即coin的输入地址以及金额
* **TxOutput:** 交易输出，即coin的输出地址以及金额

其中``TxInput``与``TxOutput``分别具有以下几个属性:

**TxInput:**  交易输入

* **preTxId**: 指向的前一个UTXO的id
* **value**： 输入的金额
* **unLockScript:** 解锁脚本

其中交易输入需要引用之前的UTXO的输出。这样很容易知道当前的交易输入的金额是由之前的哪一笔交易中的交易输出的金额传递的。
保证每一笔未消费的金额都可以找到它的源地址。
解锁脚本的作用是用于解锁当前交易输入所引用的交易输出的。因为每一笔金额都有所属，被锁定在某一个地址上面。只有该金额的所有者才具有权限消费进行消费。而解锁脚本一般都是一个数字签名。

**TxOutput** 交易输出

* **value** :输出的金额
* **lockScript**: 锁定脚本

每当一笔coin被转移，都会被锁定在一个地址上面，因此锁定脚本一般都是一个地址。

对于每一笔UTXO，输入的金额一定是等于输出的金额的。另外UTXO有一个特点，就是不能够只花费其中一部分。而是需要全部消费，而多余的再返还给原地址。
比如用户a具有10个coin被锁定在一个UTXO中，如果a需要转账给b5个coin，那么需要将10个coin全部花费掉，其中5个coin输出到b的地址，剩余的5个coin输出到a的地址。
因此一笔UTXO可以有多个交易输出，同时也可以有多个输入。

大致概念介绍差不多了，我们来实现它:

```
#TxInput.java
//因为我们采用的序列化保存区块，而该数据需要写入区块，因此需要实现Serializable接口
public class TxInput implements Serializable{
    private static final long serialVersionUID = 1L;
    // 所引用的前一个交易ID
    public String preTxId;
    // 该输入中包含的coin
    public int values;
    // 解锁脚本 通常为数字签名
    public String unLockScript;
    public TxInput(String txId, TxOutput top, Wallet wallet) throws Exception {
        //对引用的Txoutput中的地址进行签名，用于解锁引用的TxOutPut.
        this.unLockScript = wallet.sign(top.getLockScript());
        //记录引用的上一个交易ID
        this.preTxId = txId;
        //coin值等于引用的Txoutput的coin值
        this.values = top.value;
    }
}
```

接下来是交易输出:

```
#TxOutput.java

@Getter
public class TxOutput implements Serializable{
    //同理需要实现Serializable接口
    private static final long serialVersionUID = 1L;
    // 交易输出的coin值。
    public int value;
    //锁定脚本 通常为地址
    public String lockScript;
    public TxOutput(int value,String address){
        this.value = value;
        this.lockScript = address;
    }
}
```
最后是UTXO的实现: 我们使用``Transaction``进行表示。
```
#Transaction.java

@Getter
@Setter
public class Transaction implements Serializable{
    //为了后期调试方便，引入了log4j的包，导入方法和之前一样
    private transient static final Logger LOGGER = Logger.getLogger(Transaction.class);
    private static final long serialVersionUID = 1L;
    //COINBASE之后再进行解释
    private transient static final int COINBASE = 50;
    //UTXOId
    public String txId;
    // 交易输入的集合
    public ArrayList<TxInput> tips;
    // 交易输出的集合 String:address
    public HashMap<String, TxOutput> tops;

    private Transaction() {
        #这里只创建了保存交易输出的集合,因为涉及到Coinbase，暂时先不创建ArrayList
        this.tops = new HashMap<>(4);
    }
    @Override
    public String toString(){
        return JSONObject.toJSONString(this);
    }
}
```

log4j日志包:

```
        <dependency>
            <groupId>log4j</groupId>
            <artifactId>log4j</artifactId>
            <version>1.2.17</version>
        </dependency>
```
这里为了方便起见分别使用``ArrayList``和``HashMap``存储交易输入与输出.

### 创建UTXO
接下来是创建UTXO的核心方法，比较复杂，我们先来分析一下:
首先传入的参数需要有: 发送coin的源地址，发送coin的目的地址，coin的值。
返回值为一个``Transaction``实例。

接下来分析如何创建UTXO：

1. 首先需要遍历整个区块链，查找到所有**未消费的**被锁定在源地址的交易输出。
2. 将查找到的所有包含符合条件的交易输出的UTXO记录在集合中。
3. 遍历该集合，将每一笔UTXO中未消费的输出相加，直到满足转账金额或者是统计完全部UTXO。
4. 将统计的每一笔UTXO中交易输出创建为新的交易输入用于消费。
5. 判断是否coin值刚好等于需要转账的coin。如果相等则创建一个交易输出将coin转账到目的地址。
6. 如果有多余的则再创建一个交易输出返回多余的coin到源地址。

OK，分析完了可以开发了:

```
#Transaction.java
    public static Transaction newUTXO(String fromAddress, String toAddress, int value)
            throws NoSuchAlgorithmException, Exception {
        //第一步遍历区块链统计UTXO
        Transaction[] txs = Blockchain.getInstance().findAllUnspendableUTXO(fromAddress);
        if (txs.length == 0) {
            LOGGER.info("当前地址"+fromAddress+"没有未消费的UTXO！！！");
            throw new Exception("当前地址"+fromAddress+"没有未消费的UTXO,交易失败！！！");
        }
        TxOutput top;
        // 记录需要使用的TxOutput
        HashMap<String, TxOutput> tops = new HashMap<String, TxOutput>();
        int maxValue = 0;
        // 遍历交易集合
        for (int i = 0; i < txs.length; i++) {
            // 查找包括地址为fromAddress的TxOutput
            if (txs[i].tops.containsKey(fromAddress)) {
                top = txs[i].tops.get(fromAddress);
                // 添加进Map
                tops.put(txs[i].txId, top);
                // 记录该TxOutput中的value
                maxValue += top.value;
                // 如果大于需要使用的则退出
                if (maxValue >= value) {
                    break;
                }
            }
        }
        // 是否有足够的coin
        if (maxValue >= value) {
            // 创建tx
            Transaction t = new Transaction();
            t.tips = new ArrayList<TxInput>(tops.size());
            // 遍历所有需要用到的Txoutput
            tops.forEach((s, to) -> {
                // 变为TxInput
                try {
                    t.tips.add(new TxInput(s, to, Wallet.getInstance()));
                } catch (Exception e) {
                    e.printStackTrace();
                }
            });
            //如果值不均等
            if(maxValue>value){
                //创建TxOutput返还多余的coin
                top = new TxOutput(maxValue-value, Wallet.getInstance().getAddress());
                t.tops.put(top.getLockScript(), top);
            }
            //目的地址
            top = new TxOutput(value, toAddress);
            t.tops.put(top.getLockScript(), top);
            LOGGER.info("创建UTXO: "+t.toString());
            return t;
        }
        LOGGER.info("当前地址余额不足!!,余额为"+maxValue);
        throw new Exception("当前地址余额不足!!,余额为"+maxValue);
    }
```

### 统计未消费的UTXO
然后是另外一个核心方法，统计区块链中符合条件的全部未消费的UTXO：
我们使用比较简单易理解的方式，先统计地址匹配的所有的交易输出。
然后统计所有的满足条件的交易输入。交易输入需要满足两个条件：

1. 地址是自己的地址
2. 交易输入中引用的UTXOid可以追溯到。

我们将符合条件的``TxInput``中引用的UTXOId在所有未消费的UTXO中匹配，
如果匹配到说明该UTXO已经被花费掉了，我们移除掉花费掉的UTXO，剩下的就是满足条件的未消费的UTXO了。

```
#Blockchain.java
public Transaction[] findAllUnspendableUTXO(String address)
            throws FileNotFoundException, ClassNotFoundException, IOException {
        LOGGER.info("查找所有未消费的UTXO...............");
        HashMap<String, Transaction> txs = new HashMap<>();
        Block block = this.block;
        Transaction tx;
        // 从当前区块向前遍历查找UTXO txOutput
        do{
            //从区块中获取交易信息
            tx = block.getTransaction();
            // 如果存在交易信息，且TxOutput地址包含address
            if (tx != null && tx.getTops().containsKey(address)) {
                txs.put(tx.getTxId(), tx);
            }
            //指向前一个区块
            block = block.getPrevBlock();
            //一直遍历到创世区块
        }while(block!=null && block.hasPrevBlock()) ;
        // 再遍历一次查找已消费的UTXO
        block = this.block;
        do {
            tx = block.getTransaction();
            if (tx != null) {
                // 如果交易中的TxInput包含的交易ID存在于txs，移除
                tx.getTips().forEach(tip -> {
                    try {
                        //需要满足两个条件，一是Txinput中引用的UTXOId存在，说明该UTXO已经被使用了
                        //二是需要保证地址相同，确认该TxInput是coin所有者消费的
                        if (Wallet.getInstance().verify(address,tip.unLockScript) 
                                && txs.containsKey(tip.preTxId))
                            //满足两个条件则移除该UTXO
                            txs.remove(tip.preTxId);
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                });
            }
            block = block.getPrevBlock();
        }while (block!=null && block.hasPrevBlock());
        //创建UTXO数组返回
        Transaction[] t = new Transaction[txs.size()];
        return txs.values().toArray(t);
    }
```
看这里的代码：
```
 if (Wallet.getInstance().verify(address,tip.unLockScript) && txs.containsKey(tip.preTxId))
    ...
```
首先验证``TxInput``的解锁脚本是否对我们钱包的地址进行签名得到的，即验证这一笔输入是否是自己消费的。
如果是自己消费的然后比对UTXO的Id，如果相同则说明这笔UTXO已经被消费掉了。那么需要移除它。
在钱包中添加一个新的方法，用于验证解锁脚本是否可以解锁交易输出。我们简单采用哈希值匹配的方式模拟验证。
```
#Wallet.java
    public boolean verify(String data,String sign) throws DecoderException, Exception {
        LOGGER.info("验证签名: "+data);
        String[] str = data.split("%%%");
        // 原文     encry(hash(原文))
        if(str.length!=2){
            return false;
        }
        String hash2 = Hex.encodeHexString(this.decrypt(str[1]));
        String hash3 = Util.getSHA256(data);
        if(hash3.equals(hash2)){
            LOGGER.info("签名验证成功！！");
            return true;
        }
        LOGGER.info("签名验证失败！！");
        return false;
    }
```

### 更新区块信息
加入了UTXO的概念，那我们需要更新区块以及区块链的属性信息了。

```
#Block.java
@Getter
@Setter
public class Block implements Serializable{
    ...
    //当前区块中的交易
    public Transaction transaction;
    ...
    //添加一个新的构造方法
    public Block(int blkNum,Transaction transaction,String prevBlockHash){
        this.blkNum = blkNum;
        this.transaction = transaction;
        this.prevBlockHash = prevBlockHash;
        this.timeStamp = Util.getTimeStamp();
    }
    ...
}
```
然后是区块链，也要更新一个方法:
```
#Blockchain.java
public final class Blockchain {
    ...
    public Block addBlock(Transaction tx) throws IOException {
        int num = this.block.getBlkNum();
        Block block = new Block(num + 1, tx, this.block.curBlockHash);
        // 每次将区块添加进区块链之前需要计算难度值
        block.setNonce(Pow.calc(block));
        // 计算区块哈希值
        String hash = Util.getSHA256(block.getBlkNum() + block.getData() + block.getPrevBlockHash()
                + block.getPrevBlockHash() + block.getNonce());
        block.setCurBlockHash(hash);
        // 序列化
        Storage.Serialize(block);
        this.block = block;
        LOGGER.info("当前区块信息为:"+block.toString());
        return this.block;
    }
    ...
}
```
之前区块中将字符串保存为区块信息，我们更新为一笔交易。需要创建一笔交易才可以创建区块。

### Coinbase

关于UTXO，我们之前讲到每一笔输出都会对应着一个输入，那么第一笔被输出的coin是哪里来的呢，
在比特币中，每产出一个区块将会奖励一定数量的BItcoin，称为Coinbase。同理，我们这里也实现它。
因此第一笔被输出的coin来自于coinbase。我们将coinbase固定为50，正如之前设定的属性:

```
#Transaction.java
    private transient static final int COINBASE = 50;
```

所以我们还需要一个生成coinbase的交易的构造方法:

```
#Blockchain.java
    public static Transaction newCoinBase() throws NoSuchAlgorithmException, Exception {
        Transaction t = new Transaction();
        t.tips = new ArrayList<>();
        t.tops.put(Wallet.getInstance().getAddress(), new TxOutput(COINBASE, Wallet.getInstance().getAddress()));
        LOGGER.info("创建Coinbase....."+t.toString());
        return t;
    }
```
可以看到，交易输出的地址我们设置为钱包的地址。
比较简单，接下来修改一下创世区块的生成方法，将coinbase的交易添加进去。

```
#Blockchain.java
    private Block CrtGenesisBlock() throws NoSuchAlgorithmException, Exception {
        // Block block = new Block(1,"Genesis Block","00000000000000000");
        Block block = new Block(1, Transaction.newCoinBase(), "00000000000000000");
        ...
    }
```

### 测试
一切都完成了，测试一下:

```
#Test.java
public class Test {
    public static void main(String[] args) throws NoSuchAlgorithmException, Exception {
        Blockchain.getInstance().addBlock(
            Transaction.newUTXO(
                Wallet.getInstance().getAddress(), "address", 30));
        Blockchain.getInstance().addBlock(
            Transaction.newUTXO(
                "address", "address1", 20));
    }
}
```
分析一下测试用例：

```
Blockchain.getInstance()
#############################
#Blockchain.java CrtGenesisBlock()
Block block = new Block(1, Transaction.newCoinBase(), "00000000000000000");
#newCoinBase()
t.tops.put(Wallet.getInstance().getAddress(), new TxOutput(COINBASE, Wallet.getInstance().getAddress()));
```

首先获取区块链实例，因此创建了创始区块，看上面的代码我们可以知道创建了一笔coinbase交易，50个coin被锁定在我们钱包的地址。

```
Blockchain.getInstance().addBlock(
            Transaction.newUTXO(
                Wallet.getInstance().getAddress(), "address", 30));
```

然后是第二个区块，我们创建了一个UTXO，从钱包的地址转移30个coin到地址``address``。

```
        Blockchain.getInstance().addBlock(
            Transaction.newUTXO(
                "address", "address1", 20));
```
最后是第三个区块，从地址``address``转移20个coin到地址``address1``.
测试一下：

```
...
[INFO ] 2020-05-18 14:10:19,501 method:org.xd.chain.transaction.Transaction.newCoinBase(Transaction.java:42)
创建Coinbase.....{"tips":[],"tops":{"R1363548f8946529dd73922b26547b6110f9159a30cc9b0474435c1c0db37842cd3c4100082182227e356c811830d6b5b56d862880b85f20355cfbc387641653a":{"lockScript":"R1363548f8946529dd73922b26547b6110f9159a30cc9b0474435c1c0db37842cd3c4100082182227e356c811830d6b5b56d862880b85f20355cfbc387641653a","value":50}}}
...
[INFO ] 2020-05-18 14:10:19,757 method:org.xd.chain.core.Blockchain.findAllUnspendableUTXO(Blockchain.java:117)
查找所有未消费的UTXO...............
[INFO ] 2020-05-18 14:10:19,804 method:org.xd.chain.wallet.Wallet.sign(Wallet.java:86)
使用私钥对数据签名: R1363548f8946529dd73922b26547b6110f9159a30cc9b0474435c1c0db37842cd3c4100082182227e356c811830d6b5b56d862880b85f20355cfbc387641653a
[INFO ] 2020-05-18 14:10:20,382 method:org.xd.chain.transaction.Transaction.newUTXO(Transaction.java:100)
创建UTXO: {"tips":[{"unLockScript":"523133363335343866383934363532396464373339323262323635343762363131306639313539613330636339623034373434333563316330646233373834326364336334313030303832313832323237653335366338313138333064366235623536643836323838306238356632303335356366626333383736343136353361%%%4251d1ae7091f422bef3a95b29867ebeaeeedb0e20239a4edf96967d1a1f15a8f061873acc01aa86c726e1ad128aefeaaf5c447aed27e5729bdd24f0026d6c23","values":50}],"tops":{"R1363548f8946529dd73922b26547b6110f9159a30cc9b0474435c1c0db37842cd3c4100082182227e356c811830d6b5b56d862880b85f20355cfbc387641653a":{"lockScript":"R1363548f8946529dd73922b26547b6110f9159a30cc9b0474435c1c0db37842cd3c4100082182227e356c811830d6b5b56d862880b85f20355cfbc387641653a","value":20},"address":{"lockScript":"address","value":30}}}
...
[INFO ] 2020-05-18 14:10:20,468 method:org.xd.chain.core.Blockchain.addBlock(Blockchain.java:86)
当前区块信息为:{"blkNum":2,"curBlockHash":"00005f0690489e8763bd3db0ce7112592cdb118507945c65d07bfe27e0ad3031","nonce":4350,"prevBlockHash":"000011de81afdac44e08e81b9be434cbcb625808a9d0f8008275ab9a6ffb809f","timeStamp":"2020-05-18 14:10:20","transaction":{"tips":[{"unLockScript":"523133363335343866383934363532396464373339323262323635343762363131306639313539613330636339623034373434333563316330646233373834326364336334313030303832313832323237653335366338313138333064366235623536643836323838306238356632303335356366626333383736343136353361%%%4251d1ae7091f422bef3a95b29867ebeaeeedb0e20239a4edf96967d1a1f15a8f061873acc01aa86c726e1ad128aefeaaf5c447aed27e5729bdd24f0026d6c23","values":50}],"tops":{"R1363548f8946529dd73922b26547b6110f9159a30cc9b0474435c1c0db37842cd3c4100082182227e356c811830d6b5b56d862880b85f20355cfbc387641653a":{"lockScript":"R1363548f8946529dd73922b26547b6110f9159a30cc9b0474435c1c0db37842cd3c4100082182227e356c811830d6b5b56d862880b85f20355cfbc387641653a","value":20},"address":{"lockScript":"address","value":30}}}}
[INFO ] 2020-05-18 14:10:20,575 method:org.xd.chain.core.Blockchain.findAllUnspendableUTXO(Blockchain.java:117)
查找所有未消费的UTXO...............
...
[INFO ] 2020-05-18 14:10:20,725 method:org.xd.chain.wallet.Wallet.verify(Wallet.java:124)
验证签名: address
...
[INFO ] 2020-05-18 14:10:20,731 method:org.xd.chain.wallet.Wallet.sign(Wallet.java:86)
使用私钥对数据签名: address
[INFO ] 2020-05-18 14:10:20,734 method:org.xd.chain.transaction.Transaction.newUTXO(Transaction.java:100)
创建UTXO: {"tips":[{"unLockScript":"61646472657373%%%8ad16095a9f1947e323eb5ef3601a0cc2ad552ad3f7331406123577a1cc0c68dc614f3262505f079f7c3acfc1d681fdb432f7ba0f4ac3d69cb46dead5446b2cd","values":30}],"tops":{"R1363548f8946529dd73922b26547b6110f9159a30cc9b0474435c1c0db37842cd3c4100082182227e356c811830d6b5b56d862880b85f20355cfbc387641653a":{"lockScript":"R1363548f8946529dd73922b26547b6110f9159a30cc9b0474435c1c0db37842cd3c4100082182227e356c811830d6b5b56d862880b85f20355cfbc387641653a","value":10},"address1":{"lockScript":"address1","value":20}}}
...
[INFO ] 2020-05-18 14:10:20,990 method:org.xd.chain.core.Blockchain.addBlock(Blockchain.java:86)
当前区块信息为:{"blkNum":3,"curBlockHash":"00006e8918bba9831374f578caa3d80fa936997598072145bc0654cbca2d084e","nonce":74607,"prevBlockHash":"00005f0690489e8763bd3db0ce7112592cdb118507945c65d07bfe27e0ad3031","timeStamp":"2020-05-18 14:10:20","transaction":{"tips":[{"unLockScript":"61646472657373%%%8ad16095a9f1947e323eb5ef3601a0cc2ad552ad3f7331406123577a1cc0c68dc614f3262505f079f7c3acfc1d681fdb432f7ba0f4ac3d69cb46dead5446b2cd","values":30}],"tops":{"R1363548f8946529dd73922b26547b6110f9159a30cc9b0474435c1c0db37842cd3c4100082182227e356c811830d6b5b56d862880b85f20355cfbc387641653a":{"lockScript":"R1363548f8946529dd73922b26547b6110f9159a30cc9b0474435c1c0db37842cd3c4100082182227e356c811830d6b5b56d862880b85f20355cfbc387641653a","value":10},"address1":{"lockScript":"address1","value":20}}}}
```

省略掉其他日志信息，看起来测试是没有问题的，共生成了3个区块。创世区块中有一笔Coinbase交易。区块2中成功转移30coin到地址``address``，返还20coin到原地址。区块3中成功从地址``address``转移20coin到地址``address1``，返还10coin到地址``address``。

还有部分未完善部分，比如coinbase只在创世区块中生成了。每个区块中只含有一笔交易等等，后期慢慢完善。

### Github仓库地址在这里，随时保持更新中.....
Github地址：[Jchain](https://github.com/newonexd/Jchain)