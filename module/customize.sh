#!/system/bin/sh
# Magisk・KernelSU・APatch共通のモジュールインストーラーからsourceされる。
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/ftpd.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/fix_tun.sh" 0 0 0755
ui_print '- FTPD Tailscale: インストール完了。再起動後に起動します。'
ui_print '- 既存のservice.dスクリプトはREADMEを参照して手動削除してください。'
