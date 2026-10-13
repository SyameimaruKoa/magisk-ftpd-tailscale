# FTPD Tailscale（Magisk / KernelSU / APatch）

Androidのroot権限で動くBusyBox FTPサーバー。従来の`service.d`方式を、Magisk・KernelSU・APatch共通の管理可能なモジュールに移行しました。

従来のスクリプトは互換性・移行確認用にリポジトリへ残していますが、**新規導入・更新はモジュールZIPをCLIでインストール**してください。

旧スクリプトはAndroid 9 / 15（C330 / SC-52B）で動作確認済み。**新しいモジュールのMagisk・KernelSU・APatch実機動作は未検証**です。

## 動作・仕様

| モード | 待受 | 公開先 | 備考 |
| --- | --- | --- | --- |
| `tailscale`（既定） | Tailscale IPv4 `:21` | `/storage/emulated/0` | 読み書き可能 |
| `tailscale`（既定） | Tailscale IPv4 `:2121` | `/` | root権限で読み書き可能 |
| `localhost`（任意） | `127.0.0.1:2121` | `/` | ADBポート転送向け。Tailscale不要 |

- 従来のBusyBox `tcpsvd -vE` + `ftpd -w -A` を継続使用します。
- Tailscaleモードでは `tailscale ip -4`、失敗時は`tailscale0`からIPv4を取得します。**5秒おきに最大12回**調べます。
- IPが見つからない場合は起動を断念します。Tailscaleの再接続やIP変更を継続監視して自動再起動する機能は追加していません。FTPの一時停止→再開、または再起動で再試行します。
- Magisk・KernelSU・APatchそれぞれに内蔵されたBusyBoxを自動検出します。追加のBusyBoxパッケージは不要です。
- 起動・停止・ポート21/2121の生存状態をモジュールの説明欄およびCLIに表示します。KernelSUでは対応版なら`override.description`も更新します。管理アプリを開いたままの場合は一覧を再表示してください。
- module管理アプリの有効・無効は通常のモジュール切替です。加えて、**アクションボタン**でFTPだけを即時停止・再開できます（数秒で反映）。FTP一時停止は再起動後も維持されます。

FTPは暗号化されないプロトコルです。Tailscaleモードでは、VPN外のインターフェースには待受しません。`2121`番で`/`をroot権限のまま公開するため、Tailnet ACL・端末の安全性には十分注意してください。

## 必要なもの

