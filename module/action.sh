#!/system/bin/sh
# Magisk・KernelSU・APatchのアクションボタンからのみ音量キー操作を受け付ける。
# 下部のshow_help()を参照。
MODDIR=${0%/*}

show_help() {
    cat <<'HELP'
使い方: action.sh [--help]

モジュール管理アプリのアクションボタンを押した後、30秒以内に音量キーを押す。
    音量上: FTPのみ一時停止・再開（従来のtoggle）
    音量下: 共有ストレージ(external_primary)のMediaStore再スキャンを要求

スキャンはボタンを押した場合に限って実行する。FTPの転送処理は変更しない。
FTPの状態確認・切替はftpd.sh status/enable/disable/toggleからも実行できる。

オプション:
    -h, --help  このヘルプを表示
HELP
}

case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    '')
        ;;
    *)
        show_help >&2
        exit 2
        ;;
esac

BBOX=''
for CANDIDATE in /data/adb/magisk/busybox /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox; do
    if [ -x "$CANDIDATE" ]; then
        BBOX="$CANDIDATE"
        break
    fi
done
if [ -z "$BBOX" ] || [ ! -x /system/bin/getevent ]; then
    echo '音量キーの検出に必要なBusyBoxまたはgeteventが見つからぬ。' >&2
    exit 1
fi

echo '音量上: FTPの一時停止・再開'
echo '音量下: 共有ストレージのMediaScan'
echo '30秒以内に選択するのじゃ。'

DEADLINE=$(($(date +%s) + 30))
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
    # 監視はアクション操作中のみ。-c 1でイベントごとに確実に終了させる。
    EVENT=$("$BBOX" timeout 1 /system/bin/getevent -qlc 1 2>/dev/null)
    case "$EVENT" in
        *KEY_VOLUMEUP*DOWN*)
            "$MODDIR/ftpd.sh" toggle
            exit $?
            ;;
        *KEY_VOLUMEDOWN*DOWN*)
            "$MODDIR/ftpd.sh" scan
            exit $?
            ;;
    esac
done

echo '時間切れ: 何も変更せず終了したのじゃ。'
exit 1
