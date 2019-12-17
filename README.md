参考https://blog.csdn.net/smile_caijx/article/details/81229633
制作Dockerfile
---------------------------------------------------------------------------------------------------------------------------------------
FROM ubuntu:14.04

MAINTAINER lennyhuang <524180539@qq.com>

WORKDIR /root

#基础环境优化，openssh，java， vim等 ，strom 2.1 需要java8和python2.6以上版本
# install openssh-server and wget
RUN apt-get update && apt-get install -y openssh-server  wget python2.7 
# 升级vim -y的作用是在执行过程中询问yes or no 时选yes
RUN apt-get remove -y vim-common && apt-get install -y vim


COPY softs/* /root/

# install jdk1.8.0_231
RUN tar -xzvf jdk-8u231-linux-x64.tar.gz && \
    mv jdk1.8.0_231 /usr/local/jdk1.8.0_231 && \
	chmod 777 /usr/local/jdk1.8.0_231 && \
    rm jdk-8u231-linux-x64.tar.gz

	
# install zookeeper-3.4.10 
# wget  http://apache.fayea.com/zookeeper/zookeeper-3.4.14/zookeeper-3.4.14.tar.gz && \
RUN tar -xzvf zookeeper-3.4.10.tar.gz && \
    mv zookeeper-3.4.10 /usr/local/zookeeper && \
	chmod 777 /usr/local/zookeeper && \
	mkdir /usr/local/zookeeper/data && \
	mkdir /usr/local/zookeeper/logs && \
    rm zookeeper-3.4.10.tar.gz
	


# install apache-storm-2.1.0
#wget  http://mirrors.tuna.tsinghua.edu.cn/apache/storm/apache-storm-2.1.0/apache-storm-2.1.0.tar.gz && \
RUN tar -xzvf apache-storm-2.1.0.tar.gz && \
    mv apache-storm-2.1.0 /usr/local/strom && \
	chmod 777 /usr/local/strom && \
    rm apache-storm-2.1.0.tar.gz

		
	
# set environment variable


ENV JAVA_HOME=/usr/local/jdk1.8.0_231 
ENV JRE_HOME=$JAVA_HOME/jre
ENV CLASSPATH=.:$JAVA_HOME/lib:$JRE_HOME/lib
ENV PATH=$PATH:JAVA_HOME/bin
ENV ZOO_HOME=/usr/local/zookeeper
ENV PATH=$PATH:ZOO_HOME/bin
ENV STROM_HOME=/usr/local/strom
ENV PATH=$PATH:STROM_HOME/bin
# dockerfile 中的env设置完环境变量，java 命令不生效，故 配置/etc/profile。但dockerfile不支持 source /etc/profile
# 要进入容器后运行source /etc/profile
RUN echo "export JAVA_HOME=/usr/local/jdk1.8.0_231" >> /etc/profile && \
	echo "export JRE_HOME=$JAVA_HOME/jre" >> /etc/profile && \
	echo "export CLASSPATH=.:$JAVA_HOME/lib:$JRE_HOME/lib" >> /etc/profile && \
	echo "export PATH=$PATH:$JAVA_HOME/bin" >> /etc/profile && \
	cat "source /etc/profile">>/root/.bashrc

# 拷贝配置文件
COPY config/* /tmp/
#strom 状态数据存放目录
RUN mkdir /usr/local/strom/workspace

RUN mv /tmp/zoo.cfg $ZOO_HOME/conf/zoo.cfg && \
	mv /tmp/log4j.properties $ZOO_HOME/conf/log4j.properties  && \
	cp -rf /tmp/zkEnv.sh $ZOO_HOME/bin/zkEnv.sh 
---------------------------------------------------------------------------------------------------------------------------------------


#1、制作strom镜像

docker build -t lenny/strom:2.1 .

#2、启动容器一个nimbus 2个supervisor 。三个节点均启动zookeeper

docker run -itd  -p 9088:8080  -p 6627:6627 -p 3181:2181 -p 8123:8000 --restart=always --name strom-nimbus --hostname strom-nimbus lenny/strom:2.1 &> /dev/null
docker run -itd  -p 9088:8080  -p 6627:6627 -p 3181:2181 -p 8123:8000 --restart=always --name strom-supervisor1 --hostname strom-supervisor1 lenny/strom:2.1 &> /dev/null
docker run -itd  -p 9088:8080  -p 6627:6627 -p 3181:2181 -p 8123:8000 --restart=always --name strom-supervisor2 --hostname strom-supervisor2 lenny/strom:2.1 &> /dev/null

#3、修改三台机器的hosts ，使其互通

docker inspect strom-nimbus | grep IPAddress | awk 'NR==2 {print $0}'
docker inspect strom-supervisor1 | grep IPAddress | awk 'NR==2 {print $0}'
docker inspect strom-supervisor2 | grep IPAddress | awk 'NR==2 {print $0}'

#修改hosts文件，可以在制作容器的时候直接加上
run_hosts.sh
#!/bin/bash
echo 192.168.2.199 strom-nimbus >> /etc/hosts
echo 192.168.2.135 strom-supervisor1 >> /etc/hosts
echo 192.168.2.70 strom-supervisor2 >> /etc/hosts

#4、分别在每台机器上配置好zookeeper

#1）首先  source /etc/profile 使java命令生效

nimbus节点 echo "1" >> /usr/local/zookeeper/data/myid
supervisor1节点 echo "2" >> /usr/local/zookeeper/data/myid
supervisor2节点 echo "3" >> /usr/local/zookeeper/data/myid

#2）然后修改Zookeeper配置文件zoo.cfg 已经在Dockerfile中直接处理

#3）分别启动3个节点上的zookeeper 并查看状态 bin/zkServer.sh start 查看zookeeper的状态 bin/zkServer.sh status

#4）最后验证zookeeper集群

bin/zkCli.sh -server strom-nimbus:2181

#5）配置并启动storm，修改conf/storm.yaml    2.1版本后nimbus.seeds 代替nimbus.hosts

#nimbus：

storm.zookeeper.servers:
     - "strom-nimbus"
     - "strom-supervisor1"
     - "strom-supervisor2"
nimbus.seeds: ["strom-nimbus"]
storm.local.dir: "/usr/local/strom/workspace/"
supervisor.slots.ports:
     - 6700
     - 6701
     - 6702
     - 6703
ui.port: 8080

#supervisor1:

storm.zookeeper.servers:
     - "strom-nimbus"
     - "strom-supervisor1"
     - "strom-supervisor2"
nimbus.seeds: ["strom-nimbus"]
storm.local.dir: "/usr/local/strom/workspace/"
supervisor.slots.ports:
     - 6700
     - 6701
     - 6702
     - 6703
	 
#supervisor2:

storm.zookeeper.servers:
     - "strom-nimbus"
     - "strom-supervisor1"
     - "strom-supervisor2"
nimbus.seeds: ["strom-nimbus"]
storm.local.dir: "/usr/local/strom/workspace/"
supervisor.slots.ports:
     - 6700
     - 6701
     - 6702
     - 6703


#nimbus：启动ui，nimbus和supervisor

./storm ui > /dev/null 2>&1 &
./storm nimbus > /dev/null 2>&1 &
./storm logviewer > /dev/null 2>&1 &
./storm supervisor > /dev/null 2>&1 &

#supervisor：启动supervisor 和logviewer

./storm logviewer > /dev/null 2>&1 &
./storm supervisor > /dev/null 2>&1 &


访问http://192.168.100.220:9088/ 控制台

#提交作业到集群
./storm jar storm-helloworld-0.0.1-SNAPSHOT.jar com.roncoo.eshop.storm.WordCountTopology WordCountTopology
#杀掉拓扑
./storm kill WordCountTopology

