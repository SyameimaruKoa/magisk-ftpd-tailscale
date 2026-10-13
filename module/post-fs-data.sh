#!/system/bin/sh
# 従来のfix_tun.shと同じ処理を任意で実行。既定では無効。
MODDIR=${0%/*}

if [ -f "$MODDIR/enable_tun_fix" ]; then
    "$MODDIR/fix_tun.sh"
fi
