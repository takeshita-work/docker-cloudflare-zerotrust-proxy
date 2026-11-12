# docker — cloudflare-zerotrust-proxy

Ubuntu 24.04 + Cloudflare One Client (WARP) のコンテナ (WARP コンテナ) の詳細。
セットアップと使い方は [../README.md](../README.md) を参照。

## ファイル

| ファイル | 内容 |
|---|---|
| `compose.yaml` | コンテナ定義 |
| `Dockerfile` | Ubuntu 24.04 に `cloudflare-warp` / `netcat-openbsd` / `microsocks` を導入 |
| `entrypoint.sh` | コンテナ内のプロセスを起動し、登録済みなら WARP を接続 |
| `.env.example` | `.env` のひな形。コンテナの名称と SOCKS5 のポートを設定する (`.env` は無くても動く) |
| `scripts/` | ホスト (Windows) 側の操作スクリプト |

## コンテナの定義 (`compose.yaml`)

| 項目 | 値 | 理由 |
|---|---|---|
| プロジェクト名 / コンテナ名 / ホスト名 | `.env` の `CONTAINER_NAME` (既定 `cloudflare-zerotrust-proxy`) | コンテナ名は `ProxyCommand` から参照される |
| イメージ名 | `cloudflare-zerotrust-proxy:latest` | 名称を変えても同じイメージを使う |
| `cap_add` | `NET_ADMIN` | WARP が TUN デバイスとルーティングを操作するため |
| `devices` | `/dev/net/tun` | WARP のトンネル用 |
| `sysctls` | `net.ipv6.conf.all.disable_ipv6=0` / `net.ipv4.conf.all.src_valid_mark=1` | WARP の動作に必要 |
| `ports` | `127.0.0.1:${SOCKS_PORT:-1080}:1080` | SOCKS5 プロキシ。ホストのループバックにのみ公開 |
| `volumes` | `warp-data:/var/lib/cloudflare-warp` | デバイス登録情報の永続化 |
| `restart` | `unless-stopped` | Docker Desktop の起動時に自動で立ち上げる |

Zero Trust 側のデバイス名にはホスト名が使われる。

## 起動時の流れ (`entrypoint.sh`)

1. `/dev/net/tun` が無ければ作成する。
2. `dbus-daemon` を起動する (`warp-svc` が必要とする)。
3. `warp-svc` を起動し、応答するまで待つ。
4. `microsocks` を `0.0.0.0:1080` で起動する。
5. 登録済みなら `warp-cli connect` を実行する。未登録なら `00_register.ps1` の実行を案内して待機する。

`warp-svc` の詳細ログは標準出力には出さず、コンテナ内の `/var/lib/cloudflare-warp/cfwarp_service_log.txt` に出力される。

ヘルスチェックは `warp-cli status` が `Status update: Connected` を返すかで判定する。

## 接続経路

| 用途 | 経路 |
|---|---|
| SSH / VS Code Remote-SSH | `ProxyCommand docker exec -i <コンテナ名> nc %h %p`。コンテナ内の `nc` を経由するのでポート公開は不要 |
| ブラウザなど | `microsocks` による SOCKS5 プロキシ (`127.0.0.1:1080`、認証なし) |

SOCKS5 のポートを変える場合は、`.env.example` を `.env` にコピーして `SOCKS_PORT` を設定する。

## 環境固有の設定 (`.env`)

| 変数 | 既定値 | 内容 |
|---|---|---|
| `CONTAINER_NAME` | `cloudflare-zerotrust-proxy` | 起動するコンテナの名称 (小文字の英数字とハイフン)。プロジェクト名・コンテナ名・ホスト名に使う |
| `SOCKS_PORT` | `1080` | ホストの `127.0.0.1` で公開する SOCKS5 のポート |

`.env` は git の管理対象外。

`CONTAINER_NAME` を変えるときの注意:

- 登録情報の volume (`<CONTAINER_NAME>_warp-data`) も別になるので、`00_register.ps1` で再登録する。
- 変更前のコンテナは、変える前に `05_down.ps1` で停止・削除しておく (残すと SOCKS5 のポートが競合する)。
- `.ssh/config` と `~/.ssh/config` の `ProxyCommand` のコンテナ名も合わせる (食い違っていると `access.ps1` が警告する)。
- 別の名称と `SOCKS_PORT` を使えば、複数の Zero Trust 組織向けに並べて起動できる (その場合はリポジトリを別のディレクトリに複製する)。

