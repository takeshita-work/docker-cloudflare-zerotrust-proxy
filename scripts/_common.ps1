# scripts\ の各スクリプトから dot-source して使う共通定義 (直接は実行しない)
# 接続先は .ssh\config で管理する。コンテナ側の定義は docker\scripts\_common.ps1 を使う

$Root = Split-Path -Parent $PSScriptRoot
. (Join-Path $Root 'docker\scripts\_common.ps1')

$SshConfig  = Join-Path $Root '.ssh\config'
$SshExample = Join-Path $Root '.ssh\config.example'

# .ssh\config を使える状態にして、接続先 (最初の Host) の別名を返す
# - 無ければ .ssh\config.example から作る
# - 未設定の項目 (__...__) があれば対話式に設定して保存する
function Resolve-SshHost {
    if (-not (Test-Path -LiteralPath $SshConfig)) {
        if (-not (Test-Path -LiteralPath $SshExample)) { throw "SSH 設定のひな形が見つかりません: $SshExample" }
        Copy-Item -LiteralPath $SshExample -Destination $SshConfig
        Write-Host '.ssh\config を作成しました。接続先を設定します。'
    }

    $utf8 = New-Object Text.UTF8Encoding $false   # ssh は BOM 付きを読めないので BOM なし
    $config = [IO.File]::ReadAllText($SshConfig, $utf8)
    $placeholders = @(
        @{ Key = '__HOST_ALIAS__'; Prompt = '接続先の名前 (ssh で使うホスト別名。例: my-server)'; Pattern = '^[A-Za-z0-9._-]+$' },
        @{ Key = '__HOST_NAME__';  Prompt = '接続先のアドレス (IP アドレスまたはホスト名)';       Pattern = '^[A-Za-z0-9.:_-]+$' },
        @{ Key = '__USER__';       Prompt = 'ログインユーザー名';                                 Pattern = '^[A-Za-z0-9._-]+$' }
    )
    $changed = $false
    if ($config.Contains('__CONTAINER__')) {
        $config  = $config.Replace('__CONTAINER__', $Container)   # docker\.env の CONTAINER_NAME
        $changed = $true
    }
    foreach ($p in $placeholders) {
        if (-not $config.Contains($p.Key)) { continue }
        $value = ''
        while ($value -notmatch $p.Pattern) { $value = (Read-Host $p.Prompt).Trim() }
        $config  = $config.Replace($p.Key, $value)
        $changed = $true
    }
    if ($changed) {
        [IO.File]::WriteAllText($SshConfig, $config, $utf8)
        Write-Host '設定を .ssh\config に保存しました。'
    }

    # ProxyCommand のコンテナ名が docker\.env の CONTAINER_NAME と食い違っていないか
    if ($config -match '(?im)^\s*ProxyCommand\s+docker\s+exec\s+-i\s+(\S+)' -and $Matches[1] -ne $Container) {
        Write-Warning ".ssh\config の ProxyCommand のコンテナ名 ($($Matches[1])) が、起動するコンテナ名 ($Container) と違います。.ssh\config を直してください。"
    }

    # 接続先は最初の Host (ワイルドカードを除く)
    foreach ($m in [regex]::Matches($config, '(?im)^\s*Host\s+(\S+)')) {
        $name = $m.Groups[1].Value
        if ($name -notmatch '[*?!]') { return $name }
    }
    throw "接続先 (Host) が .ssh\config に定義されていません: $SshConfig"
}

# ホスト別名から、実際の接続先 (アドレスとポート) を .ssh\config の定義どおりに解決する
function Get-SshTarget {
    param([Parameter(Mandatory)][string]$HostAlias)
    $lines = & ssh -F $SshConfig -G $HostAlias
    if ($LASTEXITCODE -ne 0) { throw ".ssh\config を読み取れません: $SshConfig" }
    $target = @{ Host = $null; Port = '22' }
    foreach ($line in $lines) {
        if ($line -match '^hostname\s+(\S+)') { $target.Host = $Matches[1] }
        elseif ($line -match '^port\s+(\d+)') { $target.Port = $Matches[1] }
    }
    if (-not $target.Host) { throw "接続先のアドレスを解決できません: $HostAlias" }
    $target
}
