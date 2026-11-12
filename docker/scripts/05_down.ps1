<#
.SYNOPSIS
  WARP コンテナを停止・削除する。
.EXAMPLE
  .\docker\scripts\05_down.ps1
  .\docker\scripts\05_down.ps1 -RemoveData   # デバイス登録情報も削除
#>
param(
    # デバイス登録情報の volume も削除する (再登録が必要になる)
    [switch]$RemoveData
)

. "$PSScriptRoot\_common.ps1"
Assert-Docker

if ($RemoveData) { Invoke-Compose down -v } else { Invoke-Compose down }
exit $LASTEXITCODE
