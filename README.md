# GTK-Syncthing

Automatic file sync across **Windows and macOS** — one app, one click.

---

## For end users

| | Windows | Mac |
|---|---------|-----|
| **Open this** | **`GKG-Sync.cmd`** | **`GKG-Sync.command`** |

Pick an action from the menu:

1. **Install / Add machine**
2. **Restart sync**
3. **Open Sync folder**
4. **Guide**
5. **Syncthing dashboard**

Install [Tailscale](https://tailscale.com) first (same account on every machine).

Legacy shortcuts (`Cai-Dat-Sync.cmd`, `Bat-Dau-O-Day.cmd`, …) still work — they open the same menu or run one action.

See **`START-HERE.html`** for a visual guide.

---

## Technical notes

Uses [Syncthing](https://syncthing.net/) over [Tailscale](https://tailscale.com/).  
Shared config: **`config.ini`**. Build zip: `.\tao-goi-cai.ps1`
