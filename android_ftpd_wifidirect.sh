#!/data/adb/magisk/busybox sh
export ASH_STANDALONE=1

    BBOX="/data/adb/magisk/busybox"

(
    WFD_IP="192.168.49.1"

    while true; do
        if ip -4 addr show 2>/dev/null | grep -q "$WFD_IP"; then
            if ! ps -ef | grep tcpsvd | grep "$WFD_IP" | grep -q " 21 "; then
                tcpsvd -vE $WFD_IP 21 $BBOX ftpd -w -A /storage/emulated/0 > /dev/null 2>&1 &
                tcpsvd -vE $WFD_IP 2121 $BBOX ftpd -w -A / > /dev/null 2>&1 &
            fi
        else
            for pid in $(ps -ef | grep tcpsvd | grep "$WFD_IP" | awk '{print $2}'); do
                kill -9 $pid 2>/dev/null
            done
        fi

        sleep 10
    done
) &