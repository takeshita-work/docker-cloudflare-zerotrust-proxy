# 00_register.ps1 が一時的に登録する com.cloudflare.warp:// プロトコルハンドラ。
# ブラウザの「Open in Cloudflare One Client」から渡された URL を、指定されたファイルに書き出すだけ。
# (書き出し先は 00_register.ps1 がハンドラの登録時に引数で渡す)
# (直接は実行しない)
param([string]$Url, [string]$OutFile)

if ($OutFile -and $Url -match '^com\.cloudflare\.warp://[A-Za-z0-9.-]+/auth\?token=[A-Za-z0-9._-]+$') {
    [IO.File]::WriteAllText($OutFile, $Url)
}
