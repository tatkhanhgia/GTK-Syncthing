#!/usr/bin/env bash
# Kiem tra truoc khi cai (macOS)

test_tailscale_ready() {
    command -v tailscale >/dev/null 2>&1 || return 1
    tailscale status >/dev/null 2>&1
}

ensure_tailscale() {
    if test_tailscale_ready; then
        write_ok 'Tailscale: OK'
        return
    fi

    echo ''
    write_warn 'Chua thay Tailscale dang chay.'
    echo 'Ban can cai Tailscale va dang nhap CUNG tai khoan tren moi may.'
    echo ''
    write_info 'Dang mo trang tai Tailscale...'
    open 'https://tailscale.com/download/macos' 2>/dev/null || true
    echo ''
    echo 'Sau khi cai xong Tailscale, nhan Enter de tiep tuc...'
    read -r _
}

copy_device_id_to_clipboard() {
    local device_id="$1"
    [[ -z "$device_id" ]] && return
    if printf '%s' "$device_id" | pbcopy 2>/dev/null; then
        write_ok 'Da copy Device ID vao clipboard (Cmd+V de dan).'
    fi
}

mac_ask() {
    local title="$1"
    local prompt="$2"
    local default="${3:-}"
    osascript -e "display dialog \"$prompt\" with title \"$title\" default answer \"$default\" buttons {\"Huy\", \"OK\"} default button \"OK\"" -e 'text returned of result' 2>/dev/null || true
}

mac_alert() {
    local title="$1"
    local message="$2"
    osascript -e "display dialog \"$message\" with title \"$title\" buttons {\"OK\"} default button \"OK\"" 2>/dev/null || true
}

invoke_setup_wizard() {
    local -a ids=("$@")
    local role line trimmed dup choice new_id

    echo ''
    echo '--- Buoc 1: Loai may ---'
    choice="$(mac_ask 'GKG Sync' 'Ban la may MOI (1) hay may CU (2)?\n\n1 = May moi them vao\n2 = May cu da co sync' '1')"
    choice="$(echo "$choice" | xargs)"

    if [[ "$choice" == "2" ]]; then
        role=2
    else
        role=1
    fi

    if [[ "$role" -eq 2 ]]; then
        echo ''
        echo '--- Buoc 2: Device ID may MOI ---'
        new_id="$(mac_ask 'GKG Sync' 'Dan Device ID ma may MOI gui cho ban:\n(Khong co thi de trong va bam OK)' '')"
        new_id="$(echo "$new_id" | xargs)"
        if [[ -n "$new_id" ]]; then
            ids+=("$new_id")
        fi
    else
        echo ''
        echo '--- Buoc 2: Device ID may CU (neu co) ---'
        while true; do
            line="$(mac_ask 'GKG Sync' 'Dan Device ID may CU (Enter/OK trong neu khong co):\nBam Huy khi xong.' '')"
            line="$(echo "$line" | xargs)"
            [[ -z "$line" ]] && break
            dup=0
            for trimmed in "${ids[@]}"; do
                if [[ "$trimmed" == "$line" ]]; then
                    dup=1
                    break
                fi
            done
            if [[ $dup -eq 1 ]]; then
                write_warn 'Da co roi, bo qua.'
                continue
            fi
            ids+=("$line")
        done
    fi

    printf '%s\n' "${ids[@]}"
}

write_install_result_html() {
    local root="$1"
    local device_id="$2"
    local sync_folder="$3"
    local gui_url="$4"
    local out_path="$root/KET-QUA-CAI-DAT.html"

    cat > "$out_path" <<HTMLEOF
<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Cai dat xong - GKG Sync</title>
<style>
  body{font-family:system-ui,sans-serif;max-width:640px;margin:40px auto;padding:0 20px;background:#f0fdf4;color:#0f172a}
  .card{background:#fff;border:2px solid #16a34a;border-radius:16px;padding:28px;box-shadow:0 4px 20px rgba(0,0,0,.08)}
  h1{color:#16a34a;margin:0 0 8px;font-size:26px}
  .id{font-family:Consolas,monospace;font-size:15px;background:#f1f5f9;padding:16px;border-radius:10px;word-break:break-all;margin:16px 0}
  button{background:#2563eb;color:#fff;border:none;padding:14px 24px;font-size:16px;border-radius:10px;cursor:pointer;width:100%;margin:8px 0}
  button.secondary{background:#64748b}
  p{line-height:1.6}
  .step{background:#eff6ff;border-left:4px solid #2563eb;padding:12px 16px;margin:12px 0;border-radius:0 8px 8px 0}
</style>
</head>
<body>
<div class="card">
  <h1>Cai dat xong!</h1>
  <p>Thu muc dong bo: <b>${sync_folder}</b></p>
  <p><b>DEVICE ID MAY NAY</b> — gui cho nguoi dung may KIA:</p>
  <div class="id" id="did">${device_id}</div>
  <button type="button" onclick="copyId()">Copy Device ID</button>
  <button type="button" class="secondary" onclick="location.href='${gui_url}'">Mo trang quan ly Syncthing</button>
  <div class="step"><b>Tiep theo:</b> Tren may KIA, chay <b>Cai-Dat-Sync</b> (Windows) hoac <b>Cai-Dat-Cho-Mac</b> (Mac), dan Device ID o tren.</div>
  <div class="step">Sau do tha file vao thu muc Sync — cac may tu dong dong bo.</div>
</div>
<script>
function copyId(){
  var t=document.getElementById('did').innerText;
  navigator.clipboard.writeText(t).then(function(){
    alert('Da copy Device ID! Dan Cmd+V gui cho may kia.');
  }).catch(function(){
    prompt('Copy bang tay:', t);
  });
}
copyId();
</script>
</body>
</html>
HTMLEOF
    echo "$out_path"
}

show_device_id_result() {
    local device_id="$1"
    local html_path="$2"

    copy_device_id_to_clipboard "$device_id"

    if [[ -f "$html_path" ]]; then
        open "$html_path" 2>/dev/null || true
    fi

    mac_alert 'GKG Sync - Cai dat xong' "DEVICE ID MAY NAY (da copy):\n\n${device_id}\n\nGui cho nguoi dung may KIA."
}
