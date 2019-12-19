---
title: Fabric1.4源码解析：链码容器启动过程
date: 2019-12-19 21:02:38
tags: fabric
categories: fabric源码解析
---
想写点东西记录一下最近看的一些Fabric源码,本文使用的是**fabric1.4**的版本，所以对于其他版本的fabric，内容可能会有所不同。
其实我仅仅知道Go语言一些语法的使用，并不太熟悉Go语言，所以解析的内容可能会有误，欢迎大家批评指正。
本文想针对Fabric中链码容器的启动过程进行源码的解析。这里的链码指的是用户链码不是系统链码,顺便回顾一下系统链码:
**lscc**(Life Cycle System ChainCode)生命周期系统链码
**cscc**(Configuration System ChainCode)配置系统链码
**escc**(Endorser System ChainCode)背书系统链码
**qscc**(Query System ChainCode)查询系统链码
**vscc**(Verification System ChainCode)验证系统链码
本文主要解析的是用户链码的启动过程。
## 1 起点
```
#这是用户端链码的main方法，也是整个流程的入口点，调用了shim包中的Start(cc Chaincode)方法.
func main(){
    err :=shim.Start(new(Chaincode))
    if err != nil {
        fmt.Printf("Error starting Chaincode: %s",err)
    }
}
```
首先定位到``fabric/core/chaincode/shim/chaincode.go``这个文件中的``Start``方法，这里是链码启动的起点。
可以看到传的参数就是chaincode,接下来分析一下启动过程
```
#方法中第一行代码，根据名字可以看出是对链码的Log进行设置
SetupChaincodeLogging()
#从输入中获取用户定义的链码的名称
chaincodename := viper.GetString("chaincode.id.name")
#如果没有输入链码名称，直接返回没有提供链码id的错误，下面则不再执行
if chaincodename == "" {
    return errors.New("error chaincode id not provided")
}
#看名字是一个工厂方法，点进行看一下
err := factory.InitFactories(factory.GetDefaultOpts())
```
首先进入到``factory.GetDefaultOpts()``方法中：
```
func GetDefaultOpts() *FactoryOpts {
	return &FactoryOpts{
		ProviderName: "SW",
		SwOpts: &SwOpts{
			HashFamily: "SHA2",   #HASH类型
			SecLevel:   256,    #HASH级别

			Ephemeral: true,
		},
	}
}
#可以猜到这个方法是获取默认的加密操作，使用SHA256进行数据加密
```
不难猜到``factory.InitFactories``这个方法就是为当前链码设置加密操作的一系列内容。回到``Start()``方法中接着往下看.
```
#这一部分就是将链码数据以流的方式读取进来，userChaincodeStreamGetter是一个方法，点进去看一下
if streamGetter == nil {
	streamGetter = userChaincodeStreamGetter
}
stream, err := streamGetter(chaincodename)
if err != nil {
	return err
}
```
``userChaincodeStreamGetter``还是在这个文件中第82行:
```
#这里的name是链码名称，读取到链码数据后以PeerChainCodeStream的方式返回
func userChaincodeStreamGetter(name string) (PeerChaincodeStream, error) {
    #获取peer.address
	flag.StringVar(&peerAddress, "peer.address", "", "peer address")
	//判断是否使能TLS
	if viper.GetBool("peer.tls.enabled") {
        #获取tls密钥地址，在用户安装链码的时候指定
		keyPath := viper.GetString("tls.client.key.path")
        #获取tls证书地址
		certPath := viper.GetString("tls.client.cert.path")
        #从文件中读取密钥数据
		data, err1 := ioutil.ReadFile(keyPath)
		if err1 != nil {
			err1 = errors.Wrap(err1, fmt.Sprintf("error trying to read file content %s", keyPath))
			chaincodeLogger.Errorf("%+v", err1)
			return nil, err1
		}
		key = string(data)
         #从文件中读取证书数据
		data, err1 = ioutil.ReadFile(certPath)
		if err1 != nil {
			err1 = errors.Wrap(err1, fmt.Sprintf("error trying to read file content %s", certPath))
			chaincodeLogger.Errorf("%+v", err1)
			return nil, err1
		}
		cert = string(data)
	}
    #解析命令行参数到定义的flag
	flag.Parse()
    #日志输出
	chaincodeLogger.Debugf("Peer address: %s", getPeerAddress())

	//与peer节点建立连接
	clientConn, err := newPeerClientConnection()
```
看一下这个方法里面的内容，还是这个文件第317行：
```
func newPeerClientConnection() (*grpc.ClientConn, error) {
    #首先获取到peer节点的地址
	var peerAddress = getPeerAddress()
    #看名字就知道了，设置与链码之间的心中信息
	kaOpts := &comm.KeepaliveOptions{
		ClientInterval: time.Duration(1) * time.Minute,
		ClientTimeout:  time.Duration(20) * time.Second,
	}
```
 判断是否使能了TLS，然后根据结果建立链接,如何建立链接就不再细看了，我们回到之前的部分
