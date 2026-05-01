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

# -- Read-WithCompletion -------------------------------------------------------
function Read-WithCompletion {
    param(
        [string]$Prompt,
        [string]$Default = "",
        [string[]]$Candidates = @()
    )

    Write-Host -NoNewline "$Prompt [$Default]: "

    $buf        = [System.Text.StringBuilder]::new()
    $tabIndex   = -1
    $tabBase    = ""
    $tabMatches = @()

    while ($true) {
        $k = [Console]::ReadKey($true)

        if ($k.Key -eq 'Enter') {
            Write-Host ""
            $result = $buf.ToString().Trim('"', "'")
            if ($result -eq 'q' -or $result -eq 'Q') {
                Write-Host "Aborted." -ForegroundColor DarkGray
                exit
            }
            if ($result -eq "") { return $Default }
            return $result
        }

        if ($k.Key -eq 'Escape' -or ($k.Key -eq 'q' -and $buf.Length -eq 0)) {
            Write-Host ""
            Write-Host "Aborted." -ForegroundColor DarkGray
            exit
        }

        if ($k.Key -eq 'Backspace') {
            if ($buf.Length -gt 0) {
                $buf.Remove($buf.Length - 1, 1) | Out-Null
                [Console]::Write("`b `b")
                $tabIndex = -1
            }
            continue
        }

        if ($k.Key -eq 'Tab') {
            if ($Candidates.Count -eq 0) { continue }

            if ($tabIndex -eq -1) {
                $tabBase    = $buf.ToString()
                $tabMatches = $Candidates | Where-Object { $_ -like "$tabBase*" }
                if ($tabMatches.Count -eq 0) { continue }
            }

            $tabIndex   = ($tabIndex + 1) % $tabMatches.Count
            $completion = $tabMatches[$tabIndex]

            $clearLen = $buf.Length
            [Console]::Write("`r" + "$Prompt [$Default]: " + (" " * $clearLen) + "`r" + "$Prompt [$Default]: ")
            $buf.Clear() | Out-Null
            $buf.Append($completion) | Out-Null
            [Console]::Write($completion)
            continue
        }

        $tabIndex = -1
        $char = $k.KeyChar
        if ([char]::IsControl($char)) { continue }
        $buf.Append($char) | Out-Null
        [Console]::Write($char)
    }
}

function Ask {
    param([string]$Prompt, [string]$Default = "")
    return Read-WithCompletion -Prompt $Prompt -Default $Default -Candidates @()
}

function Ask-Path {
    param([string]$Prompt, [string]$Default = "", [switch]$DirsOnly)

    $candidates = @()
    try {
        if ($DirsOnly) {
            $candidates = Get-ChildItem -Path "." -Recurse -Directory -ErrorAction SilentlyContinue |
                          Select-Object -ExpandProperty FullName |
                          ForEach-Object { $_.Replace($PWD.Path + [IO.Path]::DirectorySeparatorChar, "") }
        } else {
            $candidates = Get-ChildItem -Path "." -Recurse -File -ErrorAction SilentlyContinue |
                          Select-Object -ExpandProperty FullName |
                          ForEach-Object { $_.Replace($PWD.Path + [IO.Path]::DirectorySeparatorChar, "") }
        }
    } catch {}

    return Read-WithCompletion -Prompt $Prompt -Default $Default -Candidates $candidates
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

    if ($errText) { Write-Host $errText -ForegroundColor Red }
}

# -- Header --------------------------------------------------------------------
$modeLabel = if ($Pull) { "PULL" } else { "PUSH" }
Write-Host "  cscp // $modeLabel" -ForegroundColor Cyan
Write-Host "  (q or Esc to quit)" -ForegroundColor DarkGray
Write-Host ""

# -- Connection ----------------------------------------------------------------
$port    = Ask "Port" $History.LastPort
$History.LastPort = $port

$ipInput = Ask "IP" $History.LastIP
$ip      = if ($ipInput -match '^\d{1,3}$') { "192.168.1.$ipInput" } else { $ipInput }
$History.LastIP = $ip
Write-Host ""

# =============================================================================
#  PUSH
# =============================================================================
if (-not $Pull) {

    $src = Ask-Path "Local source"       $History.LastPushSrc
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

# =============================================================================
#  PULL
# =============================================================================
else {

    $src = Ask      "Remote source"     $History.LastPullSrc
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
Write-Host ""
Write-Host "Done." -ForegroundColor Green
