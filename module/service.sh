#!/system/bin/sh
# モジュール専用起動フック。人間が直接実行しないため引数は不要。
MODDIR=${0%/*}

# 長時間のTailscale IP待機をサービスフック自身で行わない。
"$MODDIR/ftpd.sh" monitor >/dev/null 2>&1 &
