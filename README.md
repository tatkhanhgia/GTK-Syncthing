# GTK-Syncthing

Automatic file sync across multiple Windows machines using **[Syncthing](https://syncthing.net/)** over **[Tailscale](https://tailscale.com/)**.

No coding required — double-click a launcher and follow the on-screen prompts.

---

## Quick start

1. Extract (or clone) this repo to a folder, e.g. `C:\Users\You\Documents\GTK-Syncthing`
2. Double-click **`Cai-Dat-Sync.cmd`**
3. Follow the setup wizard

For detailed instructions, run **`Huong-Dan.cmd`** or read **`README.txt`** (Vietnamese, plain text).

## Launchers

| File | Purpose |
|------|---------|
| `Cai-Dat-Sync.cmd` | First-time install / add a new machine |
| `Huong-Dan.cmd` | Open the HTML guide in your browser |
| `Khoi-Dong-Sync.cmd` | Restart Syncthing if it was stopped |

**Default sync folder:** `%USERPROFILE%\Documents\Sync`  
**Syncthing web UI:** [http://127.0.0.1:8384](http://127.0.0.1:8384)

## Requirements

- Windows 10 or 11
- [Tailscale](https://tailscale.com) — same account on every machine
- Network connectivity (Syncthing is installed automatically via winget or portable bundle)

## Configuration (optional)

On first run, the installer creates `config.ps1` from `config.example.ps1`.

Edit `config.ps1` to pre-fill peer Device IDs in `$Peers` — optional; you can also paste IDs during setup.

> `config.ps1` is local to each machine and is listed in `.gitignore`.

## For maintainers

Build a distributable zip:

```powershell
.\tao-goi-cai.ps1
# Output: %USERPROFILE%\Documents\Sync\GKG-Syncthing.zip
```

## Legacy mode

The `legacy/` folder contains an older SSH/Unison workflow (two machines only). It is not used in the default Syncthing setup.

## Related

The API docs project (`api-document-specification`) lives in the same parent workspace. Use this sync pack to copy formatted doc files between machines — the two projects are independent in code.
