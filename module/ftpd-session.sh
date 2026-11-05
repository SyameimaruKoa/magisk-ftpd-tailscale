#!/system/bin/sh
# tcpsvdが接続ごとに起動する内部用セッションラッパー。
MODDIR=${0%/*}
RUNDIR="$MODDIR/run"
BBOX="$1"
FTP_ROOT="$2"

[ -x "$BBOX" ] && [ -n "$FTP_ROOT" ] || exit 1
mkdir -p "$RUNDIR/sessions" || exit 1
SESSION_FILE="$RUNDIR/sessions/$$.pid"
printf '%s\n' "$$" > "$SESSION_FILE" || exit 1

# セッションが異常終了しても監視側で掃除・スキャンできるよう先に予約する。
touch "$RUNDIR/scan.pending"
cleanup() {
    rm -f "$SESSION_FILE"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

"$BBOX" ftpd -w -A "$FTP_ROOT"
exit $?
