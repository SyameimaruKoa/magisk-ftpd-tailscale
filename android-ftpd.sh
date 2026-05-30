#!/system/bin/sh

# ループ処理を完全にバックグラウンドで回すために全体を括るのじゃ
(
    MAX_ATTEMPTS=12
    ATTEMPT=0
    TAIL_IP=""

    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    # tailscaleコマンド、またはipコマンドでIP取得を試みるのじゃ
        TAIL_IP=$(tailscale ip -4 2>/dev/null)
        if [ -z "$TAIL_IP" ]; then
            TAIL_IP=$(ip -4 addr show tailscale0 2>/dev/null | grep inet | awk '{print $2}' | cut -d/ -f1)
        fi

        # IPが取れたらループを脱出するぞ
        if [ -n "$TAIL_IP" ]; then
            break
        fi

        ATTEMPT=$((ATTEMPT + 1))
        sleep 5
    done
    # 普段使い用（ポート21 -> 内部ストレージ）
    busybox tcpsvd -vE $TAIL_IP 21 busybox ftpd -w -A /storage/emulated/0 > /dev/null 2>&1 &

    # システムいじり用（ポート2121 -> ルート全体）
    busybox tcpsvd -vE $TAIL_IP 2121 busybox ftpd -w -A / > /dev/null 2>&1 &
) &