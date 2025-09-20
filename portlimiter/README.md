# PortLimiter

> 简易防火墙

## 前置条件

基于iptables

## 如何使用

```shell
mkdir -p portlimiter
cd portlimiter
curl -L -o banPorts.sh https://raw.githubusercontent.com/yiiilin/scripts/refs/heads/main/portlimiter/banPorts.sh
curl -L -o removePortLimit.sh https://raw.githubusercontent.com/yiiilin/scripts/refs/heads/main/portlimiter/removePortLimit.sh
chmod +x ./*.sh
# vim banPorts.sh, update limit rules
./banPorts.sh
```