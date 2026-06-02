#!/data/adb/magisk/busybox sh
export ASH_STANDALONE=1

# tcpsvdに渡すための直通番号（フルパス）を定義じゃ
    BBOX="/data/adb/magisk/busybox"

(
    MAX_ATTEMPTS=12
    ATTEMPT=0
    TAIL_IP=""

    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        TAIL_IP=$(tailscale ip -4 2>/dev/null)
        if [ -z "$TAIL_IP" ]; then
            TAIL_IP=$(ip -4 addr show tailscale0 2>/dev/null | grep inet | awk '{print $2}' | cut -d/ -f1)
        fi

        if [ -n "$TAIL_IP" ]; then
            # 最初のtcpsvdは省略可能だが、後ろのftpdには必ず$BBOXをつけるのじゃ！
            tcpsvd -vE $TAIL_IP 21 $BBOX ftpd -w -A /storage/emulated/0 > /dev/null 2>&1 &
            tcpsvd -vE $TAIL_IP 2121 $BBOX ftpd -w -A / > /dev/null 2>&1 &
            break
        fi

        ATTEMPT=$((ATTEMPT + 1))
        sleep 5
    done
) &