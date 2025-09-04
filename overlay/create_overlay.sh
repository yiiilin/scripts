#!/bin/bash
set -e

SOURCE_DIR=$1
if [ ! -z "$SOURCE_DIR" ];then
  SOURCE_DIR=$(readlink -f $SOURCE_DIR)
fi
TARGET_DIR=$2
if [ ! -z "$TARGET_DIR" ];then
  TARGET_DIR=$(readlink -f $TARGET_DIR)
fi

if [ -z "$SOURCE_DIR" ];then
  echo "please enter source directory: "
  read -r SOURCE_DIR
  SOURCE_DIR=$(readlink -f $SOURCE_DIR)
  if [ -e $SOURCE_DIR ] && [ ! -d $SOURCE_DIR ];then
    echo "source path $SOURCE_DIR is not a directory"
    exit 1
  elif [ ! -e $SOURCE_DIR ];then
    echo "source path $SOURCE_DIR is not exist"
    exit 1
  fi
fi

if [ -z "$TARGET_DIR" ];then
  echo "please enter target directory: "
  read -r TARGET_DIR
  TARGET_DIR=$(readlink -f $TARGET_DIR)
  if [ -e $TARGET_DIR ] && [ ! -d $TARGET_DIR ];then
    echo "target path $TARGET_DIR is not a directory"
    exit 1
  elif [ ! -e $TARGET_DIR ];then
    mkdir -p $TARGET_DIR
  elif [ $(LANG=en mount -v TARGET_DIR 2>&1 | grep -c "mounted on") -ne 0 ];then
    echo "target path $TARGET_DIR is mounted now, please unmount it first. you can mount -vl TARGET_DIR to see the mount detail"
    exit 1
  fi 
fi

UPPER_DIR="${SOURCE_DIR}_upperdir"
WORK_DIR="${SOURCE_DIR}_workdir"

mkdir -p ${UPPER_DIR}
mkdir -p ${WORK_DIR}
mkdir -p ${TARGET_DIR}

mount -t overlay overlay -o lowerdir=${SOURCE_DIR},upperdir=${UPPER_DIR},workdir=${WORK_DIR} $TARGET_DIR

cat >> /etc/fstab << EOF
overlay         $TARGET_DIR overlay lowerdir=${SOURCE_DIR},upperdir=${UPPER_DIR},workdir=${WORK_DIR} 0 0 #OVERLAY_MOUNT:$TARGET_DIR
EOF
mount -a

echo "create overlay from ${SOURCE_DIR} to $TARGET_DIR success"
