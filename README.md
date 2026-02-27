# cscp — Interactive SCP for Windows

`cscp` is a small interactive PowerShell helper around `scp` (Secure Copy) to make LAN file transfers easier.  
Instead of memorizing flags, it prompts for port, IP, and paths with validation and sensible defaults.

This tool *only targets Windows users*. Termux/Android clients are expected as SCP targets, but this script runs on **Windows PowerShell**.

---

## Requirements

- **Windows 10 / 11** with **OpenSSH client** enabled (optional feature).  
  Windows includes `scp` via the OpenSSH client if the feature is installed.:contentReference[oaicite:0]{index=0}  
- SCP server (e.g., Termux SSH server) on the destination device.

You don’t need anything else — no third-party tools.

---

## Quick Install

1. Place `cscp.ps1` in a folder (e.g., `C:\Users\<you>\bin`)
2. Add this to your PowerShell profile (`$PROFILE`):

```powershell
function cscp { powershell -ExecutionPolicy Bypass -File "C:\Users\<you>\bin\cscp.ps1" @args }
```

3.Reload PowerShell:

```powershell
. $PROFILE
```

# Usage
Push (Windows → remote)

```powershell
cscp
```
Steps:

Port (default: 8022)

IP (default hint 192.168.1. — type last byte or full IP)

Local file (handles pasted "C:\path\with spaces")

Remote destination (default ~)

Pull (remote → Windows)

```powershell
cscp -p
```

Same logic but reverses source/destination.

What Makes It Better

Validates port as a real number (1–65535)

Accepts partial or full IP and validates it

Normalizes copied Windows paths (strips quotes)

Validates that local files/dirs exist before running scp

# Example

## Push a file to Android (Termux):

```powershell
cscp
# Port [8022]: [ENTER]
# IP [192.168.1.]: 42
# Local file path: "C:\Users\you\file.txt"
# Remote destination [~]: [ENTER]
```

## Pull from phone:

```
cscp -p
# Port [8022]: [ENTER]
# IP [192.168.1.]: 42
# Remote file path: ~/notes.txt
# Local destination [.]: Downloads
```

# Future Enhancements (ideas)

* arp -a-assisted IP selection

* fzf for local path picking

* Named host presets (e.g., cscp phone)

* Cross-platform Bash version for Linux/macOS

# License

MIT © MBK