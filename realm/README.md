# Realm

> 简单的快速配置端口转发脚本

## 前置条件

基于docker compose，所以需要先安装docker compose

如果是debian系统，可以用以下命令安装

```shell
bash <(curl -L https://raw.githubusercontent.com/yiiilin/scripts/refs/heads/main/docker/install_docker.sh)
```

## 如何使用

通过以下命令安装

一下命令即将本地的`11111`和`22222`端口，分别转发到`1.1.1.1:11111`和`2.2.2.2:22222`

```shell
bash <(curl -L https://raw.githubusercontent.com/yiiilin/scripts/refs/heads/main/realm/realm.sh) 0.0.0.0:11111-1.1.1.1:11111 0.0.0.0:22222-2.2.2.2:22222
```