# PLAN — Tự động sync các device trong một Tailscale (Syncthing introducer)

> Phiên bản đã "ổn định consensus" giữa main-agent và agent đối tác (reviewer).
> Thay đổi then máu so với bản draft: hướng cờ introducer, thuật merge folder không ghi đè, hook membership chỉ tại hub, bỏ phần confirm không chính xác.

Mục đích: bỏ thao tác "dán Device ID lẫn nhau vào config.ini". Một máy đóng vai **hub (introducer)**; máy mới chỉ kết nối hub **một lần**; Syncthing tự chia sẻ device qua nhau + folder membership tự đồng bộ.

Hai nền song hành: **Windows (PowerShell)** + **macOS (bash)**, dùng chung `config.ini`.

---

## Cơ chế (đã làm rõ — quan trọng)

1. **Hướng cờ introducer**:
   - **Máy con** (is_hub=false) đặt `introducer: true` cho **hub** ⇒ "tin hub, cho hub giới thiệu máy khác về tôi".
   - **Hub** (is_hub=true) đặt `introducer: false` cho các máy con (hub không tự giới thiệu ai về chúng trừ khi cần).
2. **Device: tự động, không confirm dialog.** Khi có liên kết introducer, Syncthing tự thêm + tự kết nối device được giới thiệu (không popup).
3. **Folder: KHÔNG tự chia.** Syncthing chỉ chia **quan hệ device**; thiết bị phải nằm trong folder `devices[]` mới sync file ⇒ **Phase 2 là bắt buộc**, không ai tùy chọn.
4. Cờ `introducer` là đặc tính **bên nhận** nói lên nó tin ai giới thiệu; **không đặt ngược chiều.**

## REST API đang dùng
- `GET`/`POST /rest/config/devices` (POST body {deviceID,name,addresses:[dynamic],introducer,...,paused:false})
- `GET`/`PUT /rest/config/folders` , `GET /rest/config/folders/{id}`
- `GET /rest/system/status` (myID)
- **Port**: lấy từ `config.ini` `[syncthing] port`. **Bỏ hardcode 838**.

---

## Cấu hình `config.ini` (mở rộng)

Thêm section (có sẵn trong `config.example.ini` từ đầu):

```
[network]
is_hub=false
introducer_device_id=
auto_share=true
```

Quy ước / validation:
- `is_hub=true`: máy hub, không cần `introducer_device_id`.
- `is_hub=false` + `introducer_device_id=<id hub>`.
- `introducer_device_id` phải khác `myID` local.
- Chống 2 hub (nếu `is_hub=true` mà lại có `introducer_device_id` → cảnh báo).
- `folder_id` + `type` (sendreceive) nên giống nhau giữa các máy — validate + cảnh báo khi lệch.

---

## Phase 1 — Join network bằng introducer

**Mục tiêu:** máy mới chỉ nhập **1** Device ID hub; tự thêm hub (introducer=true) + tự chia folder với hub.

Windows (`*.ps1`):
- `load-config.ps1`: đọc `[network]` → `$script:PackConfig.IntroducerDeviceId/IsHub/AutoShare`.
- `syncthing-setup.ps1`:
  - `Add-SyncthingRemoteDevice` thêm `-Introducer` (default $false); POST device kèm `introducer=$true`.
  - `Install-SyncthingMode` thêm `-IntroducerDeviceId`.
- `preflight.ps1` `Invoke-SetupWizard`: thêm option "Join Hub network (chỉ cần Hub Device ID)".
- `install.ps1`: điều hướng nhánh join theo `[network]`.
- `menu.ps1`: thêm mục "6. Join network".

macOS (`scripts/mac/*.sh` — khớp 1-1):
- `load-config.sh`: biến `NET_IS_HUB`/`NET_INTRODUCER_ID`/`NET_AUTO_SHARE`.
- `syncthing-setup.sh`: `add_syncthing_remote_device` thêm arg `--introducer`; `install_syncthing_mode` nhận introducer id.
- `preflight.sh`, `install.sh`, `menu.sh` (`mac_choose` chuỗi AppleScript cứng phải sửa cả list + dispatch).

