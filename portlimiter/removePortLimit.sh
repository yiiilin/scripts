#!/bin/bash
set -ex

if [[ $(iptables -t mangle -nL PREROUTING | grep -c CUSTOM_INPUT_FILTER) -ne 0 ]]; then
  iptables -t mangle -D PREROUTING 1
fi
if [[ $(iptables -t mangle -nL CUSTOM_INPUT_FILTER | wc -l) -ge 2 ]]; then
  iptables -t mangle -F CUSTOM_INPUT_FILTER
  iptables -t mangle -X CUSTOM_INPUT_FILTER
fi
sed -i '/portLimits.sh/d' /etc/rc.local
rm -f /etc/portLimits.sh
