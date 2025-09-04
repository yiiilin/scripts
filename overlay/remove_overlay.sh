#!/bin/bash
set -e

TARGET_DIR=$1
if [ ! -z "$TARGET_DIR" ];then
  TARGET_DIR=$(readlink -f $TARGET_DIR)
fi

if [ -z "$TARGET_DIR" ];then
  echo "please enter target directory: "
  read -r TARGET_DIR
  TARGET_DIR=$(readlink -f $TARGET_DIR)
  if [ -e $TARGET_DIR ] && [ ! -d $TARGET_DIR ];then
    echo "source path $TARGET_DIR is not a directory"
    exit 1
  elif [ ! -e $TARGET_DIR ];then
    echo "source path $TARGET_DIR is not exist"
    exit 1
  fi
fi

if num=$(mount | grep -Ec "overlay on $TARGET_DIR .+");then
  while [[ $num -gt 0 ]];do
    umount $TARGET_DIR
    num=$((num-1))
  done
fi

sed -i "/#OVERLAY_MOUNT:$(echo $TARGET_DIR | sed 's#/#\\\/#g')/d" /etc/fstab

echo "remove overlay on $TARGET_DIR success"
