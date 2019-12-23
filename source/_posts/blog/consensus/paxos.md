---
title: Paxos算法
date: 2019-12-23 13:26:27
tags: algorithm
categories: consensus
---
# 使Paxos变简单

**摘要**
Paxos算法，用英语说明时，变得非常简单。

## 1 介绍

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;人们一直认为，用于实现容错分布式系统的Paxos算法难以理解，可能是因为最初的演示文稿对许多读者来说是希腊文.事实上，它是分布式算法中最简单，最有效的方法之一。它的核心是共识算法。下一节将说明这种共识算法几乎不可避免地遵循了我们希望它满足的特性。最后一部分介绍了完整的Paxos算法，该算法是通过将共识直接应用于构建分布式系统的状态机方法而获得的，这种方法应该是众所周知的，因为它是有关分布式系统理论的最常被引用的文章的主题。

## 2 共识算法
### 2.1 问题

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;假设有一个可以提出值的进程的集合。共识算法确保只有一个提出的值被选中。如果没有值被提出，则没有值应该被选中。如果一个值被选中，那么所有过程应该能够`learn`被选中的值。共识需要满足以下要求：

* 只有被提出的值才可以被选中
* 被选中的只有一个值
* 除非一个值真正地被选中，否则某个进程不会去`learn`这个值。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们不会尝试指定精确的活动要求，然而，目标是确保最终存在一个值被选定。并且当一个值被选定时，进程最终会`learn`到这个值。
我们在共识算法中定义了三种角色：

* `proposers`
* `acceptors`
* `learners`

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在算法的实现中，某个进程可能同时担任多个角色，但是在这里不讨论角色到进程的映射关系。
假设角色之间通过发送消息进行通信。我们使用异步，非拜占庭模型：

* 角色以任意的速度执行，可能由于停止而宕掉，可能会重启。所有的角色可能在一个值被选中之后宕掉重启。除非宕掉再重启的角色可以记住某些信息，否则等重启后无法确定被选定的值。
* 消息可能要花很长时间才能被交付，可能会复制可能会丢失，但是都没有关系。

### 2.2 选择一个值

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;最简单的方式是存在单个的`acceptor`角色然后选择一个值。一个`proposer`发送一个`proposal`到`acceptor`，`acceptor`选择它接收到的第一个`proposal`的值。尽管简单，但是这种解决方案不能满足要求，因为如果`acceptor`宕掉将会使未来的步骤无法继续(单点故障)。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;所以，让我们尝试另外一种方式选择一个值。使用多个`acceptor`角色代替单个`acceptor`。一个`proposer`发送一个`proposal`值到`acceptor`角色的集合。`acceptor`可能会接受`proposal`的值。当足够多的`acceptor`接受了该值，则说明这个值被选择了。足够多是多少呢？为了确保只有一个值被选择。我们可以让足够多数量的一组包含任何大多数角色。因为任何两个足够多数量的组都至少有一个共同的接受者，所以如果一个接受者最多可以接受一个值，则此方法有效。
在没有失败或消息丢失的情况下，如果只有一个值由单个的`proposer`提出，我们想要这个值被选择，需要满足以下要求：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**P1**:**任何`acceptor`必须接受它收到的第一个`proposal`。**

但是这个要求会出现一个问题。如果在同一时间有多个不同的`proposer`提出多个值，将会导致这种状态：每一个`acceptor`将会接受到一个值，但是不存在一个被大多数成员接受的值。即使只提出了两个值。如果每一个都由一半的`acceptor`接受，当一个`acceptor`宕掉后，将无法确定哪一个值被选择。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**P1**和**被大多数的`acceptor`接受的值才能被选择**，这两个要求隐性说哦名了每一个`acceptor`都必须可以接受多个值。我们通过为每个`proposal`分配一个（自然）编号来跟踪接受者可以接受的不同提案，那么每一个`proposal`将由一个`proposal`序号和一个值组成。为了避免冲突，我们要求不同的`proposal`所含有的`proposal`序号都是不同的。如何做到这一点取决于实现方法。现在我们只是假设。当一个`proposal`的值被大多数`acceptor`接受，那么该值说明被选择。这种情况下，我们说该`proposal`被选择。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们允许多个`proposal`被选择。但是需要保证所有被选择的`proposal`具有相同的值。通过对`proposal`编号的归纳，足以保证：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**P2**：**如果一个值为*v*的`proposal`被选择，那么被选择的比该`proposal`编号大的`proposal`具有相同的值*v*。**

