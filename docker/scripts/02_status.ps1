<#
.SYNOPSIS
  コンテナの状態と WARP の接続状態を確認する。
.DESCRIPTION
  確認するのは WARP が接続されているかまで。
  接続先への疎通は、リポジトリのルートの .\scripts\check.ps1 で確認する。
.EXAMPLE
  .\docker\scripts\02_status.ps1
#>

. "$PSScriptRoot\_common.ps1"
Assert-Docker

Write-Host '== コンテナ ==' -ForegroundColor Cyan
Invoke-Compose ps
Assert-Running

Write-Host ''
Write-Host '== WARP ==' -ForegroundColor Cyan
$status = Get-WarpStatus
Write-Host $status.Trim()
if ($status -notmatch 'Status update: Connected') {
    Write-Host 'NG: WARP が接続されていません (未登録なら .\docker\scripts\00_register.ps1 を実行)' -ForegroundColor Yellow
    exit 1
}
exit 0
