#!/system/bin/sh
    # まずはスマートに、カーネルモジュールとしてtunが存在するか探し出してロードを試みるのじゃ
    modprobe tun 2>/dev/null || insmod /system/lib/modules/tun.ko 2>/dev/null

    if [ ! -e /dev/net/tun ]; then
        mkdir -p /dev/net
        if [ -e /dev/tun ]; then
            ln -sf /dev/tun /dev/net/tun
        else
            # 仕方なく錬成する場合も、Android 9の作法に従うのじゃ
            mknod /dev/net/tun c 10 200
        fi

        # ここが一番スマートなポイントじゃ！
        # Android 9の厳しいSELinuxに怒られないよう、正しい身分証（コンテキスト）を持たせるぞ
        chcon u:object_r:tun_device:s0 /dev/net/tun
        chmod 666 /dev/net/tun
    fi