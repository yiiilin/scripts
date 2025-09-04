# OverlayFS

> 简单的快速创建overlayfs的脚本

## 如何使用

先下载脚本

```shell
if [ ! -f create_overlay.sh ];then
  curl -L -o /usr/bin/create_overlay.sh https://raw.githubusercontent.com/yiiilin/scripts/refs/heads/main/overlay/create_overlay.sh
fi
if [ ! -f remove_overlay.sh ];then
  curl -L -o /usr/bin/remove_overlay.sh https://raw.githubusercontent.com/yiiilin/scripts/refs/heads/main/overlay/remove_overlay.sh
fi
chmod +x /usr/bin/create_overlay.sh /usr/bin/remove_overlay.sh
```

假设只读层是`READONLY`，目标层是`MERGED`

那么创建`overlay`就是

```shell
create_overlay.sh READONLY MERGED
```

删除`overlay`就是

```shell
remove_overlay.sh MERGED
```