# 无线协议服务器测试程序 #
## 概要 ##
客户端发送的是二进制数据，服务器接收时，通过阻塞接收函数，以8bit一字节的方式接收并返回字符串。
提取数据要使用string.byte()。而部分BCD码，还需要再多一次转化。
