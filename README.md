# cscp — Interactive SCP for Windows

`cscp` is a lightweight interactive wrapper around `scp` (Secure Copy) for fast LAN transfers.  
It prompts for connection details, validates input, and remembers your last usage.

Designed for **Windows PowerShell**, typically targeting devices like Termux over SSH.

---

## Requirements

- Windows 10 / 11 with OpenSSH client (`scp`) available  
- An SSH server on the target device (e.g., Termux)

---

## Install

1. Copy the script:

```powershell
mkdir -Force $HOME\.bin\ps | Out-Null
copy .\cscp.ps1 $HOME\.bin\ps\cscp.ps1
```

2. Run this to add it to your profile:

```powershell
$fn = 'function cscp { powershell -ExecutionPolicy Bypass -File "$HOME\.bin\ps\cscp.ps1" @args }'
if (-not (Select-String -Path $PROFILE -Pattern 'function\s+cscp' -Quiet)) {
    Add-Content -Path $PROFILE -Value "`n$fn"
}
```

3. Reload:

---

## Usage

### Push (Windows → remote)

```powershell
cscp
```

### Pull (remote → Windows)

```powershell
cscp -Pull
```

---

## Features

- Interactive prompts with defaults  
- Input validation (port, IP, paths)  
- Handles quoted Windows paths  
- Detects directories and applies `-r` automatically  
- Retry logic when remote path is a directory  

### History (stateful usage)

`cscp` stores your last inputs in:

```
$HOME\.cscp\history.json
```

It remembers:

- Last IP and port  
- Last push source/destination  
- Last pull source/destination  

This enables:

- Fast repeated transfers (just press Enter)  
- Consistent workflows without retyping paths  
- Smooth back-and-forth push/pull cycles  

---

## Example

### Push to Termux

```powershell
cscp
# Port [8022]: [ENTER]
# IP [192.168.1.]: 42
# Local source: file.txt
# Remote destination [~]: [ENTER]
```

### Pull from device

```powershell
cscp -Pull
# Port [8022]: [ENTER]
# IP [192.168.1.]: 42
# Remote source: ~/notes.txt
# Local destination [.]: Downloads
```

---

## Notes

- Type `q` or press `Esc` at any prompt to abort  
- Tab cycles through local path suggestions  
- Partial IP input (e.g., `42`) expands to `192.168.1.42`  

---

## License

MIT © MBK
