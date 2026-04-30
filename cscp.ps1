<#
    cscp.ps1 - Usage:
        cscp          -> Push
        cscp -Pull    -> Pull
        cscp -Multi   -> Multi-Push
#>
param([switch]$Pull, [switch]$Multi)

$ConfigDir   = Join-Path $HOME ".cscp"
$HistoryFile = Join-Path $ConfigDir "history.json"
if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }

$H = if (Test-Path $HistoryFile) { try { Get-Content $HistoryFile -Raw | ConvertFrom-Json } catch { $null } }
if (-not $H) {
    $H = [PSCustomObject]@{ IP="192.168.1."; Port="8022"; PushSrc=$null; PushDst="~"; PullSrc=$null; PullDst="." }
}

function Save  { $H | ConvertTo-Json -Depth 3 | Set-Content $HistoryFile -Force }
function Ask($msg, $def="") {
    $v = Read-Host "$(if($def){"$msg [$def]"}else{$msg})"
    if ($v -match '^[qQ]$') { exit }
    if (-not $v) { return $def }
    return $v.Trim('"',"'")
}

$H.Port = Ask "Port" $H.Port
$raw    = Ask "IP"   $H.IP
$H.IP   = if ($raw -match '^\d{1,3}$') { "192.168.1.$raw" } else { $raw }

if (-not $Pull -and -not $Multi) {
    $H.PushSrc = Ask "Source"      $H.PushSrc
    $H.PushDst = Ask "Remote dest" $H.PushDst
    $isDir = (Get-Item $H.PushSrc -EA SilentlyContinue)?.PSIsContainer
    if ($isDir) { scp -r -P $H.Port $H.PushSrc "$($H.IP):$($H.PushDst)" }
    else        { scp    -P $H.Port $H.PushSrc "$($H.IP):$($H.PushDst)" }

} elseif ($Multi) {
    $srcs      = (Ask "Sources (space-separated)" $H.PushSrc) -split '\s+' | Where-Object { $_ }
    $H.PushSrc = $srcs -join ' '
    $H.PushDst = Ask "Remote dest" $H.PushDst
    foreach ($s in $srcs) {
        $isDir = (Get-Item $s -EA SilentlyContinue)?.PSIsContainer
        if ($isDir) { scp -r -P $H.Port $s "$($H.IP):$($H.PushDst)" }
        else        { scp    -P $H.Port $s "$($H.IP):$($H.PushDst)" }
    }

} else {
    $H.PullSrc = Ask "Remote source" $H.PullSrc
    $H.PullDst = Ask "Local dest"    $H.PullDst
    $forceR    = $H.PullSrc.EndsWith('/') -or $H.PullSrc.Contains('*')
    if ($forceR) {
        scp -r -P $H.Port "$($H.IP):$($H.PullSrc)" $H.PullDst
    } else {
        $tmp = [System.IO.Path]::GetTempFileName()
        scp -P $H.Port "$($H.IP):$($H.PullSrc)" $H.PullDst 2>$tmp
        if ($LASTEXITCODE -ne 0 -and (Get-Content $tmp -Raw) -match 'not a regular file') {
            scp -r -P $H.Port "$($H.IP):$($H.PullSrc)" $H.PullDst
        }
        Remove-Item $tmp -Force -EA SilentlyContinue
    }
}

Save
