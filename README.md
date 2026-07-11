# セットアップ

Android 9,15でテスト済み
(C330,SC-52B)

## 注意

> なんとAndroid版やiOS版のVLCには**対応していません**！！！
> 
> 理由はすべてのフォルダをファイルとして認識するから。使い物にならないってーの。
>
> どうしてもその用途で使いたかったらMiXとかのファイラーでプロキシして再生

## 前提

- [Magisk](https://github.com/topjohnwu/Magisk)
- [Magisk-Tailscaled](https://github.com/anasfanani/magisk-tailscaled)
- `/dev/net/tun`が存在する

### /dev/net/tunが存在しない場合

再起動後、起動時に作ってくれます。

```sh
su -c '
cd /data/adb/post-fs-data.d/ && /data/adb/magisk/busybox wget https://gist.github.com/SyameimaruKoa/6aec1fdbd347602fb0621b10c90a63a4/raw/fix_tun.sh && \
chmod 755 /data/adb/post-fs-data.d/fix_tun.sh
'
```

## ダウンロード＆インストール or アップデート

※rmは前のバージョンのやつとか俺が過去に設定してた名前のファイル

```sh
su -c '
cd /data/adb/service.d/ && \
rm ftpd.sh android-ftpd.sh android-ftpd-tailscale.sh ; \
/data/adb/magisk/busybox wget https://gist.github.com/SyameimaruKoa/6aec1fdbd347602fb0621b10c90a63a4/raw/android-ftpd-tailscale.sh && \
chmod 755 /data/adb/service.d/android-ftpd-tailscale.sh
'
```
終わったら再起動

### Tailscaleに依存せずlocalhostのみで公開する場合

用途はadbでポートフォワーディングするとかね

```sh
su -c '
cd /data/adb/service.d/ && \
rm android-ftpd_localhost.sh ; \
/data/adb/magisk/busybox wget https://gist.github.com/SyameimaruKoa/6aec1fdbd347602fb0621b10c90a63a4/raw/android-ftpd_localhost.sh && \
chmod 755 /data/adb/service.d/android-ftpd_localhost.sh
'
```

#### 接続方法

接続したいPCで
```sh
adb forward tcp:2121 tcp:2121
```