由于数字是完全有序的，因此条件P2保证了仅选择一个值的关键安全性。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;一个`proposal`要被选择，建议必须至少由一个`acceptor`接受。 因此，我们可以通过满足以下条件来满足P2：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**P2<sup>a</sup>**：**如果一个值为*v*的`proposal`被选择。那么由任意的`acceptor`接受的被选择的比该`proposal`编号大的`proposal`具有相同的值*v*。**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们始终保证**P1**来确保一些`proposal`被选择。因为通信是异步的。一个`proposal`可以被一些从没有接受到任何`proposal`的`acceptor`*c*选择。假设一个新的`proposer`刚刚启动就接受到一个高编号的且值不同的`proposal`。**P1**则要求*c*接受该`proposal`，因此不满足要求**P2<sup>a</sup>**.维持**P1**和**P2<sup>a</sup>**需要加强P2<sup>a</sup>为：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**P2<sup>b</sup>**:**如果一个值为*v*的`proposal`被选择，那么每一个由任意的`proposer`提出的编号高的`proposal`都具有相同的*v*。**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于一个`proposal`都需要在被任意`acceptor`接受之前都由`proposer`提出，因此满足了要求**P2<sub>b</sub>**，就满足了要求**P2<sub>a</sub>**,所以也就满足了**P2**。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;为了发现如何满足要求**P2<sup>b</sup>**,让我们考虑一下如何证明它成立。我们假设被选择的`proposal`具有编号*m*与值*v*并且表明证明任何发布的编号为*n*>*m*的`proposal`也具有值*v*。我们可以通过对*n*进行归纳来简化证明，因此可以证明`proposal`编号*n*在值*v*的附加假设下每个提案编号都在*m*..(*n*−1)区间内并且值为*v*，其中*i..j*表示从*i*到*j*的一组数字。为了选择编号为*m*的`proposal`，必须有一些由大多数`acceptor`组成的集合*C*，以便*C*中的每个`acceptor`都接受它。将其与归纳假设相结合，选择*m*的假设就意味着：
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*C*中的每个`acceptor`都接受了一个编号为*m*..(*n-1*)的`proposal`，并且任何`acceptor`接受的每个编号为*m*..(*n-1*)的`proposal`都具有值*v*。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由大多数成员组成的集合*s*，至少包括一个*C*中的成员。我们可以通过确保以下不变式得出结论：编号为*n*的`proposal`具有值*v*.
**P2<sup>c</sup>**:**对于任何值*v*和*n*，如果一个`proposal`具有编号*n*和值*v*，那么由主要`acceptor`组成的集合满足以下其中一个条件：**

* ***S*中的`acceptor`不会接受任何编号小于*n*的`proposal`。**
* ***S*中的`acceptor`接受的最大编号的`proposal`的值为*v*。**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;因此满足了**P2<sup>c</sup>**的不变式即满足了**P2<sup>b</sup>.**
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;为了维持**P2<sup>c</sup>**的不变式，`proposer`想要提出一个编号为*n*的`proposal`必须`learn`(如果有的话)已被或将要被大多数`acceptor`中的每个`acceptor`接受的编号小于*n*的最高编号的`proposal`。了解已经接受的`proposal`很容易；预测未来是否会被接受很难。`proposer`没有试图预测未来，而是通过提取不会有任何此类接受的承诺来控制未来。换句话说，`proposer`要求`acceptor`不接受任何其他编号小于*n*的`proposal`。 推导出以下用于发布提案的算法：

* **一个`proposal`选择编号为*n*的`proposal`并发送请求到包括半数以上个`acceptor`的集合，并要求得到以下其中一个回应：**
    1. **一个不会接受编号值小于*n*的`proposal`的承诺。**
    2. **如果`acceptor`已经接受过`proposal`，则相应已接受的小于编号*n*的最大编号的`proposal`。**

将该请求称为编号为*n*的`prepare`请求。

* **如果`proposer`接受到大部分`acceptor`的请求响应，那么可以提出一个编号为*n*且值为*v*的`proposal`。这里的*v*是请求响应中编号最高的`proposal`中的值。或者如果响应中没有任何`proposal`，那么该值将由`proposer`自由选择。**
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`proposer`通过发送`proposal`到包括半数以上个`acceptor`集合(需要与起初的请求集合不是同一个)，并期望接受该请求。将该请求称为`accept`请求。

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这里描述的是关于`proposer`的算法。关于`acceptor`呢？`acceptor`可以从`proposer`接收两种类型的请求：`prepare`和`accept`请求。`acceptor`可以忽略任何请求而不会影响安全性。 因此，我们仅需说何时才允许响应请求。它总是可以响应`prepare`请求。 如果它没有答应不接受，它可以响应`accept`请求，接受`proposal`。 换一种说法：

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**P1<sup>a</sup>**:**如果`acceptor`没有响应编号大于*n*的`prepare`请求那么可以接收一个编号为*n*的`proposal`。**

