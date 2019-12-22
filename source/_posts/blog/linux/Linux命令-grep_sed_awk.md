---
title: Linux命令-grep,sed,awk
date: 2019-12-22 14:59:39
tags: Linux
categories: Linux命令
---
# grep

* * *

(global search regular expression[RE] and print out the line)
正则表达式全局搜索并将行打印出来

* 在文件中查找包含字符串"text"的行

```
grep text local_file
grep "text" local_file #另一种方式
grep "text" local_file1 local_file2 ...  #查找多个文件
```

* 在文件中查找**不**包含字符串"text"的行

```
grep -v "text" local_file
```

* **忽略大小写**

```
grep -i "TeXt" local_file
grep -y "TeXt" local_file
```

* **不显示错误信息**，常用于脚本文件中

```
grep -s "text" local_file
```

* **只打印出匹配到的字符串**

```
grep -o "text" local_file
```

* **统计文件中有多少行包含需要查找的字符串**

```
grep -c "text" local_file
```

*  **不输出信息**，命令运行成功返回0.失败返回非0值，用于判断

```
grep -q "text" local_file
```

* 匹配多个字符串,相当于逻辑中的或

```
grep -e "text1" -e "text2" local_file
```

* **递归查找**，用于多级目录中的文件

```
grep -r "text" . #在当前目录下进行查找
```

* 输出匹配需要查找字符串的行以及**之前**的行

```
grep "text" -B 3 local_file #输出之前的3行
```

* 输出匹配需要查找字符串的行以及**之后**的行

```
grep "text" -A 3 local_file #输出之后的3行
```

# sed

* * *
流编辑器，用来编辑一个或者多个文件，简化对文件的重复操作。在缓冲区内操作，除非特别指定，不对文件本身内容进行修改。

## `-i`
对文件本身进行修改
## `-q`
* 打印出第2行后退出`sed`

```
sed '2q' local_file
```

## 查找
* 查找第2-5行数据

```
sed '2,5p' local_file
sed -n '2,5p' local_file #并打印行号
```

* 查找包含字符串"text"的行与包含字符串"file"的行范围内的行

```
sed '/text/,/file/p' local_file
```

* 查找从第2行开始一直到以字符串"text“开头的行之间的所有行

```
sed '2,/^text/p' local_file
```

## 添加
* 在第2行后面一行添加字符串"text"

```
sed '2a text' local_file
```

* 在第二行前面一行添加字符串"text"

```
sed '2i text' local_file
```

* 在每一个单词前面加上字符"a":

```
sed 's/\w\+/a&/g'  # \w\+匹配每一个单词 &对应之前匹配的每一个单词
```

## 替换
* 替换字符串`file`为`files`

```
sed 's/file/files/g' local_file #打印到控制台，不修改文件
sed 's:file:file:g' local_file # /标记可以使用其他符号代替
sed -i 's/file/files/g' local_file #修改文件本身内容，不打印到控制台
```

* 替换第2-5行为字符串"text"

```
sed '2,5c text' local_file
```

## 删除

* 删除文件内的第2-5行

```
sed '/2,5/d' local_file
```

* 删除开头字符串为"text"的行

```
sed '/^text.*//g' local_file
sed '/^text/'d local_file
```

* 删除最后一行

```
sed '$d' local_file
```

* 删除空白行

```
sed '/^$/d' local_file
```
# awk

* * *

* 打印每一行的第2，3列数据

```
awk '{print $2,$3}' local_file
```