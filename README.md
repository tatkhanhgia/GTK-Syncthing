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
6. **Join network** *(auto device sync — new)*
7. **Sync now** *(trigger membership sync immediately — new)*

> **New in latest version:** designate one machine as the **hub**, and every other machine just runs **"Join network"** (menu item 6) pasting only the hub's Device ID once. Devices are added automatically via Syncthing's introducer, and the sync folder's membership updates itself — no more hand-pasting every Device ID into `config.ini` on each machine. See `config.ini` → `[network]` and the guide (`HUONG-DAN.html`) for details.

Install [Tailscale](https://tailscale.com) first (same account on every machine).

Legacy shortcuts (in `shortcuts/`) still work — `Cai-Dat-Sync.cmd` and friends open the same menu or run one action.

See **`START-HERE.html`** for a visual guide.

---

## Project layout

```
.
├── GKG-Sync.cmd / GKG-Sync.command   ← double-click to open the menu (Win / Mac)
├── README.txt / START-HERE.html      ← start reading here
├── HUONG-DAN.html                    ← full user guide
├── config.example.ini                ← template; script copies it to config.ini
├── config.ini                        ← shared config (machine-specific, not committed)
├── scripts/
│   ├── win/   ← Windows engine (PowerShell)
│   └── mac/   ← macOS engine (bash)
├── shortcuts/                        ← optional extra launchers (legacy compatibility)
└── legacy/                           ← old SSH/Unison mode (advanced)
```

---

## Technical notes

Uses [Syncthing](https://syncthing.net/) over [Tailscale](https://tailscale.com/).  
Shared config: **`config.ini`** (see `[network]` for the hub/auto-sync setup). Build zip: `powershell ./scripts/win/tao-goi-cai.ps1` → outputs `GKG-Syncthing.zip` in the project root.
