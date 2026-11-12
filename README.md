# cloudflare-zerotrust-proxy

Cloudflare Zero Trust のプライベートネットワーク (Cloudflare Tunnel の先にあるホスト) に、手元の Windows PC から接続するための環境。

Cloudflare One Client (WARP) を入れた Docker コンテナ (既定の名称は `cloudflare-zerotrust-proxy`) を踏み台 / プロキシとして使う。
WARP をコンテナに閉じ込めるので、PC 全体の通信を WARP に通さず、必要な接続先だけをコンテナ経由にできる。

```
Windows PC ──> cloudflare-zerotrust-proxy (Docker / WARP) ──> Cloudflare ──(Tunnel)──> 接続先ホスト
```

コンテナの仕組みや構成の詳細は [docker/README.md](docker/README.md) を参照。

## 前提

- Windows + Docker Desktop
- Zero Trust 組織 (チーム) にログインできるアカウント
- 接続先へのルートを持つ Cloudflare Tunnel が Zero Trust 側に設定済みであること (このリポジトリは Tunnel 自体は扱わない)
- SSH で接続する場合は、接続先の SSH アカウント

コマンドはすべてこのディレクトリ (リポジトリのルート) から実行する。

## 環境固有の設定

接続先などの環境固有の値は、git の管理対象外のファイルに置く。

| ファイル | 内容 | ひな形 |
|---|---|---|
| `.ssh/config` | 接続先 (ホスト別名・アドレス・ユーザー名)。SSH 接続と疎通確認に使う | `.ssh/config.example` |
| `docker/.env` | コンテナの名称、SOCKS5 のポート (任意) | `docker/.env.example` |

Zero Trust のチーム名はデバイス登録時に入力し、登録情報としてコンテナの volume に保存される。

## セットアップ (初回のみ)

```powershell
.\docker\scripts\00_register.ps1
```

1. Zero Trust のチーム名 (`<team>.cloudflareaccess.com` の `<team>`) を入力する。
2. ブラウザが開くのでログインする。
3. 「アプリを開きますか？」のダイアログで **開く** を押す (または画面の「Open in Cloudflare One Client」)。
4. 自動でデバイス登録・接続まで進む。

登録は一度だけでよく、次回以降はコンテナを起動すれば自動で接続される。
登録し直すときは `-Force` を付ける。

コンテナの名称や SOCKS5 のポートを変えたい場合は、先に `docker/.env.example` を `docker/.env` にコピーして設定する。

## 使い方

### SSH で接続する

```powershell
.\scripts\access.ps1
```

- 初回は `.ssh/config.example` から `.ssh/config` を作り、接続先の名前・アドレス・ログインユーザー名を聞いて保存する。
- `.ssh/config` の最初の `Host` に接続する。
- コンテナが止まっていれば起動し、接続を待ってから SSH する。
- 鍵を指定する場合は `.ssh/config` の `IdentityFile` のコメントを外して書き換える。
- `ssh` のオプションやリモートコマンドはそのまま渡せる。

```powershell
.\scripts\access.ps1 -L 8888:localhost:8888     # ポート転送
.\scripts\access.ps1 nvidia-smi                 # リモートでコマンドを実行
```

### 接続先への疎通を確認する

```powershell
.\scripts\check.ps1
```

- コンテナと WARP の状態を表示し、`.ssh/config` の最初の `Host` (`access.ps1` と同じ接続先) にコンテナの中から届くかを確認する。
- コンテナは起動しない。止まっている場合は `.\docker\scripts\01_up.ps1` で起動する。

### VS Code Remote-SSH で接続する

1. `~/.ssh/config` に `.ssh/config` の `Host` ブロックを追記する。
   同じ名前の `Host` の定義が他にある場合は削除する (先に書かれた定義が優先されるため)。
2. `.\docker\scripts\01_up.ps1` でコンテナを起動しておく (VS Code はコンテナを起動しない)。
3. VS Code で「Remote-SSH: Connect to Host...」から追記したホストを選ぶ。

同じ設定で、通常のターミナルから `ssh <ホスト別名>` でも接続できる。

`remote.SSH.configFile` はユーザー設定でしか有効にならないため、ワークスペースの `.vscode/settings.json` では指定できない。

### ブラウザでアクセスする (ZeroOmega)

コンテナが SOCKS5 プロキシを `127.0.0.1:1080` に公開している。
Proxy SwitchyOmega 3 (ZeroOmega) で、接続先のアドレス宛てだけをこのプロキシに向ける。

1. プロキシプロファイルを作る。

   | 項目 | 値 |
   |---|---|
   | Protocol | SOCKS5 |
   | Server | `127.0.0.1` |
   | Port | `1080` |

2. auto switch に条件を追加する。Default は Direct のままにする。

   | 項目 | 値 |
   |---|---|
   | Condition Type | Host wildcard |
   | Condition Details | 接続先のアドレス (例: `192.0.2.10`) |
   | Profile | 1 で作ったプロファイル |

3. 「Apply changes」を押し、拡張のアイコンから auto switch を選ぶ。

これで `http://<接続先のアドレス>:<ポート>` へのアクセスだけがコンテナ経由になる。
プロファイルを直接選ぶと全通信が WARP 経由になるので、auto switch で接続先を絞る。

## コンテナの操作

| スクリプト | 用途 |
|---|---|
| `.\docker\scripts\01_up.ps1` | 起動して WARP の接続を確認 |
| `.\docker\scripts\02_status.ps1` | コンテナと WARP の状態の確認 |
| `.\docker\scripts\03_logs.ps1` | ログ表示 |
| `.\docker\scripts\04_shell.ps1` | コンテナ内でシェルを開く |
| `.\docker\scripts\05_down.ps1` | 停止・削除 |

一度起動しておけば、Docker Desktop の起動時に自動で立ち上がる。
オプションなどの詳細は [docker/README.md](docker/README.md) を参照。

`docker/` のスクリプトが確認するのは WARP が接続されているかまでで、接続先のことは知らない。
接続先に届くかどうかは `.\scripts\check.ps1` で確認する。

## うまくいかないとき

まず `.\scripts\check.ps1` で状態と疎通を確認する。

| 症状 | 対処 |
|---|---|
| `Docker エンジンに接続できません` | Docker Desktop を起動する |
| `WARP が未登録です` / `Registration Missing` | `.\docker\scripts\00_register.ps1` を実行する |
| WARP は `Connected` だが疎通が NG | Zero Trust 側の Split Tunnel と Tunnel のルートに接続先のアドレスが含まれているか確認する |
| `ssh <ホスト別名>` で `nc: getaddrinfo for host "<ホスト別名>"` | `~/.ssh/config` に同じ名前の古い `Host` の定義が残っている。削除する |
| `ssh` / VS Code で `No such container` | `~/.ssh/config` の `ProxyCommand` のコンテナ名が、起動しているコンテナの名称 (`docker/.env` の `CONTAINER_NAME`) と一致しているか確認する |
| ブラウザからつながらない | コンテナが起動しているか、ZeroOmega で auto switch を選んでいるか確認する |

## 注意

- 届くのは Tunnel のルートに含まれるアドレスだけ。同じ LAN でもルートに無いアドレスには届かない。
- コンテナの名称は `docker/.env` の `CONTAINER_NAME` で変えられる (既定は `cloudflare-zerotrust-proxy`)。
  `.ssh/config` と `~/.ssh/config` の `ProxyCommand` から参照しているので、変更する場合はあわせて直す。
  登録情報の volume も別になるため、再登録が必要になる。
- Zero Trust 側のデバイス名にはコンテナのホスト名 (= コンテナの名称) が使われる。
