<#
.SYNOPSIS
  .ssh\config に定義した接続先に、WARP コンテナを踏み台にして SSH 接続する。
.DESCRIPTION
  .ssh\config の最初の Host を接続先にし、WARP コンテナを踏み台にして接続する。
  .ssh\config が無ければ .ssh\config.example から作り、接続先を対話式に設定する。
  コンテナが止まっていれば起動し、WARP の接続を待ってから ssh を実行する。
.EXAMPLE
  .\scripts\access.ps1
  .\scripts\access.ps1 -L 8888:localhost:8888     # ssh のオプションはそのまま渡せる
  .\scripts\access.ps1 nvidia-smi                 # リモートでコマンドを実行
#>

. "$PSScriptRoot\_common.ps1"

$HostAlias = Resolve-SshHost

# --- WARP コンテナの準備 (未起動なら起動し、WARP の接続を待つ) ---
Start-Warp -IfStopped

# --- 接続 ---
& ssh -F $SshConfig $HostAlias @args
exit $LASTEXITCODE
