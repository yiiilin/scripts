#!/bin/bash
set -ex

cd "$(dirname "$0")"

# 白名单模式或者黑名单模式
# whitelist or banlist
# mode should be 'allow' or 'ban'
defaultMode="allow"

# 默认协议
# default protocol
# tcp or udp or all
defaultProtocol="all"

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
rules="192.168.44.80&44&55&192.168.44.84,192.168.44.85,192.168.44.86:20000-30000/tcp#allow&192.168.55.155:22/tcp#allow"

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
  local rule="$1"
  
  # 判断是否是纯数字（端口）
  if [[ "$rule" =~ ^[0-9]+$ ]]; then
    echo "纯端口规则: $rule"
    handlePortRule "$rule" "" "$defaultProtocol" "$defaultMode"
    return
  fi
  
  # 判断是否是IP地址（包含点但不包含冒号、斜杠和井号）
  if [[ "$rule" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+([,-][0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)*$ ]] && 
     [[ ! "$rule" =~ [:/#] ]]; then
    echo "纯IP规则: $rule"
    handlePortRule "" "$rule" "$defaultProtocol" "$defaultMode"
    return
  fi
  
  # 判断是否包含点（IP地址）和可能的端口、协议、模式
  if [[ "$rule" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "包含IP的复杂规则: $rule"
    # 使用正则表达式匹配IP:端口/协议#模式格式
    if [[ "$rule" =~ ^(([0-9.]+(-[0-9.]+)?)(,([0-9.]+(-[0-9.]+)?))*:)?([0-9]+(-[0-9]+)?)(,([0-9]+(-[0-9]+)?))*(/(tcp|udp|all))?(#(allow|ban))?$ ]]; then
      local ipPart="${BASH_REMATCH[1]%:}"  # 去掉末尾的冒号
      local portPart="${BASH_REMATCH[7]}"
      local protocolPart="${BASH_REMATCH[13]}"
      local modePart="${BASH_REMATCH[15]}"
      
      local protocol="$defaultProtocol"
      local mode="$defaultMode"
      
      if [ -n "$protocolPart" ]; then
        protocol="$protocolPart"
      fi
      
      if [ -n "$modePart" ]; then
        mode="$modePart"
      fi
      
      handlePortRule "$portPart" "$ipPart" "$protocol" "$mode"
      return
    fi
  fi
  
  # 如果都不匹配，尝试作为端口规则处理
  echo "尝试作为端口规则处理: $rule"
  handlePortRule "$rule" "" "$defaultProtocol" "$defaultMode"
}

function handlePortRule() {
  local portPart="$1"
  local ipPart="$2"
  local protocol="$3"
  local mode="$4"
  
  local ipArray=()
  local portArray=()
  
  # 处理IP部分
  if [ -n "$ipPart" ]; then
    IFS="," read -r -a ipArray <<<"$ipPart"
  fi
  
  # 处理端口部分
  if [ -n "$portPart" ]; then
    IFS="," read -r -a portArray <<<"$portPart"
  fi
  
  # 输出结果
  echo "IP Array: ${ipArray[*]}"
  echo "Port: ${portArray[*]}"
  echo "Protocol: $protocol"
  echo "Mode: $mode"

  # 处理协议为'all'的情况
  local protocols=()
  if [ "$protocol" == "all" ]; then
    protocols=("tcp" "udp")
  else
    protocols=("$protocol")
  fi

  # ip规则
  local ipRules=()
  for ip in "${ipArray[@]}"; do
    if [[ $(echo "$ip" | grep -c '-') -ne 0 ]]; then
      ipRules+=("-m iprange --src-range $ip")
    else
      ipRules+=("-s $ip")
    fi
  done

  # 端口规则 - 如果没有指定端口，则为空
  local portRules=()
  for port in "${portArray[@]}"; do
    if [ -n "$port" ]; then
      portRules+=("--dport ${port//-/:}")
    fi
  done

  # 策略规则
  local ruleAction=""
  if [[ "$mode" == "allow" ]]; then
    ruleAction="-j ACCEPT"
  elif [[ "$mode" == "ban" ]]; then
    ruleAction="-j DROP"
  else
    echo "invalid mode, mode should be 'allow' or 'ban'"
    exit 1
  fi

  # 写入文件
  for proto in "${protocols[@]}"; do
    local protocolRule="-p $proto"
    
    # 如果没有指定端口，则不添加端口规则
    if [ ${#portArray[@]} -eq 0 ]; then
      if [ ${#ipArray[@]} -eq 0 ]; then
        # 既没有IP也没有端口
        cat >>/etc/portLimits.sh <<EOF
iptables -w -t mangle -A CUSTOM_INPUT_FILTER ${protocolRule} ${ruleAction}
EOF
      else
        # 只有IP，没有端口
        for ipRule in "${ipRules[@]}"; do
          cat >>/etc/portLimits.sh <<EOF
iptables -w -t mangle -A CUSTOM_INPUT_FILTER ${protocolRule} ${ipRule} ${ruleAction}
EOF
        done
      fi
    else
      # 有端口规则
      for portRule in "${portRules[@]}"; do
        if [ ${#ipArray[@]} -eq 0 ]; then
          # 没有IP，只有端口
          cat >>/etc/portLimits.sh <<EOF
iptables -w -t mangle -A CUSTOM_INPUT_FILTER ${protocolRule} ${portRule} ${ruleAction}
EOF
        else
          # 既有IP也有端口
          for ipRule in "${ipRules[@]}"; do
            cat >>/etc/portLimits.sh <<EOF
iptables -w -t mangle -A CUSTOM_INPUT_FILTER ${protocolRule} ${ipRule} ${portRule} ${ruleAction}
EOF
          done
        fi
      done
    fi
  done
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