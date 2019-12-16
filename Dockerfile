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

RUN echo "export JAVA_HOME=/usr/local/jdk1.8.0_231" >> /etc/profile && \
	echo "export JRE_HOME=$JAVA_HOME/jre" >> /etc/profile && \
	echo "export CLASSPATH=.:$JAVA_HOME/lib:$JRE_HOME/lib" >> /etc/profile && \
	echo "export PATH=$PATH:$JAVA_HOME/bin" >> /etc/profile 

# 拷贝配置文件
COPY config/* /tmp/
#strom 状态数据存放目录
RUN mkdir /usr/local/strom/workspace

RUN mv /tmp/zoo.cfg $ZOO_HOME/conf/zoo.cfg && \
	mv /tmp/log4j.properties $ZOO_HOME/conf/log4j.properties  && \
	cp -rf /tmp/zkEnv.sh $ZOO_HOME/bin/zkEnv.sh 