```
	if viper.GetBool("peer.tls.enabled") {
		return comm.NewClientConnectionWithAddress(peerAddress, true, true,
			comm.InitTLSForShim(key, cert), kaOpts)
	}
	return comm.NewClientConnectionWithAddress(peerAddress, true, false, nil, kaOpts)
}
```
还是之前的``userChaincodeStreamGetter``方法
```
clientConn, err := newPeerClientConnection()
	if err != nil {
		err = errors.Wrap(err, "error trying to connect to local peer")
		chaincodeLogger.Errorf("%+v", err)
		return nil, err
	}

	chaincodeLogger.Debugf("os.Args returns: %s", os.Args)

    #接下来是这个方法，返回一个ChaincodeSupportClient实例,对应着链码容器
	chaincodeSupportClient := pb.NewChaincodeSupportClient(clientConn)

	//这一步是与peer节点建立gRPC连接
	stream, err := chaincodeSupportClient.Register(context.Background())
	if err != nil {
		return nil, errors.WithMessage(err, fmt.Sprintf("error chatting with leader at address=%s", getPeerAddress()))
	}

	return stream, nil
}
```
这个方法结束之后，链码容器与Peer节点已经建立起了连接，接下来链码容器与Peer节点开始互相发送消息了。
返回到``Start()``方法中，还剩最后的一个方法``chatWithPeer()``：
```
	err = chatWithPeer(chaincodename, stream, cc)
	return err
}
```
看一下链码容器与Peer节点是如何互相通信的。这个方法是链码容器启动的过程中最重要的方法，包含所有的通信流程。``chatWithPeer()``在331行:
```
func chatWithPeer(chaincodename string, stream PeerChaincodeStream, cc Chaincode)
#传入的参数有链码名称，流(这个是之前链码容器与Peer节点建立gRPC连接所返回的)，链码
```
首先第一步是新建一个``ChaincodeHandler``对象：是非常重要的一个对象。看一下该对象的内容,在``core/chaincode/shim/handler.go``文件中第166行:
```
func newChaincodeHandler(peerChatStream PeerChaincodeStream, chaincode Chaincode) *Handler {
	v := &Handler{
		ChatStream: peerChatStream,   #与Peer节点通信的流
		cc:         chaincode,      #链码
	}
	v.responseChannel = make(map[string]chan pb.ChaincodeMessage)  #链码信息响应通道
	v.state = created     #表示将链码容器的状态更改为created
	return v    将handler返回
}
```
这个``ChaincodeHandler``对象是链码侧完成链码与Peer节点之前所有的消息的控制逻辑。
继续往下看：
```
#在方法执行结束的时候关闭gRPC连接
defer stream.CloseSend()
#获取链码名称
chaincodeID := &pb.ChaincodeID{Name: chaincodename}
#将获取的链码名称序列化为有效载荷.
payload, err := proto.Marshal(chaincodeID)
if err != nil {
	return errors.Wrap(err, "error marshalling chaincodeID during chaincode registration")
}
#日志输出,这个日志信息在安装链码的时候应该有看到过吧
chaincodeLogger.Debugf("Registering.. sending %s", pb.ChaincodeMessage_REGISTER)
#链码容器通过handler开始通过gRPC连接向Peer节点发送第一个消息了，链码容器向Peer节点发送REGISTER消息，并附上链码的名称
if err = handler.serialSend(&pb.ChaincodeMessage{Type: pb.ChaincodeMessage_REGISTER, Payload: payload}); err != nil {
		return errors.WithMessage(err, "error sending chaincode REGISTER")
	}
#定义一个接收消息的结构体
type recvMsg struct {
    msg *pb.ChaincodeMessage
	err error
}
msgAvail := make(chan *recvMsg, 1)
errc := make(chan error)

receiveMessage := func() {
	in, err := stream.Recv()
	msgAvail <- &recvMsg{in, err}
}
#接收由Peer节点返回的响应消息
go receiveMessage()
```
接下来的部分就是链码容器与Peer节点详细的通信过程了：
## 2链码侧向Peer节点发送REGISTER消息
```
#前面的部分都是接收到错误消息的各种输出逻辑，不再细看，我们看default这一部分，这一部分是正常情况下消息的处理情况：
for {
		select {
		case rmsg := <-msgAvail:
			switch {
			case rmsg.err == io.EOF:
				err = errors.Wrapf(rmsg.err, "received EOF, ending chaincode stream")
				chaincodeLogger.Debugf("%+v", err)
				return err
			case rmsg.err != nil:
				err := errors.Wrap(rmsg.err, "receive failed")
				chaincodeLogger.Errorf("Received error from server, ending chaincode stream: %+v", err)
				return err
			case rmsg.msg == nil:
				err := errors.New("received nil message, ending chaincode stream")
				chaincodeLogger.Debugf("%+v", err)
				return err
			default:
            #这一句日志输出应该看到过好多次吧。
				chaincodeLogger.Debugf("[%s]Received message %s from peer", shorttxid(rmsg.msg.Txid), rmsg.msg.Type)
                #重要的一个方法，在链码容器与Peer节点建立起了联系后，主要通过该方法对消息逻辑进行处理，我们点进行看一下。
				err := handler.handleMessage(rmsg.msg, errc)
				if err != nil {
					err = errors.WithMessage(err, "error handling message")
					return err
				}
                #当消息处理完成后，再次接收消息。
				go receiveMessage()
			}
        #最后是发送失败的处理
		case sendErr := <-errc:
			if sendErr != nil {
				err := errors.Wrap(sendErr, "error sending")
				return err
			}
		}
	}
```
一个重要的方法：``handleMessage``在``core/chaincode/shim/handler.go``文件第801行：
```
func (handler *Handler) handleMessage(msg *pb.ChaincodeMessage, errc chan error) error {
    #如果链码容器接收到Peer节点发送的心跳消息后，直接将心跳消息返回，双方就一直保持联系。
	if msg.Type == pb.ChaincodeMessage_KEEPALIVE {
		chaincodeLogger.Debug("Sending KEEPALIVE response")
		handler.serialSendAsync(msg, nil) // ignore errors, maybe next KEEPALIVE will work
		return nil
	}
    #我们先看到这里，如果再往下看的话可能会乱掉，所以还是按照逻辑顺序进行说明。
```
**先说一下链码侧所做的工作：**
* 首先进行各项基本配置，然后建立起与Peer节点的gRPC连接。
* 创建``Handler``,并更改``Handler``状态为``created``。
* 发送``REGISTER``消息到Peer节点。
* 等待Peer节点返回的信息
## 3Peer节点接收到REGISTER消息后
之前讲的都是链码侧的一系列流程，我们之前提到链码侧与Peer节点之间的第一个消息内容是由链码侧发送至Peer节点的``REGISTER``消息。接下来我们看一下Peer节点在接收到该消息后是如果进行处理的。
代码在``core/chaincode/handler.go``文件中第174行，这里不是处理消息的开始，但是对于我们要说的链码容器启动过程中消息的处理刚好衔接上，所以就直接从这里开始了。另外很重要的一点，这里已经转换到Peer节点侧了，不是之前说的链码侧，我们看一下代码：
```
func (h *Handler) handleMessage(msg *pb.ChaincodeMessage) error {
	chaincodeLogger.Debugf("[%s] Fabric side handling ChaincodeMessage of type: %s in state %s", shorttxid(msg.Txid), msg.Type, h.state)
	#这边也是首先判断是不是心跳信息，如果是心跳信息的话就什么也不做，与之前不同的是链码侧在收到心跳信息后会返回Peer节点一个心跳信息。
	if msg.Type == pb.ChaincodeMessage_KEEPALIVE {
		return nil
	}
    #之前我们提到，创建handler时，更改状态为created,所以这里进入到handleMessageCreatedState这个方法内.
	switch h.state {
	case Created:
		return h.handleMessageCreatedState(msg)
	case Ready:
		return h.handleMessageReadyState(msg)
	default:
		return errors.Errorf("handle message: invalid state %s for transaction %s", h.state, msg.Txid)
	}
}
```
``handleMessageCreatedState``这个方法在第191行,方法内容很简单，判断消息类型是不是REGISTER，如果是则进入HandlerRegister(msg)方法内，如果不是则返回错误信息。
```
func (h *Handler) handleMessageCreatedState(msg *pb.ChaincodeMessage) error {
	switch msg.Type {
	case pb.ChaincodeMessage_REGISTER:
		h.HandleRegister(msg)
	default:
		return fmt.Errorf("[%s] Fabric side handler cannot handle message (%s) while in created state", msg.Txid, msg.Type)
	}
	return nil
}
```
接下来我们看一下``HandleRegister``这个方法,在第495行：
```
func (h *Handler) HandleRegister(msg *pb.ChaincodeMessage) {
	chaincodeLogger.Debugf("Received %s in state %s", msg.Type, h.state)
	#获取链码ID
	chaincodeID := &pb.ChaincodeID{}
    #反序列化
	err := proto.Unmarshal(msg.Payload, chaincodeID)
	if err != nil {
		chaincodeLogger.Errorf("Error in received %s, could NOT unmarshal registration info: %s", pb.ChaincodeMessage_REGISTER, err)
		return
	}

	h.chaincodeID = chaincodeID
	#这一行就是将链码注册到当前Peer节点上
	err = h.Registry.Register(h)
	if err != nil {
		h.notifyRegistry(err)
		return
	}

	从Peer节点侧的handler获取链码名称
	h.ccInstance = ParseName(h.chaincodeID.Name)

	chaincodeLogger.Debugf("Got %s for chaincodeID = %s, sending back %s", pb.ChaincodeMessage_REGISTER, chaincodeID, pb.ChaincodeMessage_REGISTERED)
	#然后将REGISTERED消息返回给链码侧
	if err := h.serialSend(&pb.ChaincodeMessage{Type: pb.ChaincodeMessage_REGISTERED}); err != nil {
		chaincodeLogger.Errorf("error sending %s: %s", pb.ChaincodeMessage_REGISTERED, err)
		h.notifyRegistry(err)
		return
	}

	//更新handler状态为Established
	h.state = Established

	chaincodeLogger.Debugf("Changed state to established for %+v", h.chaincodeID)

	#还有这个方法也要看一下
	h.notifyRegistry(nil)
}
```
简单来说``HandleRegister``的功能就是将链码注册到Peer节点上，并发送``RESIGSERED``到链码侧，最后更新``handler``状态为``Established``，我们看一下``notifyRegistry``方法,在478行：
```
func (h *Handler) notifyRegistry(err error) {
	if err == nil {
		//再往里面看,方法在459行
		err = h.sendReady()
	}

	if err != nil {
		h.Registry.Failed(h.chaincodeID.Name, err)
		chaincodeLogger.Errorf("failed to start %s", h.chaincodeID)
		return
	}

	h.Registry.Ready(h.chaincodeID.Name)
}
#sendReady()
func (h *Handler) sendReady() error {
	chaincodeLogger.Debugf("sending READY for chaincode %+v", h.chaincodeID)
	ccMsg := &pb.ChaincodeMessage{Type: pb.ChaincodeMessage_READY}

	#Peer节点又向链码容器发送了READY消息
	if err := h.serialSend(ccMsg); err != nil {
		chaincodeLogger.Errorf("error sending READY (%s) for chaincode %+v", err, h.chaincodeID)
		return err
	}
	#同时更新handler状态为Ready
	h.state = Ready

	chaincodeLogger.Debugf("Changed to state ready for chaincode %+v", h.chaincodeID)

	return nil
}
```
到这里，Peer节点暂时分析完成，又到了链码侧对Peer节点发送的消息进行处理的流程.
**我们先总结一下这一部分Peer节点做了哪些工作：**
* 首先当Peer节点接收到链码侧发送的``REGISTER``消息后，将链码注册到Peer端的``Handler``上，发送``REGISTERED``到链码侧，更新``Handler``的状态为``Established``。
* 然后Peer节点向链码侧发送``READY``消息，同时更新``Handler``的状态为``Ready``。

