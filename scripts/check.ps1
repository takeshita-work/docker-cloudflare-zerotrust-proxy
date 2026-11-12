<#
.SYNOPSIS
  コンテナと WARP の状態に加えて、接続先への疎通を確認する。
.DESCRIPTION
  .ssh\config の最初の Host (access.ps1 と同じ接続先) に、コンテナの中から届くかを確認する。
  コンテナは起動しない (止まっている場合は .\docker\scripts\01_up.ps1 で起動する)。
.EXAMPLE
  .\scripts\check.ps1
#>

. "$PSScriptRoot\_common.ps1"

$HostAlias = Resolve-SshHost
$target    = Get-SshTarget $HostAlias

# --- コンテナと WARP の状態 ---
& (Join-Path $DockerDir 'scripts\02_status.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# --- 接続先への疎通 (コンテナの中から確認する) ---
Write-Host ''
Write-Host "== 疎通 ($HostAlias = $($target.Host):$($target.Port)) ==" -ForegroundColor Cyan
Invoke-Compose exec -T $Service nc -z -w 5 $target.Host $target.Port
if ($LASTEXITCODE -eq 0) {
    Write-Host 'OK: 接続できました' -ForegroundColor Green
} else {
    Write-Host 'NG: 接続できません (Zero Trust 側の Split Tunnel と Tunnel のルートに接続先が含まれているか確認)' -ForegroundColor Yellow
    exit 1
}