---

## Phase 2 — Tự đồng bộ folder membership (core, bắt buộc)

### Thuật toán `Sync-FolderMembership` / `sync_folder_membership(apiKey)` — KHÔNG ghi đè:
1. `GET /rest/config/folders/{id}` → object folder **hiện tại** đang runtime.
2. Lấy `devices[]` hiện có; `GET /rest/config/devices` lấy danh sách device đã biết.
3. Merge **add-only**: chỉ chèn device còn thiếu vào `devices[]` của folder, **loại myID self**; **GIỮ NGUYÊN** các field khác (versioning, ignorePatterns, rescanIntervalS, fsWatcherDelayS, type...).
4. `PUT /rest/config/folders/{id}` với chính object đó. **Retry khi 409/500** (config in-flight): backtối giản 3 lần.
5. Không dùng lại `Ensure-SyncthingFolder`/`build_folder_json` (chúng tự dựng template → reset config).

**Hook chạy (chống race — cải thiện từ review):**
- **Chỉ hub chạy membership-sync** khi thấy máy mới kết nối (1 lần/restart + 1 lần ngay sau khi máy con join gọi).
- **Máy con chỉ PULL**: ở cuối `install_syncthing_mode` nó chỉ chia folder với hub, không tự PUT đè. Khi hub sync thiết đã biết máy con nằm trong folder ⇒ file sẽ sync.
- `khoi-dong-sync` (2 đnều) **hiện KHÔNG có apiKey/REST** — phải đoạn `wait_syncthing_config` + `get_syncthing_api_key` để gọi membership (chỉ tại hub; ở máy con thì PULL không PUT).

---

## Lộ trình deliver (Windows + Mac song song)

- **A.** Update `config.example.ini` (thêm `[network]`) + `PLAN-AUTO-SYNC.md` (file này) — đã xong/handler chung.
- **B. (song song)** Windows agent && macOS agent, mỗi bên làm **Phase 1 + Phase 2 core** trên nền của mình.
- **C.** Contract/interface thống nhất giữa 2 nền (bảng hàm, payload, tên biến) — liệt kê dưới đây.
- **D.** Validate: `pwsh -NoProfile -Command "parse"` cho ps1; `shellcheck` cho sh; sửa menu + hướng dẫn HTML.
- **E (stretch):** daemon định kỳ 60s (Task Scheduler / launchd) — nếu cần "tự động đúng nghĩa". **Bỏ hẳn** watcher `/rest/system/connections` poll liên tục (friction; khuyến nghị reviewer).

---

## Bảng interface chung (bắt buộc nhất quán 2 nền)

| Khái niệm | config.ini | Windows (pl?/function) | macOS (bash) |
|-----------|-----------|------------------------|--------------|
| intro id  | `[network] introducer_device_id` | `$PackConfig.IntroducerDeviceId` | `NET_INTRODUCER_ID` |
| hub flag  | `is_hub` | `$PackConfig.IsHub` | `NET_IS_HUB` |
| auto share| `auto_share` | `$PackConfig.AutoShare` | `NET_AUTO_SHARE` |
| add device| — | `Add-SyncthingRemoteDevice -DeviceId -Name -Introducer` | `add_syncthing_remote_device` + `--introducer` |
| membership| — | `Sync-FolderMembership(apiKey)` | `sync_folder_membership "$api_key"` |
| folder    |   | `Get/Update-SyncthingFolder` (không template) | `get/update_syncthing_folder` |
| port      | `[syncthing] port` | `$PackConfig.SyncthingPort` | `$SYNCTHING_PORT` |

**REST contract cứng:** dùng tên field chuẩn `deviceID` (chữ I hoa — PowerShell giữ hoa), `devices[]`, `/rest/config/folders/{id}`.