## 4链码侧的回应
我们回到链码侧之前的这一部分``core/chaincode/chaincode.go``中第364行,这里是链码铡对接收到的Peer节点发送的消息进行处理的逻辑,至于发生错误的情况就不再说明，我们看``handleMessage``这个方法。
```
go receiveMessage()
	for {
           #相关代码
		...
		err := handler.handleMessage(rmsg.msg, errc)
		...
            #相关代码
				go receiveMessage()
	}
```
``handleMessage``这个方法在``core/chaincode/shim/handler.go``这个文件中，第801行。
```
#主要就是这一部分：
switch handler.state {
	case ready:
		err = handler.handleReady(msg, errc)
	case established:
		err = handler.handleEstablished(msg, errc)
	case created:
		err = handler.handleCreated(msg, errc)
	default:
		err = errors.Errorf("[%s] Chaincode handler cannot handle message (%s) with payload size (%d) while in state: %s", msg.Txid, msg.Type, len(msg.Payload), handler.state)
}
```
* 首先链码侧接收到Peer节点发送的``REGISTERED``消息后，这里链码侧的``handler``与Peer节点侧的``handler``并不是同一个，不要搞混了。判断当前链码侧``handler``的状态为``created``，进入到``handleCreated``方法中,在792行：
```
#将链码侧的handler的状态更改为established
if msg.Type == pb.ChaincodeMessage_REGISTERED {
	handler.state = established
	return nil
}
```
* 当链码侧接收到Peer节点发送的``READY``消息后，又一次进入上面的逻辑，由于链码侧的``handler``的状态已经更改为``established``,所以这次进入到``handleEstablished``方法中。在783行：
```
#然后将链码侧的handler的状态更改为ready
if msg.Type == pb.ChaincodeMessage_READY {
	handler.state = ready
	return nil
}
```
* 另外，当用户对链码进行实例化操作时，会通过Peer节点向链码侧发送``INIT``消息，这里涉及到背书过程，之后再对背书过程进行讨论，我们在这里只关注链码侧接收到``INIT``消息后的逻辑，还是``handleMessage``这个方法中：
```
#当判断到消息类型为INIT时，会执行这个方法。
handler.handleInit(msg, errc)
```
``handler.handleInit(msg, errc)``方法在第177行：
```
func (handler *Handler) handleInit(msg *pb.ChaincodeMessage, errc chan error) {
	go func() {
		var nextStateMsg *pb.ChaincodeMessage

		defer func() {
            #这一名相当于更新链码的状态
			handler.triggerNextState(nextStateMsg, errc)
		}()
        #判断错误信息
		errFunc := func(err error, payload []byte, ce *pb.ChaincodeEvent, errFmt string, args ...interface{}) *pb.ChaincodeMessage {
			if err != nil {
				// Send ERROR message to chaincode support and change state
				if payload == nil {
					payload = []byte(err.Error())
				}
				chaincodeLogger.Errorf(errFmt, args...)
				return &pb.ChaincodeMessage{Type: pb.ChaincodeMessage_ERROR, Payload: payload, Txid: msg.Txid, ChaincodeEvent: ce, ChannelId: msg.ChannelId}
			}
			return nil
		}
		#获取用户输入的参数
		input := &pb.ChaincodeInput{}
        #反序列化
		unmarshalErr := proto.Unmarshal(msg.Payload, input)
		if nextStateMsg = errFunc(unmarshalErr, nil, nil, "[%s] Incorrect payload format. Sending %s", shorttxid(msg.Txid), pb.ChaincodeMessage_ERROR.String()); nextStateMsg != nil {
			return
		}

		#ChaincodeStub应该很熟悉了,很重要的一个对象，包含一项提案中所需要的内容。在``core/chaincode/shim/chaincode.go``文件中第53行，有兴趣可以点进去看一下
		stub := new(ChaincodeStub)
        #这一行代码的意思就是将提案中的信息抽取出来赋值到ChaincodeStub这个对象中
       err := stub.init(handler, msg.ChannelId, msg.Txid, input, msg.Proposal)
       if nextStateMsg = errFunc(err, nil, stub.chaincodeEvent, "[%s] Init get error response. Sending %s", shorttxid(msg.Txid), pb.ChaincodeMessage_ERROR.String()); nextStateMsg != nil {
			return
	   }
       #这里的Init方法就是链码中所写的Init()方法，就不再解释了
       res := handler.cc.Init(stub)
       chaincodeLogger.Debugf("[%s] Init get response status: %d", shorttxid(msg.Txid), res.Status)
        #ERROR的值为500,OK=200，ERRORTHRESHOLD = 400，大于等于400就代表错误信息或者被背书节点拒绝。
		if res.Status >= ERROR {
			err = errors.New(res.Message)
			if nextStateMsg = errFunc(err, []byte(res.Message), stub.chaincodeEvent, "[%s] Init get error response. Sending %s", shorttxid(msg.Txid), pb.ChaincodeMessage_ERROR.String()); nextStateMsg != nil {
				return
			}
		}
        resBytes, err := proto.Marshal(&res)
		if err != nil {
			payload := []byte(err.Error())
			chaincodeLogger.Errorf("[%s] Init marshal response error [%s]. Sending %s", shorttxid(msg.Txid), err, pb.ChaincodeMessage_ERROR)
			nextStateMsg = &pb.ChaincodeMessage{Type: pb.ChaincodeMessage_ERROR, Payload: payload, Txid: msg.Txid, ChaincodeEvent: stub.chaincodeEvent}
			return
		}

		// Send COMPLETED message to chaincode support and change state
		nextStateMsg = &pb.ChaincodeMessage{Type: pb.ChaincodeMessage_COMPLETED, Payload: resBytes, Txid: msg.Txid, ChaincodeEvent: stub.chaincodeEvent, ChannelId: stub.ChannelId}
		chaincodeLogger.Debugf("[%s] Init succeeded. Sending %s", shorttxid(msg.Txid), pb.ChaincodeMessage_COMPLETED)
        #到这里就结束了，会调用上面的handler.triggerNextState(nextStateMsg, errc)方法，这个方法将初始化数据与COMPLETED状态发送至Peer节点。
	}()
}
```
这个方法还是比较简单的，一共做了这些事情：

