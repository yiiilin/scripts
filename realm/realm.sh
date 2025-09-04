#!/bin/bash
set -ex

if ! docker info || ! docker compose -v;then
  if [ $(cat /etc/os-release | grep -E "^NAME=" | tr A-Z a-z | grep -c debian) -eq 1 ];then
    bash <(curl -L https://raw.githubusercontent.com/yiiilin/scripts/refs/heads/main/docker/install_docker.sh)
  else
    echo "we need docker and docker compose, please install them first!"
    exit 1
  fi
fi

if [[ "$(basename $PWD)" != "realm" ]];then
        mkdir -p realm
        cd realm
fi

if [ ! -f realm ];then
        curl -OL https://raw.githubusercontent.com/yiiilin/scripts/refs/heads/main/realm/realm
fi
chmod +x realm

cat > ./realm.sh.tmp << 'EOF'
bash <(curl -L https://raw.githubusercontent.com/yiiilin/scripts/refs/heads/main/realm/realm.sh)
EOF
cat << EOF > ./realm.yaml
version: '3'
services:
EOF
for i in $@;do
        source_addr=$(echo "$i" | awk -F'-' '{print $1}')
        target_addr=$(echo "$i" | awk -F'-' '{print $2}')
        source_host=$(echo "$source_addr" | awk -F':' '{print $1}')
        source_port=$(echo "$source_addr" | awk -F':' '{print $2}')
        target_host=$(echo "$target_addr" | awk -F':' '{print $1}')
        target_port=$(echo "$target_addr" | awk -F':' '{print $2}')
        cat << EOF >> ./realm.yaml
  port-${source_host}-${source_port}:
    image: busybox:1.37.0-glibc
    volumes:
      - ./realm:/usr/bin/realm
    command: realm -l ${source_host}:${source_port} -r ${target_host}:${target_port}
    network_mode: host
    restart: always
EOF
  cat >> ./realm.sh.tmp << EOF
${source_host}:${source_port}-${target_host}:${target_port}
EOF
done

sed -i ':a;N;$!ba;s/\n/ /g' ./realm.sh.tmp
chmod +x ./realm.sh.tmp
rm -f ./realm.sh
mv ./realm.sh.tmp ./realm.sh

docker compose -f realm.yaml -p realm up -d