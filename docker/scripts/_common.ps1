# 各スクリプトから dot-source して使う共通定義 (直接は実行しない)
# compose.yaml の場所を $PSScriptRoot から解決するので、どのディレクトリから実行しても動く

$ErrorActionPreference = 'Stop'

$DockerDir   = Split-Path -Parent $PSScriptRoot
$ComposeFile = Join-Path $DockerDir 'compose.yaml'
$Service     = 'warp'

# docker\.env (任意) を読む。KEY=VALUE 形式のみ対応
function Get-DotEnv {
    $map  = @{}
    $path = Join-Path $DockerDir '.env'
    if (Test-Path -LiteralPath $path) {
        foreach ($line in [IO.File]::ReadAllLines($path)) {
            if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
                $map[$Matches[1]] = $Matches[2].Trim('"', "'")
            }
        }
    }
    $map
}

$DotEnv = Get-DotEnv

# コンテナ名 (docker\.env の CONTAINER_NAME)
# 既定値は compose.yaml の ${CONTAINER_NAME:-...} と同じ値にする (変える場合は両方を直す)
$Container = if ($DotEnv['CONTAINER_NAME']) { $DotEnv['CONTAINER_NAME'] } else { 'cloudflare-zerotrust-proxy' }
if ($Container -notmatch '^[a-z0-9][a-z0-9-]*$') {
    throw "docker\.env の CONTAINER_NAME の形式が正しくありません (小文字の英数字とハイフンのみ): $Container"
}

function Invoke-Compose {
    & docker compose -f $ComposeFile @args
}

function Invoke-Warp {
    Invoke-Compose exec -T $Service warp-cli --accept-tos @args
}

function Get-WarpStatus {
    (Invoke-Warp status | Out-String)
}

function Assert-Docker {
    # Windows PowerShell 5.1 は、'Stop' のままエラー出力を捨てると例外になるので、ここだけ 'Continue' にする
    $ErrorActionPreference = 'Continue'
    $ok = $false
    try {
        & docker info --format '{{.ServerVersion}}' *> $null
        $ok = ($LASTEXITCODE -eq 0)
    } catch { }
    if (-not $ok) {
        throw 'Docker エンジンに接続できません。Docker Desktop を起動してください。'
    }
}

function Test-Running {
    [bool](Invoke-Compose ps -q --status running $Service)
}

function Assert-Running {
    if (-not (Test-Running)) {
        throw 'コンテナが起動していません。先に .\docker\scripts\01_up.ps1 を実行してください。'
    }
}

function Start-Container {
    param([switch]$Build)
    if ($Build) { Invoke-Compose up -d --build } else { Invoke-Compose up -d }
    if ($LASTEXITCODE -ne 0) { throw 'コンテナの起動に失敗しました。' }
}

# warp-svc が応答するまで待ち、その時点の状態文字列を返す
function Wait-WarpService {
    param([int]$TimeoutSec = 30)
    foreach ($i in 1..$TimeoutSec) {
        $status = Get-WarpStatus
        if ($status -match 'Status update|Registration') { return $status }
        Start-Sleep -Seconds 1
    }
    throw 'warp-svc が応答しません。.\docker\scripts\03_logs.ps1 でログを確認してください。'
}

# WARP が Connected になるまで待つ (未登録なら登録スクリプトを案内して停止)
function Wait-WarpConnected {
    param([int]$TimeoutSec = 40)
    foreach ($i in 1..$TimeoutSec) {
        $status = Get-WarpStatus
        if ($status -match 'Registration Missing') {
            throw 'WARP が未登録です。先に .\docker\scripts\00_register.ps1 を実行してください。'
        }
        if ($status -match 'Status update: Connected') { return }
        if ($i -eq 2) { Write-Host 'WARP の接続を待っています...' }
        Start-Sleep -Seconds 1
    }
    throw 'WARP が接続状態になりません。.\docker\scripts\02_status.ps1 で確認してください。'
}

# コンテナを使える状態にする (起動して WARP の接続を待つ)
#   -Build     イメージを再ビルドしてから起動する
#   -IfStopped 起動済みなら何もしない (compose up を省くので、設定変更の反映もしない)
function Start-Warp {
    param([switch]$Build, [switch]$IfStopped)
    Assert-Docker
    if (-not $IfStopped) {
        Start-Container -Build:$Build
    } elseif (-not (Test-Running)) {
        Write-Host 'WARP コンテナを起動します...'
        Start-Container -Build:$Build
    }
    Wait-WarpConnected
}
