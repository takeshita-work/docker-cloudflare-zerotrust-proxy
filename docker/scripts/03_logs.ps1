<#
.SYNOPSIS
  コンテナのログを表示する。
.EXAMPLE
  .\docker\scripts\03_logs.ps1
  .\docker\scripts\03_logs.ps1 -Follow
#>
param(
    [switch]$Follow,
    [int]$Tail = 100
)

. "$PSScriptRoot\_common.ps1"
Assert-Docker

if ($Follow) { Invoke-Compose logs --tail $Tail -f } else { Invoke-Compose logs --tail $Tail }
exit $LASTEXITCODE