## デバイス登録の仕組み (`00_register.ps1`)

WARP の登録には、ブラウザでのログイン後に発行される `com.cloudflare.warp://<team>.cloudflareaccess.com/auth?token=...` 形式の URL が必要になる。
コンテナにはブラウザが無いので、ホスト側で次のように受け渡す。

1. コンテナ内で `warp-cli registration new <team>` を実行する。
2. ホストの `HKCU\Software\Classes\com.cloudflare.warp` に、`_token_handler.ps1` を呼ぶプロトコルハンドラを一時登録する。
3. ブラウザでログインページを開く。ログイン後に「開く」を押すと、ハンドラが URL を一時ファイル (`%TEMP%\<コンテナ名>-warp-token.txt`。パスはハンドラの登録時に引数で渡す) に書き出す。
4. スクリプトが URL を読み取り、`warp-cli registration token <URL>` と `warp-cli connect` を実行する。
5. 終了時 (中断・失敗時も含む) にハンドラと一時ファイルを削除する。

補足:

- トークンは発行から短時間で失効する。
- ホストに Cloudflare One Client が入っていて既にハンドラがある場合は、上書きせずハンドラ登録をスキップする。
- 予備の経路として、クリップボードも監視している。F12 の Elements で「Open in Cloudflare One Client」ボタンを選んでコピーすると、そこから URL を読み取る。
- 登録情報 (`reg.json` など) は volume `<コンテナ名>_warp-data` に保存される。

## スクリプト (`scripts/`)

リポジトリのルートから `.\docker\scripts\<名前>.ps1` で実行する。
`compose.yaml` の場所はスクリプト自身の位置から解決するので、どのディレクトリから実行しても動く。

| スクリプト | 内容 | オプション |
|---|---|---|
| `00_register.ps1` | デバイス登録 (初回のみ) | `-Team <名前>` チーム名を指定 / `-Force` 登録し直す / `-TimeoutSec <秒>` トークンの待ち時間 (既定 300) |
| `01_up.ps1` | 起動し、WARP の接続を待って状態を表示 | `-Build` イメージを再ビルド |
| `02_status.ps1` | コンテナの状態と WARP の接続状態を確認 | |
| `03_logs.ps1` | コンテナのログを表示 | `-Follow` 追従 / `-Tail <行数>` (既定 100) |
| `04_shell.ps1` | コンテナ内で bash を開く | 引数を渡すとそのコマンドを実行 |
| `05_down.ps1` | コンテナを停止・削除 | `-RemoveData` 登録情報の volume も削除 (再登録が必要になる) |
| `_common.ps1` | 共通定義 (コンテナ名、`.env` の読み込み、起動・接続待ちの関数)。直接は実行しない | |
| `_token_handler.ps1` | 登録時のプロトコルハンドラ。直接は実行しない | |

`scripts/` の `.ps1` は BOM 付き UTF-8 で保存する (Windows PowerShell 5.1 が BOM なしの日本語を読めないため)。

ここのスクリプトが扱うのはコンテナと WARP の接続までで、接続先のことは知らない。
接続先への疎通は、リポジトリのルートの `.\scripts\check.ps1` (接続先は `.ssh/config` から読む) で確認する。

`Dockerfile` や `entrypoint.sh` を変更したら、`01_up.ps1 -Build` で反映する。

## 調査のしかた

```powershell
.\docker\scripts\04_shell.ps1 warp-cli --accept-tos status          # WARP の状態
.\docker\scripts\04_shell.ps1 nc -zv -w 5 <接続先のアドレス> 22     # コンテナからの疎通
.\docker\scripts\04_shell.ps1 tail -n 50 /var/lib/cloudflare-warp/cfwarp_service_log.txt   # warp-svc のログ
```

- WARP が `Connected` なのに疎通しない場合は、Zero Trust 側の設定 (Split Tunnel で接続先のアドレスが WARP 経由になっているか、Tunnel のルートに含まれているか) を確認する。
- 届くのは Tunnel のルートに含まれるアドレスだけ。同じ LAN でもルートに無いアドレスには届かない。
