#!/bin/bash
set -ex

cd "$(dirname "$0")"

# 白名单模式或者黑名单模式
# whitelist or banlist
# mode should be 'allow' or 'ban'
defaultMode="ban"

# 默认协议
# default protocol
# tcp or udp
defaultProtocol="tcp"

# 限制规则
# limit rules
# [IP,(IP|IP1-IP2):]port[(-ports|,port2)][/protocol][#mode]
# IP:端口，范围端口使用-表示范围，如：15000:20000
# 中括号表示可选参数
# 多个规则使用&分割
# 例如：
#   192.168.44.84,192.168.44.85,192.168.44.86:20000-30000/tcp#allow
#   20000到30000的tcp端口，仅允许192.168.44.84和192.168.44.85和192.168.44.86访问，其他IP不允许访问
# 或者：
#   192.168.44.84-192.168.44.86,192.168.44.88:20000,30000,40000-50000/udp#ban
#   20000和30000和40000到50000的udp端口，不允许192.168.44.84和192.168.44.85和192.168.44.86和192.168.44.88访问，其他IP允许访问
rules="192.168.44.84,192.168.44.85,192.168.44.86:20000-30000/tcp#allow&192.168.55.155:22/tcp#allow&44&55"

action=""
defaultAction=""
if [ "$defaultMode" == "ban" ]; then
  action="DROP"
  defaultAction="ACCEPT"
elif [ "$defaultMode" == "allow" ]; then
  action="ACCEPT"
  defaultAction="DROP"
else
  echo "invalid mode, mode should be 'allow' or 'ban'"
  exit 1
fi

IFS="&" read -r -a ruleArray <<<"$rules"

# clear old rules
./removePortLimit.sh
rm -f /etc/portLimits.sh

# new rules chain
# allow lo to access
cat >>/etc/portLimits.sh <<EOF
iptables -w -t mangle -N CUSTOM_INPUT_FILTER
iptables -w -t mangle -A CUSTOM_INPUT_FILTER -s 127.0.0.1 -j ACCEPT
EOF

# allow 172.0.0.0/8 to access
cat >>/etc/portLimits.sh <<EOF
iptables -w -t mangle -A CUSTOM_INPUT_FILTER -s 172.0.0.0/8 -j ACCEPT
EOF

# allow current hostname to access
for i in $(hostname -I); do
  cat >>/etc/portLimits.sh <<EOF
iptables -w -t mangle -A CUSTOM_INPUT_FILTER -s $i -j ACCEPT
EOF
done

function handleRules() {
  if [[ $1 =~ ^(([0-9.]+((,[0-9.]+)|(-[0-9.]+))*):)?([0-9]+((,[0-9]+)|(-[0-9]+))*)(/([a-zA-Z]+))?(#([a-zA-Z]+))?$ ]]; then
    local ipArray=()
    local portArray=()
    local protocol="$defaultProtocol"
    local mode="$defaultMode"
    # 提取IP部分并分割成数组
    IFS="," read -r -a ipArray <<<"${BASH_REMATCH[2]}"

    # 提取端口部分并分割成数组
    IFS="," read -r -a portArray <<<"${BASH_REMATCH[6]}"

    # 提取protocol参数
    if [[ "${BASH_REMATCH[11]}" != "" ]]; then
      protocol="${BASH_REMATCH[11]}"
    fi

    # 提取mode参数
    if [[ "${BASH_REMATCH[13]}" != "" ]]; then
      mode="${BASH_REMATCH[13]}"
    fi

    # 输出结果
    echo "IP Array: ${ipArray[*]}"
    echo "Port: ${portArray[*]}"
    echo "Protocol: $protocol"
    echo "Mode: $mode"

    # 协议规则
    protocolRule="-p $protocol"

    # ip规则
    local ipRules=()
    for ip in "${ipArray[@]}"; do
      if [[ $(echo "$ip" | grep -c '-') -ne 0 ]]; then
        ipRules+=("-m iprange --src-range $ip")
      else
        ipRules+=("-s $ip")
      fi
    done

    # 端口规则
    local portRules=()
    for port in "${portArray[@]}"; do
      portRules+=("--dport ${port//-/:}")
    done

    # 策略规则
    actionRule="-j $action"
    if [[ "${mode}" != "" ]]; then
      if [[ "${mode}" == "allow" ]]; then
        actionRule="-j ACCEPT"
      elif [[ "${mode}" == "ban" ]]; then
        actionRule="-j DROP"
      else
        echo "invalid mode, mode should be 'allow' or 'ban'"
        exit 1
      fi
    fi

    # 写入文件
    for portRule in "${portRules[@]}"; do
      if [[ ${#ipArray[*]} -eq 0 ]]; then
        cat >>/etc/portLimits.sh <<EOF
iptables -w -t mangle -A CUSTOM_INPUT_FILTER ${protocolRule} ${portRule} ${actionRule}
EOF
      else
        for ipRule in "${ipRules[@]}"; do
          cat >>/etc/portLimits.sh <<EOF
iptables -w -t mangle -A CUSTOM_INPUT_FILTER ${protocolRule} ${ipRule} ${portRule} ${actionRule}
EOF
        done
      fi
    done
  else
    echo "invalid rule: $1"
    exit 1
  fi
}

# parse rules
for i in "${ruleArray[@]}"; do
  handleRules "$i"
done

# allow icmp access
# allow not syn tcp segment access
# set default rule
# insert custom rules chain
cat >>/etc/portLimits.sh <<EOF
iptables -w -t mangle -I CUSTOM_INPUT_FILTER -p icmp -j ACCEPT
iptables -w -t mangle -A CUSTOM_INPUT_FILTER -p tcp ! --syn -j ACCEPT
iptables -w -t mangle -A CUSTOM_INPUT_FILTER -j $defaultAction
iptables -w -t mangle -I PREROUTING -j CUSTOM_INPUT_FILTER
exit 0
EOF

chmod +x /etc/portLimits.sh
sed -i '/exit 0/d' /etc/rc.local
echo "/etc/portLimits.sh" >>/etc/rc.local
echo 'exit 0' >>/etc/rc.local
chmod +x /etc/rc.local
/etc/portLimits.sh

iptables -t mangle -nL CUSTOM_INPUT_FILTER
