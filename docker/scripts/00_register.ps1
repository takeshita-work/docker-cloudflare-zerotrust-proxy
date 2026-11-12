<#
.SYNOPSIS
  コンテナ内の WARP を Zero Trust 組織にデバイス登録して接続する (初回のみ)。
.DESCRIPTION
  ブラウザでログイン後、「Open in Cloudflare One Client」を押すだけで登録が完了する。
  (登録中だけ com.cloudflare.warp:// の受け口を Windows に一時登録し、トークンを自動で受け取る)
.EXAMPLE
  .\docker\scripts\00_register.ps1                 # チーム名を対話式に入力
  .\docker\scripts\00_register.ps1 -Team my-team
  .\docker\scripts\00_register.ps1 -Team my-team -Force   # 登録済みでもやり直す
#>
param(
    # Zero Trust のチーム名 (<team>.cloudflareaccess.com の <team>)。未指定なら対話式に入力
    [string]$Team,
    # 既存のデバイス登録を削除して登録し直す
    [switch]$Force,
    # トークンの待ち時間 (秒)
    [int]$TimeoutSec = 300
)

. "$PSScriptRoot\_common.ps1"

$TokenPattern = 'com\.cloudflare\.warp://[A-Za-z0-9.-]+/auth\?token=[A-Za-z0-9._-]+'
$TokenFile    = Join-Path $env:TEMP "$Container-warp-token.txt"   # _token_handler.ps1 の書き出し先
$ProtoKey     = 'HKCU:\Software\Classes\com.cloudflare.warp'

Assert-Docker

# コンテナが未起動なら起動する
Start-Container

# 登録済みなら何もしない
$status = Wait-WarpService
if ($status -notmatch 'Registration Missing') {
    if (-not $Force) {
        Write-Host 'すでにデバイス登録済みです。やり直す場合は -Force を付けてください。' -ForegroundColor Yellow
        & "$PSScriptRoot\02_status.ps1"
        exit $LASTEXITCODE
    }
    Invoke-Warp registration delete
}

while (-not $Team) {
    $Team = (Read-Host 'Zero Trust のチーム名 (<team>.cloudflareaccess.com の <team>)').Trim()
}
# URL やドメインごと貼り付けられてもチーム名だけを取り出す
$Team = $Team -replace '^https?://', '' -replace '\.cloudflareaccess\.com.*$', '' -replace '/.*$', ''
if ($Team -notmatch '^[A-Za-z0-9-]+$') {
    throw "チーム名の形式が正しくありません: $Team"
}

Invoke-Warp registration new $Team | Out-Null

# --- トークンの受け口を一時登録 (Windows 側に Cloudflare One Client が無い場合のみ) ---
$handlerRegistered = $false
$hasOtherHandler = (Test-Path $ProtoKey) -or (Test-Path 'HKLM:\Software\Classes\com.cloudflare.warp')
Remove-Item -LiteralPath $TokenFile -ErrorAction SilentlyContinue

$token = $null
try {
    if (-not $hasOtherHandler) {
        $handler = Join-Path $PSScriptRoot '_token_handler.ps1'
        $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$handler`" `"%1`" `"$TokenFile`""
        New-Item -Path "$ProtoKey\shell\open\command" -Force | Out-Null
        Set-ItemProperty -Path $ProtoKey -Name '(default)' -Value "URL:Cloudflare WARP token ($Container docker)"
        New-ItemProperty -Path $ProtoKey -Name 'URL Protocol' -Value '' -Force | Out-Null
        Set-ItemProperty -Path "$ProtoKey\shell\open\command" -Name '(default)' -Value $command
        $handlerRegistered = $true
    }

    $url = "https://$Team.cloudflareaccess.com/warp"
    Write-Host ''
    Write-Host "ブラウザで $url を開きます。ログインしてください。" -ForegroundColor Cyan
    Start-Process $url
    Write-Host ''
    if ($handlerRegistered) {
        Write-Host 'ログイン後、ブラウザのダイアログで「開く」(または画面の'
        Write-Host '「Open in Cloudflare One Client」ボタン) を押してください。自動で登録が進みます。'
    } else {
        Write-Host 'Windows 側に Cloudflare One Client があるため、自動受け取りは使えません。'
        Write-Host 'ブラウザのダイアログはキャンセルし、下の方法でトークンをコピーしてください。'
    }
    Write-Host ''
    Write-Host '(うまくいかない場合) F12 > Elements で「Open in Cloudflare One Client」ボタンを選んで' -ForegroundColor DarkGray
    Write-Host '  Ctrl+C でコピーすると、クリップボードから自動で読み取ります。' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host "トークンを待っています... (最大 $TimeoutSec 秒 / 中止は Ctrl+C)"

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while (-not $token -and (Get-Date) -lt $deadline) {
        $text = $null
        if (Test-Path -LiteralPath $TokenFile) {
            $text = [IO.File]::ReadAllText($TokenFile)
        } else {
            try { $text = Get-Clipboard -Raw -ErrorAction Stop } catch { $text = $null }
        }
        if ($text -and $text -match $TokenPattern) { $token = $Matches[0]; break }
        Start-Sleep -Milliseconds 500
    }
}
finally {
    if ($handlerRegistered) { Remove-Item -Path $ProtoKey -Recurse -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $TokenFile -ErrorAction SilentlyContinue
}

if (-not $token) { throw 'トークンを受け取れませんでした (タイムアウト)。もう一度実行してください。' }

Write-Host 'トークンを受け取りました。登録します...' -ForegroundColor Green
Invoke-Warp registration token $token
if ($LASTEXITCODE -ne 0) { throw 'デバイス登録に失敗しました。トークンは短時間で失効するので、もう一度実行してください。' }

Invoke-Warp connect
Wait-WarpConnected
& "$PSScriptRoot\02_status.ps1"
exit $LASTEXITCODE
