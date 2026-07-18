#!/system/bin/sh
MODDIR=${0%/*}

# モジュールが有効な状態であれば初期起動させておく
if [ ! -f "$MODDIR/disable" ]; then
    "$MODDIR/ftpd.service" start
fi

# 重複起動を防ぐために既存の inotifyd プロセスをキルするのじゃ
for PID in $(/data/adb/magisk/busybox pidof inotifyd); do
    if grep -q "ftpd.inotify" "/proc/$PID/cmdline" 2>/dev/null; then
        kill -9 "$PID"
    fi
done

# inotifydを使ってモジュールディレクトリのイベント監視をバックグラウンドで開始するぞ
inotifyd "$MODDIR/ftpd.inotify" "$MODDIR" > /dev/null 2>&1 &