观察到**P1<sup>a</sup>**包含**P1**。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;我们现在拥有了一个完整的算法选择一个满足安全性要求的值-通过假设一个唯一的`proposal`编号。最终算法通过一个小的优化获得。
假设`acceptor`收到编号为*n*的`prepare`请求.但是已经响应过一个编号值大于*n*的`prepare`请求。因此承诺不会接受任何编号为*n*的新的`proposal`请求。这样，`acceptor`就没有理由响应新的`prepare`请求，因为它不会接受`proposer`想要发出的编号为*n*的`proposal`。 因此，我们让`acceptor`忽略这样的`prepare`请求。 我们也可以忽略它已经接受的`proposal`的`prepare`请求。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;通过这种优化，接受者只需要记住它曾经接受的编号最高的`proposal`以及它已响应的编号最高的`prepare`请求的数量。无论如何失败，**P2<sup>c</sup>**也必须保持不变，所以即使失败，接受者也必须记住该信息，然后重新启动。 请注意，只要`proposer`从不尝试发布具有相同编号的另一个`proposal`，它总是可以放弃该`proposal`并将其遗忘。
将`proposer`和`acceptor`的动作放在一起，我们看到该算法在以下两个阶段中运行：

**阶段一**：

1. **`proposer`选择一个编号为*n*的`proposal`并发送编号为*n*的`prepare`请求到大多数的`acceptor`。**
2. **如果`acceptor`接受了编号为*n*的`prepare`请求，并且编号*n*比接受到的任何`prepare`请求的编号都要大，那么将会响应它接受到的编号最大的`proposal`(如果有的话)到`proposer`并且承诺不再接受任何编号小于*n*的`proposal`。**

**阶段二**：

1. **如果`proposer`从大多数的`acceptor`接受到编号为*n*的请求响应。那么将会发送编号为*n*且值为*v*的`accept`请求到接受`prepare`请求的每一个`acceptor`。这里的*v*是所有`prepare`响应中编号最大的响应中的值。或者当`prepare`响应中没有`proposal`时，该值由自己选择。**
2. **如果`acceptor`接收到编号为*n*的`accept`请求，除非它已经响应了一个编号大于*n*的`prepare`请求，否则它将接受该`proposal`。**

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;一个`proposer`可以提出多个`proposal`，只要它遵循每个`proposal`的算法即可。 它可以随时在协议中间放弃`proposal`。(即使`proposal`的请求和/或响应可能在`proposal`被放弃很长时间后到达目的地，也可以保持正确性。)如果某个`proposer`已经开始尝试发布编号更大的`proposal`，那么放弃`proposal`可能是一个好主意。因此，如果某个`acceptor`忽略了`prepare`或者是`accept`请求，那是因为已经接受了一个编号更大的`prepare`请求。所以`acceptor`应该通知`proposer`放弃它的`proposal`。这是对性能的优化并且不会影响正确性。

### 2.3 `learn`一个被选择的值

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`learner`必须发现一个被大多数`acceptor`接受的`proposal`，才能`learn`被选择的值。最明显的算法是让每个`acceptor`在接受`proposal`时对所有`learner`做出回应，向他们发送`proposal`。这使`learner`能够尽快发现所选的值，但是它要求每个`acceptor`对每个`learner`做出回应-回应的数量等于`acceptor`数量与`learner`数量的乘积。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;非拜占庭式失败的假设使一个`learner`很容易从另一个`learner`那里发现一个值已经被接受。我们可以让`acceptor`以他们的接受来回应一个特别的`learner`，当选择了一个值时，后者又会通知其他`learner`。这种方法需要所有`learner`进行额外的一轮努力才能发现所选的值。它也不太可靠，因为特别的`learner`可能会失败。但是，它需要的响应数量仅等于`acceptor`数量和`learner`数量之和。
更一般而言，`acceptor`可以用他们对某些特别的`learner`的接受做出响应，然后当选择了某个值时，每个`learner`都可以通知所有`learner`。使用更多的特别的`learner`以更高的通信复杂性为代价提供更高的可靠性。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于消息丢失，一个值的被选择可能会没有`learner`会发现。`learner`可以向`acceptor`询问他们接受了哪些`proposal`，但是`acceptor`的失败可能使得无法知道大多数人是否接受了特定`proposal`。在这种情况下，`learner`只有在选择新`proposal`时才能发现什么值被选择。 如果`learner`需要知道是否一个值被选择，则可以使用上述算法让`proposer`发布`proposal`。

