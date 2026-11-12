<#
.SYNOPSIS
  WARP コンテナを起動し、WARP の接続を確認する。
.EXAMPLE
  .\docker\scripts\01_up.ps1
  .\docker\scripts\01_up.ps1 -Build
#>
param(
    # イメージを再ビルドしてから起動する
    [switch]$Build
)

. "$PSScriptRoot\_common.ps1"

Start-Warp -Build:$Build
& "$PSScriptRoot\02_status.ps1"
exit $LASTEXITCODE