- [Magisk](https://github.com/topjohnwu/Magisk)、[KernelSU](https://github.com/tiann/KernelSU)、[APatch](https://github.com/bmax121/APatch) のいずれか
- Tailscaleモードでは、起動済みのTailscaleデーモンおよび使用可能な`tailscale`コマンドまたは`tailscale0`インターフェース
- Tailscaleモードでは`/dev/net/tun`（無い場合は後述の修復オプション）
- rootシェル（`su`）

従来の[Magisk-Tailscaled](https://github.com/anasfanani/magisk-tailscaled)など、**Tailscale本体の導入は別途必要**です。FTPモジュールはTailscaleデーモンをインストールしません。KernelSU / APatchでは各環境で動作するTailscaleの用意が必要です。

## 1. CLIでダウンロード・インストール・更新

`su`が使えるAndroid端末のシェル、または`adb shell`内で実行します。`FTPD-Tailscale.zip`は[このリポジトリの専用リリース](https://github.com/SyameimaruKoa/magisk-ftpd-tailscale/releases/tag/ftpd-tailscale-latest)で配布します（リリース作成後に利用可能）。

### ダウンロード（3つのroot管理方式共通）

```sh
su -c '
    ZIP=/data/local/tmp/FTPD-Tailscale.zip
    URL=https://github.com/SyameimaruKoa/magisk-ftpd-tailscale/releases/download/ftpd-tailscale-latest/FTPD-Tailscale.zip

    if [ -x /data/adb/magisk/busybox ]; then
        BB=/data/adb/magisk/busybox
    elif [ -x /data/adb/ksu/bin/busybox ]; then
        BB=/data/adb/ksu/bin/busybox
    else
        BB=/data/adb/ap/bin/busybox
    fi

    "$BB" wget -O "$ZIP" "$URL" || exit 1
    "$BB" unzip -t "$ZIP" || exit 1
    echo "取得・ZIP検証成功: $ZIP"
'
```

### インストール（使っているroot管理方式のコマンドを1つ選ぶ）

Magisk:

```sh
su -c 'magisk --install-module /data/local/tmp/FTPD-Tailscale.zip'
```

KernelSU:

```sh
su -c '/data/adb/ksu/bin/ksud module install /data/local/tmp/FTPD-Tailscale.zip'
```

APatch:

```sh
su -c '/data/adb/ap/bin/apd module install /data/local/tmp/FTPD-Tailscale.zip'
```

インストール・更新に成功したら**端末を再起動**してください。APatch等でCLIインストールが失敗する場合は、管理アプリのモジュールZIPインストール機能を使ってください。

## 2. 旧スクリプトから移行する

**重複待受を防ぐため、古い`service.d`スクリプトを削除してから再起動**します。以下はこのリポジトリで過去に使用していた名前のみを指定しており、ほかのroot起動スクリプトは消しません。

```sh
su -c '
    rm -f \
        /data/adb/service.d/ftpd.sh \
        /data/adb/service.d/android-ftpd.sh \
        /data/adb/service.d/android-ftpd-tailscale.sh \
        /data/adb/service.d/android-ftpd_localhost.sh
'
```

`/data/adb/post-fs-data.d/fix_tun.sh`を使用していた場合は、下記の修復オプションを有効にし、**再起動してtunデバイスが使用可能なことを確認した後**に、旧スクリプトを削除します。

```sh
su -c 'rm -f /data/adb/post-fs-data.d/fix_tun.sh'
```

> 旧スクリプトを消すだけでは、**今動いているFTPプロセスは停止しない**場合があります。モジュール導入後に一度再起動してください。

## 3. 有効・無効・ステータス

管理アプリ（Magisk / KernelSU / APatch）のモジュール画面からモジュール全体を有効化・無効化できます。通常は再起動後に有効・無効が確定します。説明欄の`[FTP: ...]`に現在の状態を表示します。管理アプリの**アクション**ボタンでFTPのみ一時停止・再開できます（アプリ側がアクションボタンに対応している必要があります）。

CLIで状態表示:

```sh
su -c 'sh /data/adb/modules/ftpd-tailscale/ftpd.sh status'
```

CLIでFTPのみ無効化:

```sh
su -c 'sh /data/adb/modules/ftpd-tailscale/ftpd.sh disable'
```

CLIでFTPのみ有効化:

```sh
su -c 'sh /data/adb/modules/ftpd-tailscale/ftpd.sh enable'
```

CLIヘルプ:

```sh
su -c 'sh /data/adb/modules/ftpd-tailscale/ftpd.sh --help'
```

- `enable` / `disable` / アクションはFTP機能のみ切り替えます。管理アプリでモジュール全体を無効化している場合は、そちらの有効化・再起動が必要です。
- FTP停止時には監視中の`tcpsvd`リスナーを停止します。すでに確立しているFTPセッションは終了まで残る場合があります。
- Tailscale IP変更後の再待受は`disable`→`enable`で実行できます。これは従来の動作に自動追従を追加するものではありません。

## 4. localhost専用（Tailscaleに依存しない）

旧`android-ftpd_localhost.sh`の機能もモジュールへ移行しました。モジュールの`config.conf`を変更します。

```sh
su -c 'sed -i "s/^MODE=.*/MODE=localhost/" /data/adb/modules/ftpd-tailscale/config.conf'
```

モード変更後はFTPを`disable`→`enable`で再起動するか端末を再起動します。Tailscaleモードへ戻す場合は`MODE=tailscale`にしてください。

接続するPCでADBポート転送:

```sh
adb forward tcp:2121 tcp:2121
```

転送先は`ftp://127.0.0.1:2121`です。

## 5. `/dev/net/tun`が存在しない場合（任意）

従来の`fix_tun.sh`と同じデバイス作成処理をモジュールの`post-fs-data.sh`から起動できます。既定ではオフです。必要な端末でのみ有効にしてください。

```sh
su -c 'touch /data/adb/modules/ftpd-tailscale/enable_tun_fix'
```

設定後に再起動し、以下で確認します。

```sh
su -c 'ls -lZ /dev/net/tun'
```

無効化する場合（再起動で反映）:

```sh
su -c 'rm -f /data/adb/modules/ftpd-tailscale/enable_tun_fix'
```

## 注意：Android / iOS版VLC

なんとAndroid版やiOS版のVLCには**対応していません**！！！

理由はすべてのフォルダをファイルとして認識するから。使い物にならないってーの。
どうしてもその用途で使いたかったらMiXとかのファイラーでプロキシして再生。

読み込み用のファイルサーバーとしてこれから使うつもりなら、これを使わずにTailscaleのTailDriveを使った方が良いと思います。TailDriveは神。

多数のファイルの書き込み等はあまり安定しないのでFTPを使うのは大いにあり。

## その他の既存コード

- `android-ftpd-tailscale.sh` / `android-ftpd_localhost.sh` / `fix_tun.sh`: 従来方式のスクリプト（既存のコードは残しています）
- `Tethering_FTPD_Multi-IP/`: 別用途のIP指定型モジュール（今回のモジュール化では変更しません）