### 2.4 流程

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;很容易构造这样一个场景，在该场景中，两个`proposer`各自不断发布数量越来越多的`proposal`序列，而从未选择过一个。 `proposer`*p*完成阶段1的编号为*n1*的`proposal`。然后，另一个`proposer`*q*完成阶段1的编号*n2>n1*的`proposal`。 `proposer`*p*的第2阶段编号为*n1*的`proposal`请求被忽略，因为`acceptor`都承诺不接受任何编号少于*n2*的新`proposal`。 因此，`proposer`*p*又开始以编号为*n3>n2*的`proposal`进行阶段1，导致阶段2`proposer`*q*的请求被忽略,并一直持续下去。为了保证进度，必须选择特别的`proposer`作为尝试发布`proposal`的唯一`proposer`。 如果特别的`proposer`可以与大多数`acceptor`成功通信，并且使用的`proposal`编号大于已使用的`proposal`的编号，那么它将成功发布被接受的`proposal`。并在得知某个`proposal`具有更高`proposal`编号的请求后通过放弃`proposal`再试一次，特别的`proposer`最终将选择足够高的`proposal`编号。如果系统（`proposer`，`acceptor`和通信网络）能够正常工作，那么可以通过选举一个特别的`proposer`来实现活跃性。Fischer，Lynch和Pattererson的著名成果表明，一种可靠的选择`proposer`的算法必须使用随机性或实时性，例如使用超时。但是，无论选举成功与否，都会确保安全。

### 2.5 实现

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Paxos算法假设网络的进程。在其共识算法中，每个进程都扮演着`proposer`，`acceptor`和`learner`的角色。该算法选择一个`leader`，该`leader`同时扮演特别的`proposer`与特别的`learner`。Paxos共识算法正是上述算法，其中请求和响应作为普通消息发送。（响应消息带有相应的`proposal`编号，以防止混淆。）在故障期间保留的稳定存储用于维护`acceptor`必须记住的信息。`acceptor`在实际发送响应之前将其预期的响应记录在稳定的存储中。剩下的就是描述如何保证没有两个`proposal`编号相同的机制。不同的`proposer`从不相交的数字集中选择他们的数字，因此两个不同的`proposer`从不发布具有相同编号的`proposal`。 每个`proposer`（在稳定的存储中）都会记住尝试发布的编号最高的`proposal`，并从第1阶段开始使用比其已经使用过的`proposer`编号更高的`proposer`编号。

