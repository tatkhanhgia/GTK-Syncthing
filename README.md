# GKG-Syncthing

Dong bo file tu dong giua nhieu may Windows qua **Syncthing** + **Tailscale**.

## Nguoi dung (khong can doc code)

1. Giai nen (hoac clone) project vao mot thu muc, vi du `C:\Users\Admin\Documents\GKG-Syncthing`
2. Double-click **`Cai-Dat-Sync.cmd`**
3. Lam theo huong dan tren man hinh

Chi tiet: chay **`Huong-Dan.cmd`** hoac doc **`README.txt`**.

| File | Muc dich |
|------|----------|
| `Cai-Dat-Sync.cmd` | Cai lan dau / them may moi |
| `Huong-Dan.cmd` | Mo huong dan HTML |
| `Khoi-Dong-Sync.cmd` | Bat lai Syncthing neu bi tat |

Thu muc dong bo mac dinh: `%USERPROFILE%\Documents\Sync`

## Yeu cau

- Windows 10/11
- [Tailscale](https://tailscale.com) — cung tai khoan tren tat ca cac may
- Ket noi mang (Syncthing tu cai qua winget hoac portable)

## Cau hinh (tuy chon)

Lan dau chay, script tu tao `config.ps1` tu `config.example.ps1`.

Chinh `config.ps1` de luu san Device ID cac may (`$Peers`) — khong bat buoc, co the dan Device ID luc cai dat.

## Maintainer

```powershell
# Tao zip phan phoi
.\tao-goi-cai.ps1
# -> %USERPROFILE%\Documents\Sync\GKG-Syncthing.zip
```

Che do SSH/Unison (legacy, chi 2 may) nam trong `legacy/` — khong dung cho nguoi dung thong thuong.

## Lien quan

Project docs API (`api-document-specification`) nam cung cap thu muc — dung sync pack nay de copy file formatted doc qua cac may, khong phu thuoc vao nhau ve code.