* 获取用户的输入数据
* 新建一个``ChainCodeStub``对象，然后将用户输入的数据赋值给该对象
* 调用用户链码中的``Init()``方法
* 将所有数据封装成``ChainCodeMessage``，类型为``COMPLETED``,发送至Peer节点。

这个时候链码已经初始化完成，已经进入了可被调用(``invoke``)的状态.
之后的流程就差不多了，Peer节点发送``TRANSACTION``消息给链码侧，调用``Invoke()``方法，之后链码侧发送具体的调用方法到Peer节点，由Peer节点进行相应的处理，最后返回``RESPONSE``消息到链码侧，链码侧接收到``RESPONSE``消息后，返回``COMPLETED``消息到Peer节点。

## 5总结
到这里，Peer节点与链码侧的``handler``都处于``READY``状态,链码容器已经启动完成。最后总结一下整体的流程：

1. 通过用户端链码中的``main``方法，调用了``core/chaincode/shim/chaincode.go``中的``Start()``方法，从而开始了链码的启动。
2. 首先进行相关的配置比如基本的加密，证书的读取。
3. 创建与Peer节点之间的gRPC连接，创建``handler``实例。
4. 由链码容器向Peer节点发送第一个消息:``REGISTER``,然后等待接收由Peer节点发送的消息。如果接收到的是心跳消息，则向Peer节点返回心跳消息。
5. Peer节点接收到链码容器发送的``REGISTER``消息后，将其注册到Peer节点端的``handler``上。
6. Peer节点发送``REGISTERED``消息到链码侧，同时更新Peer节点端的``handler``状态为``Established``。
7. Peer节点发送``Ready``消息到链码侧，同时更新Peer节点端的``handler``状态为``Ready``。
8. 链码侧接收到由Peer节点发送的``REGISTERED``消息后，更新链码侧的``handler``状态为``Established``。
9. 链码侧接收到由Peer节点发送的``READY``消息后，更新链码侧的``handler``状态为``ready``。
10. 当用户执行实例化链码时，通过Peer节点向链码侧发送``INIT``消息。链码侧接收到``INIT``消息后，根据用户输入的参数进行实例化操作。实例化完成后，返回``COMPLETED``消息到Peer节点。
11. 到这里链码容器已经启动，可以对链码数据进行查询调用等操作了。

另外，阅读Fabric源码中有一些没有看明白或者分析有误的地方，还望大家能够批评指正。


最后附上参考文档：[传送门](https://legacy.gitbook.com/book/yeasy/hyperledger_code_fabric/details)
以及Fabric源码地址：[传送门](https://github.com/hyperledger/fabric)