<#
    cscp.ps1 - Interactive SCP Tool
    Usage:
        .\cscp.ps1        -> Push
        .\cscp.ps1 -Pull  -> Pull
#>
param(
    [switch]$Pull
)

$ConfigDir   = Join-Path $HOME ".cscp"
$HistoryFile = Join-Path $ConfigDir "history.json"

if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

# -- Defaults ------------------------------------------------------------------
$DefaultPort = "8022"
$DefaultIP   = "192.168.1."
$DefaultDir  = "."

# -- History -------------------------------------------------------------------
$History = if (Test-Path $HistoryFile) {
    try { Get-Content $HistoryFile -Raw | ConvertFrom-Json } catch { $null }
}

if (-not $History) {
    $History = [PSCustomObject]@{
        LastIP      = $DefaultIP
        LastPort    = $DefaultPort
        LastPushSrc = $null
        LastPushDst = "~"
        LastPullSrc = $null
        LastPullDst = $DefaultDir
    }
}

function Save-History {
    $History | ConvertTo-Json -Depth 3 | Set-Content $HistoryFile -Force
}

# -- Expand ~ in local paths ---------------------------------------------------
function Expand-LocalPath {
    param([string]$Path)
    if ($Path -match '^~[/\\]?(.*)$') {
        return Join-Path $HOME $matches[1]
    }
    return $Path
}

# -- Simple input -------------------------------------------------------------
function Ask {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )

    if ($Default) {
        Write-Host -NoNewline "$Prompt [$Default]: "
    } else {
        Write-Host -NoNewline "${Prompt}: "
    }

    $input = Read-Host

    if ([string]::IsNullOrWhiteSpace($input)) {
        return $Default
    }

    if ($input -eq 'q' -or $input -eq 'Q') {
        Write-Host "Aborted." -ForegroundColor DarkGray
        exit
    }

    return $input
}

function Ask-Path {
    param(
        [string]$Prompt,
        [string]$Default = "",
        [switch]$DirsOnly
    )

    return Ask $Prompt $Default
}

# -- SCP -----------------------------------------------------------------------
function Invoke-Scp {
    param(
        [string]$Port,
        [string]$Src,
        [string]$Dst,
        [switch]$Recursive,
        [switch]$AllowRetry
    )

    $scpArgs = @("-P", $Port)
    if ($Recursive) { $scpArgs += "-r" }
    $scpArgs += $Src
    $scpArgs += $Dst

    $tmpErr = [System.IO.Path]::GetTempFileName()
    $proc   = Start-Process -FilePath "scp" `
                            -ArgumentList $scpArgs `
                            -NoNewWindow -Wait -PassThru `
                            -RedirectStandardError $tmpErr

    $errText = ""
    if (Test-Path $tmpErr) {
        $errText = Get-Content $tmpErr -Raw
        Remove-Item $tmpErr -Force
    }

    if ($proc.ExitCode -ne 0 -and $AllowRetry -and (-not $Recursive) -and $errText -match "not a regular file") {
        Write-Host "  Remote path looks like a directory -- retrying with -r" -ForegroundColor DarkGray
        Invoke-Scp -Port $Port -Src $Src -Dst $Dst -Recursive
        return
    }

    if ($errText) {
        Write-Host $errText -ForegroundColor Red
    }
}

# -- Header --------------------------------------------------------------------
Write-Host "(q to quit)" -ForegroundColor DarkGray

# -- Connection ----------------------------------------------------------------
$port = Ask "Port" $History.LastPort
$History.LastPort = $port

$ipInput = Ask "IP" $History.LastIP
$ip = if ($ipInput -match '^\d{1,3}$') { "192.168.1.$ipInput" } else { $ipInput }
$History.LastIP = $ip

Write-Host ""

# PUSH
if (-not $Pull) {

    $src = Ask-Path "Local source" $History.LastPushSrc
    $dst = Ask      "Remote destination" $History.LastPushDst

    $History.LastPushSrc = $src
    $History.LastPushDst = $dst

    $src   = Expand-LocalPath $src
    $item  = Get-Item $src -ErrorAction SilentlyContinue
    $isDir = $item -and $item.PSIsContainer

    Write-Host ""
    Write-Host "-> Push : scp -P $port `"$src`" ${ip}:`"$dst`"" -ForegroundColor Yellow

    Invoke-Scp -Port $port -Src $src -Dst "${ip}:$dst" -Recursive:$isDir
}

# PULL
else {

    $src = Ask      "Remote source" $History.LastPullSrc
    $dst = Ask-Path "Local destination" $History.LastPullDst -DirsOnly

    $History.LastPullSrc = $src
    $History.LastPullDst = $dst

    $dst = Expand-LocalPath $dst

    Write-Host ""
    Write-Host "-> Pull : scp -P $port ${ip}:`"$src`" `"$dst`"" -ForegroundColor Yellow

    Invoke-Scp -Port $port -Src "${ip}:$src" -Dst $dst -AllowRetry
}

# -- Wrap up -------------------------------------------------------------------
Save-History