## 3 状态机的实现

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;实现分布式系统的一种简单方法是作为向中央服务器发出命令的客户端的集合。 服务器可以描述为以某种顺序执行客户端命令的确定性状态机。状态机具有当前状态。它通过将命令作为输入并产生输出和新状态来执行步骤。例如，分布式银行系统的客户可能是柜员，并且状态机状态可能由所有用户的帐户余额组成。 提现将通过执行状态机命令来执行，该命令会在且仅当余额大于提款金额时才减少帐户的余额，并产生旧余额和新余额作为输出。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果单个中央服务器发生故障，则该服务器的实施将失败。因此，我们改为使用服务器的集合，每个服务器独立实现状态机。 因为状态机是确定性的，所以如果所有服务器都执行相同的命令序列，则所有服务器将产生相同的状态序列和输出。 然后，发出命令的客户端可以使用任何服务器为其生成的输出。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;为了确保所有服务器执行相同的状态机命令序列，我们实现了Paxos共识算法的不同实例序列，第i个实例选择的值是序列中的第i个状态机命令。每个服务器在算法的每个实例中扮演所有角色(`proposer`，`acceptor`和`learner`)。现在，假设服务器组是固定的，因此共识算法的所有实例使用相同的角色。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;在正常操作中，将选择一台服务器作为`leader`，在共识算法的所有实例中均充当特别的`proposer`(尝试发布`proposal`的唯一的`proposer`)。 客户将命令发送给`leader`，`leader`决定每个命令应出现的顺序。如果`leader`确定某个客户命令应为第135个命令，则它将尝试选择该命令作为共识算法的第135个实例的值。通常会成功。 它也可能由于故障而失败，或者因为另一台服务器也认为自己是`leader`并且认为另一条客户端命令应该为第135条命令。但是共识算法确保最多可以选择一个命令作为第135个命令。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;这种方法的效率的关键在于，在Paxos共识算法中，直到第2阶段才选择要提出的值。回想一下，在完成`proposer`算法的第1阶段之后，要么确定了要提出的值，要么提议者可以自由提出任何价值。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;现在，将描述Paxos状态机实现在正常操作期间如何工作。稍后，将讨论可能出问题的地方。 考虑当前任`leader`刚刚失败并选择了新`leader`时会发生什么。(系统启动是一种特殊情况，其中尚未提出任何命令。)
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;新的`leader`，在共识算法的所有情况下都是`learner`，应该知道已经选择的大多数命令。 假设它知道命令1–134、138和139，即共识算法实例1–134、138和139中选择的值。(将在后面看到如何在命令序列中出现这样的间隙.)然后，它执行实例135-137和大于139的所有实例的阶段1。(在下面描述如何做到这一点.)假设这些执行确定了在实例135和140中要提出的值，但在所有其他情况下都不受约束。领导者然后对实例135和140执行阶段2，从而选择命令135和140。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`leader`以及`learn``leader`知道的所有命令的任何其他服务器现在可以执行命令1–135。但是，它无法执行它也知道的命令138-140，因为尚未选择命令136和137。`leader`可以将客户请求的下两个命令作为命令136和137。相反，我们通过建议一个特殊的`no-op`命令作为命令136和137，使状态保持不变，从而立即填补了空白。（这是通过执行共识算法实例136和137的阶段2来完成的。）一旦选择了这些`no-op`命令，就可以执行命令138-140。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;现在已选择命令1–140。`leader`还已经为大于共识算法140的所有实例完成了阶段1，并且可以自由地在那些实例的阶段2中提出任何值。它将命令号141分配给客户端请求的下一个命令，并建议将其作为共识算法实例141的阶段2中的值。 它提出了接收到的下一个客户端命令作为命令142，依此类推。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`leader`可以在获悉已选择其提出的命令141之前提出命令142。 它在提议命令141中发送的所有消息都可能丢失，并且有可能在任何其他服务器了解`leader`作为命令141提出的建议之前选择命令142。当`leader`未能收到在实例141中的消息对其阶段2的预期响应时，它将重传那些消息。如果一切顺利，将选择其建议的命令。但是，它可能失败，从而在选择的命令序列中留下空白。通常，假设`leader`可以提前获得α命令-也就是说，在选择命令`1`至`i`之后，它可以提出命令`i+1`至`i+α`。最多可能会出现`α-1`命令的间隔。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;对于实例135-137和大于139的所有实例,新选择的`leader`在上面的方案中使用共识算法执行第1阶段的次数不限。它对所有实例使用相同的编号，可以通过向其他服务器发送一条合理的短消息来实现此目的。在阶段1中，只有在`acceptor`已经从某个`proposer`那里收到阶段2消息的情况下，接受者才用简单的OK做出响应.(仅对于实例135和140是这种情况.)因此，服务器(充当`acceptor`)可以使用单个合理的短消息对所有实例进行响应。 因此，执行这些无限多个阶段1实例不会带来任何问题。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;由于`leader`失败选举新`leader`的情况很少见，因此执行状态机命令的有效成本（即，对命令/值达成共识）是仅执行共识算法第二阶段的成本。可以证明，存在故障时达成共识的任何算法的最小可能成本在Paxos共识算法的第2阶段。 因此，Paxos算法本质上是最佳的。
对系统正常运行的讨论假定只有一个`leader`，除了在当前`leader`失败和选举新`leader`之间的短暂时间之外。 在异常情况下，`leader`选举可能会失败。如果没有服务器充当`leader`，则不会提出新命令。如果多个服务器认为自己是`leader`，则它们都可以在同一共识算法实例中提出值，这可能会阻止选择任何值。但是，安全性得以保留-两个不同的服务器将永远不会在选择作为第i个状态机命令的值上发生分歧。仅选举一位`leader`才能确保取得进展。
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;如果服务器组可以更改，则必须采用某种方法确定哪些服务器实现共识算法的哪些实例。最简单的方法是通过状态机本身。 当前服务器集可以成为状态的一部分，并且可以通过普通的状态机命令进行更改。我们可以允许`leader`提前获得`α`命令,通过让执行第`i`个状态机命令后的状态指定执行共识算法的实例`i+α`的服务器集。这允许任意复杂的重新配置算法的简单实现。