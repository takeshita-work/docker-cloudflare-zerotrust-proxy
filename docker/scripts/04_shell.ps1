<#
.SYNOPSIS
  コンテナ内で bash を開く (引数を渡すとそのコマンドを実行)。
.EXAMPLE
  .\docker\scripts\04_shell.ps1
  .\docker\scripts\04_shell.ps1 warp-cli --accept-tos status
#>

. "$PSScriptRoot\_common.ps1"
Assert-Docker
Assert-Running

if ($args.Count -gt 0) {
    Invoke-Compose exec $Service @args
} else {
    Invoke-Compose exec $Service bash
}
exit $LASTEXITCODE
