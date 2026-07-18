#!/system/bin/sh

# 人間が直接実行するものではないからヘルプは省いておるぞ
    BBOX="/data/adb/magisk/busybox"

# localhost (127.0.0.1) のみで待ち受け、ルート (/) をポート2121で公開するのじゃ
    $BBOX tcpsvd -vE 127.0.0.1 2121 $BBOX ftpd -w -A / > /dev/null 2>&1 &