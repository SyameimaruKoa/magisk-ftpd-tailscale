#!/system/bin/sh
# モジュールマネージャーのアクションボタン専用フック。
MODDIR=${0%/*}
"$MODDIR/ftpd.sh" toggle
