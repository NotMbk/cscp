param(
    [switch]$p  # pull mode
)

function QuitIfQ($v) {
    if ($v -eq 'q') { exit }
}

function NormalizePath($path) {
    # Remove surrounding quotes if they exist
    if ($path -match '^".*"$') {
        $path = $path.Trim('"')
    }
    return $path
}

function QuoteIfNeeded($path) {
    if ($path -match '\s') {
        return "`"$path`""
    }
    return $path
}

function Ask($msg, $default = $null) {
    if ($default) {
        $v = Read-Host "$msg [$default]"
        QuitIfQ $v
        if (-not $v) { return $default }
        return $v
    }
    $v = Read-Host $msg
    QuitIfQ $v
    return $v
}

function IsValidPort($p) {
    return ($p -match '^\d{1,5}$' -and [int]$p -ge 1 -and [int]$p -le 65535)
}

function IsValidIP($ip) {
    return [System.Net.IPAddress]::TryParse($ip, [ref]$null)
}

# ---- PORT ----
do {
    $port = Ask "Port" "8022"
} until (IsValidPort $port)

# ---- IP ----
do {
    $ipInput = Ask "IP" "192.168.1."
    if ($ipInput -match '^\d{1,3}$') {
        $ip = "192.168.1.$ipInput"
    } else {
        $ip = $ipInput
    }
} until (IsValidIP $ip)

if (-not $p) {
	# -------- PUSH --------
	$src = Ask "Local file path"
	$src = NormalizePath $src

	if (-not (Test-Path $src -PathType Leaf)) {
    	Write-Error "Source file does not exist"
    	exit 1
	}

	$dst = Ask "Remote destination" "~"
	$src = QuoteIfNeeded $src
	
scp -P $port $src "${ip}:$dst"
}
else {
   	# -------- PULL --------
	$src = Ask "Remote file path"
	$dst = Ask "Local destination" "."

	$dst = NormalizePath $dst

	if (-not (Test-Path $dst -PathType Container)) {
    	Write-Error "Destination directory does not exist"
    	exit 1
	}

	$dst = QuoteIfNeeded $dst
	scp -P $port "${ip}:$src" $dst
}