#!/data/adb/magisk/busybox sh
export ASH_STANDALONE=1

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
            tcpsvd -vE $TAIL_IP 21 ftpd -w -A /storage/emulated/0 > /dev/null 2>&1 &
            tcpsvd -vE $TAIL_IP 2121 ftpd -w -A / > /dev/null 2>&1 &
            break
        fi

        ATTEMPT=$((ATTEMPT + 1))
        sleep 5
    done
) &