#!/system/bin/sh
# 下部の show_help() を参照。
MODDIR=${0%/*}
RUNDIR="$MODDIR/run"
PID_MONITOR="$RUNDIR/monitor.pid"
DESCRIPTION='FTP (Tailscale/localhost、21: 内部ストレージ / 2121: ルート)。アクションで一時停止・再開。'

# 管理方式に応じて各マネージャー内蔵のBusyBoxを利用する。
find_busybox() {
    if [ "${APATCH:-}" = true ] && [ -x /data/adb/ap/bin/busybox ]; then
        BBOX=/data/adb/ap/bin/busybox
    elif [ "${KSU:-}" = true ] && [ -x /data/adb/ksu/bin/busybox ]; then
        BBOX=/data/adb/ksu/bin/busybox
    elif [ -x /data/adb/magisk/busybox ]; then
        BBOX=/data/adb/magisk/busybox
    elif [ -x /data/adb/ksu/bin/busybox ]; then
        BBOX=/data/adb/ksu/bin/busybox
    elif [ -x /data/adb/ap/bin/busybox ]; then
        BBOX=/data/adb/ap/bin/busybox
    else
        BBOX=$(command -v busybox 2>/dev/null)
    fi
    [ -n "$BBOX" ] && [ -x "$BBOX" ]
}

# 信頼済みのmodule/config.confだけからMODEを読み出す（コードとして実行しない）。
get_mode() {
    MODE=$($BBOX sed -n 's/^MODE=//p' "$MODDIR/config.conf" 2>/dev/null | $BBOX tail -n 1 | $BBOX tr -d '\r')
    case "$MODE" in
        tailscale|localhost) ;;
        *) MODE=tailscale ;;
    esac
}

# 過去に使ったPIDを別のプロセスと取り違えないようコマンドラインを確認する。
valid_pid() {
    PID="$1"
    EXPECTED="$2"
    case "$PID" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ -r "/proc/$PID/cmdline" ] || return 1
    CMDLINE=$($BBOX tr '\000' ' ' < "/proc/$PID/cmdline" 2>/dev/null)
    case "$CMDLINE" in
        *"$EXPECTED"*) return 0 ;;
    esac
    return 1
}

ftpd_alive() {
    PORT="$1"
    [ -r "$RUNDIR/$PORT.pid" ] && [ -r "$RUNDIR/bind.ip" ] || return 1
    PID=$(cat "$RUNDIR/$PORT.pid")
    BIND_IP=$(cat "$RUNDIR/bind.ip")
    valid_pid "$PID" "tcpsvd -vE $BIND_IP $PORT "
}

monitor_alive() {
    [ -r "$PID_MONITOR" ] || return 1
    PID=$(cat "$PID_MONITOR")
    valid_pid "$PID" "$MODDIR/ftpd.sh monitor"
}

stop_servers() {
    if [ -f "$RUNDIR/bind.ip" ]; then
        for PORT in 21 2121; do
            if ftpd_alive "$PORT"; then
                kill "$(cat "$RUNDIR/$PORT.pid")" 2>/dev/null
            fi
        done
    fi
    rm -f "$RUNDIR/21.pid" "$RUNDIR/2121.pid" "$RUNDIR/bind.ip" "$RUNDIR/starting"
}

get_tail_ip() {
    TAIL_IP=$(tailscale ip -4 2>/dev/null | $BBOX sed -n '1p')
    if [ -z "$TAIL_IP" ]; then
        TAIL_IP=$($BBOX ip -4 addr show tailscale0 2>/dev/null | $BBOX grep 'inet ' | $BBOX awk '{print $2}' | $BBOX cut -d/ -f1 | $BBOX sed -n '1p')
    fi
    # 不正な待受アドレスをBusyBoxに渡さない。
    case "$TAIL_IP" in
        ''|*[!0-9.]*) TAIL_IP='' ;;
    esac
}

start_servers() {
    get_mode
    rm -f "$RUNDIR/timeout"
    touch "$RUNDIR/starting"
    if [ "$MODE" = localhost ]; then
        BIND_IP=127.0.0.1
    else
        ATTEMPT=0
        BIND_IP=''
        while [ "$ATTEMPT" -lt 12 ]; do
            if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ] || [ -f "$MODDIR/paused" ]; then
                rm -f "$RUNDIR/starting"
                return 1
            fi
            get_tail_ip
            if [ -n "$TAIL_IP" ]; then
                BIND_IP="$TAIL_IP"
                break
            fi
            ATTEMPT=$((ATTEMPT + 1))
            sleep 5
        done
        if [ -z "$BIND_IP" ]; then
            touch "$RUNDIR/timeout"
            rm -f "$RUNDIR/starting"
            return 1
        fi
    fi

    if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ] || [ -f "$MODDIR/paused" ]; then
        rm -f "$RUNDIR/starting"
        return 1
    fi
    echo "$BIND_IP" > "$RUNDIR/bind.ip"
    if [ "$MODE" = tailscale ]; then
        "$BBOX" tcpsvd -vE "$BIND_IP" 21 "$BBOX" ftpd -w -A /storage/emulated/0 >/dev/null 2>&1 &
        echo "$!" > "$RUNDIR/21.pid"
    fi
    "$BBOX" tcpsvd -vE "$BIND_IP" 2121 "$BBOX" ftpd -w -A / >/dev/null 2>&1 &
    echo "$!" > "$RUNDIR/2121.pid"
    rm -f "$RUNDIR/starting"
}

get_status() {
    if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ]; then
        STATUS='無効 (モジュール管理画面)'
    elif [ -f "$MODDIR/paused" ]; then
        STATUS='停止中 (FTP一時停止)'
    elif [ -f "$RUNDIR/starting" ]; then
        STATUS='起動中 (Tailscale IP待機)'
    elif [ -f "$RUNDIR/timeout" ]; then
        STATUS='停止中 (Tailscale IP取得タイムアウト)'
    elif [ -f "$RUNDIR/bind.ip" ]; then
        get_mode
        if [ "$MODE" = localhost ]; then
            if ftpd_alive 2121; then
                STATUS='動作中 (127.0.0.1:2121)'
            else
                STATUS='停止中 (FTPプロセス終了)'
            fi
        elif ftpd_alive 21 && ftpd_alive 2121; then
            STATUS="動作中 ($(cat "$RUNDIR/bind.ip"):21,2121)"
        elif ftpd_alive 21 || ftpd_alive 2121; then
            STATUS='一部動作中 (ポートの競合などを確認)'
        else
            STATUS='停止中 (FTPプロセス終了)'
        fi
    elif ! monitor_alive; then
        STATUS='停止中 (起動サービスなし / 再起動待ち)'
    else
        STATUS='起動待ち'
    fi
}

publish_status() {
    get_status
    NEW_DESC="[FTP: $STATUS] $DESCRIPTION"
    OLD_DESC=$(cat "$RUNDIR/description" 2>/dev/null)
    if [ "$OLD_DESC" = "$NEW_DESC" ]; then
        return
    fi
    echo "$NEW_DESC" > "$RUNDIR/description"
    "$BBOX" sed -i "s|^description=.*|description=$NEW_DESC|" "$MODDIR/module.prop" 2>/dev/null
    # KernelSU新バージョンではmodule.propよりoverride.descriptionが優先される。
    if [ "${KSU:-}" = true ]; then
        if command -v ksud >/dev/null 2>&1; then
            ksud module config set override.description "$NEW_DESC" >/dev/null 2>&1 || true
        elif [ -x /data/adb/ksu/bin/ksud ]; then
            /data/adb/ksu/bin/ksud module config set override.description "$NEW_DESC" >/dev/null 2>&1 || true
        fi
    fi
}

monitor() {
    if ! find_busybox; then
        echo 'BusyBoxが見つかりません' >&2
        return 1
    fi
    mkdir -p "$RUNDIR"
    if monitor_alive; then
        return 0
    fi
    echo "$$" > "$PID_MONITOR"
    LAST_ENABLED=0
    while :; do
        if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ] || [ -f "$MODDIR/paused" ]; then
            if [ "$LAST_ENABLED" -eq 1 ]; then
                stop_servers
            fi
            LAST_ENABLED=0
        elif [ "$LAST_ENABLED" -eq 0 ]; then
            LAST_ENABLED=1
            stop_servers
            if ! start_servers; then
                if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ] || [ -f "$MODDIR/paused" ]; then
                    LAST_ENABLED=0
                fi
            fi
        fi
        publish_status
        if [ -f "$MODDIR/remove" ]; then
            rm -f "$PID_MONITOR"
            return 0
        fi
        sleep 2
    done
}

print_status() {
    if ! find_busybox; then
        echo 'FTP: BusyBoxが見つかりません'
        return 1
    fi
    mkdir -p "$RUNDIR"
    get_mode
    get_status
    printf 'モジュール: %s\nFTP: %s\nモード: %s\n' "$MODDIR" "$STATUS" "$MODE"
    if [ "$MODE" = tailscale ]; then
        echo '21/tcp  -> /storage/emulated/0'
        echo '2121/tcp -> /'
    else
        echo '127.0.0.1:2121/tcp -> /'
    fi
}

flip_pause() {
    if [ -f "$MODDIR/disable" ]; then
        echo 'モジュールが無効です。管理アプリで有効にして再起動してください。'
        return 1
    fi
    if [ -f "$MODDIR/paused" ]; then
        rm -f "$MODDIR/paused"
        echo 'FTPを有効化しました。'
    else
        touch "$MODDIR/paused"
        echo 'FTPを無効化しました。'
    fi
    sleep 3
    print_status
}

show_help() {
    cat <<'HELP'
使い方: ftpd.sh <コマンド>

コマンド:
    status      現在のFTP稼働状態、待受アドレスと公開ディレクトリを表示
    enable      FTPを有効化（モジュール全体の無効化は解除しない）
    disable     FTPを停止（設定は再起動後も保持）
    toggle      FTPの有効/無効を切り替え、状態を表示（管理画面のアクション用）
    monitor     起動時の監視プロセスを開始（service.sh専用）
    -h, --help  このヘルプを表示

設定:
    config.conf の MODE=tailscale または MODE=localhost
    モード変更を反映するにはFTPをdisable→enableするか再起動する。
    モジュール管理画面の無効化は別途行い、再起動後も無効状態を保持する。
HELP
}

case "$1" in
    monitor)
        monitor
        ;;
    status)
        print_status
        ;;
    enable)
        rm -f "$MODDIR/paused"
        echo 'FTP有効化を要求しました。起動サービスが動作していない場合は再起動してください。'
        ;;
    disable)
        touch "$MODDIR/paused"
        echo 'FTP無効化を要求しました。'
        ;;
    toggle)
        flip_pause
        ;;
    -h|--help|'')
        show_help
        ;;
    *)
        echo "不明な引数: $1" >&2
        show_help
        exit 2
        ;;
esac
