#!/system/bin/sh
# 旧fix_tun.shの処理を保持。post-fs-data.shからのみ呼び出す。
    modprobe tun 2>/dev/null || insmod /system/lib/modules/tun.ko 2>/dev/null

    if [ ! -e /dev/net/tun ]; then
        mkdir -p /dev/net
        if [ -e /dev/tun ]; then
            ln -sf /dev/tun /dev/net/tun
        else
            mknod /dev/net/tun c 10 200
        fi
        chcon u:object_r:tun_device:s0 /dev/net/tun
        chmod 666 /dev/net/tun
    fi
