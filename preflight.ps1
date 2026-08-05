# Kiem tra truoc khi cai (Windows)

function Test-TailscaleReady {
    if (Get-Command tailscale -ErrorAction SilentlyContinue) {
        $status = & tailscale status 2>&1
        if ($LASTEXITCODE -eq 0 -and $status) {
            return $true
        }
    }
    return $false
}

function Ensure-Tailscale {
    if (Test-TailscaleReady) {
        Write-Host 'Tailscale: OK' -ForegroundColor Green
        return
    }

    Write-Host ''
    Write-Host 'Chua thay Tailscale dang chay.' -ForegroundColor Yellow
    Write-Host 'Ban can cai Tailscale va dang nhap CUNG tai khoan tren moi may.'
    Write-Host ''
    Write-Host 'Dang mo trang tai Tailscale...' -ForegroundColor Cyan
    Start-Process 'https://tailscale.com/download/windows' | Out-Null
    Write-Host ''
    Write-Host 'Sau khi cai xong Tailscale, nhan Enter de tiep tuc...' -ForegroundColor Yellow
    Read-Host | Out-Null

    if (-not (Test-TailscaleReady)) {
        Write-Warn 'Van chua thay Tailscale. Tiep tuc cai dat Syncthing — co the ket noi sau.'
    }
}

function Copy-DeviceIdToClipboard {
    param([string]$DeviceId)
    if (-not $DeviceId) { return }

    try {
        Set-Clipboard -Value $DeviceId
        Write-Ok 'Da copy Device ID vao clipboard (Ctrl+V de dan).'
    } catch {
        Write-Warn 'Khong copy duoc tu dong — hay copy bang tay tu man hinh ket qua.'
    }
}

function Show-DeviceIdDialog {
    param(
        [string]$DeviceId,
        [string]$HtmlPath
    )

    Copy-DeviceIdToClipboard -DeviceId $DeviceId

    if ($HtmlPath -and (Test-Path $HtmlPath)) {
        Start-Process $HtmlPath | Out-Null
        return
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            "DEVICE ID MAY NAY (da copy vao clipboard):`n`n$DeviceId`n`nGui dong nay cho nguoi dung may KIA, roi chay Cai-Dat-Sync tren may do.",
            'GKG Sync - Cai dat xong',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } catch {
        Write-Host 'DEVICE ID MAY NAY:' -ForegroundColor Yellow
        Write-Host $DeviceId -ForegroundColor White
    }
}

function Invoke-SetupWizard {
    param([string[]]$ExistingIds = @())

    Write-Host ''
    Write-Host '--- Buoc 1: Loai may ---' -ForegroundColor Cyan
    Write-Host '  1 = May MOI   (may nay moi them vao, chua ai sync voi may nay)'
    Write-Host '  2 = May CU    (da co may khac dung sync, dang noi may nay vao)'
    Write-Host ''
    $role = Read-Host 'Ban chon 1 hay 2'

    $ids = [System.Collections.ArrayList]@($ExistingIds)

    if ($role -eq '2') {
        Write-Host ''
        Write-Host '--- Buoc 2: Device ID may MOI ---' -ForegroundColor Cyan
        Write-Host 'Nguoi dung may MOI se gui cho ban mot dai ky tu (Device ID).'
        Write-Host 'Dan vao day (Enter neu chua co):'
        $newId = Read-Host 'Device ID may moi'
        if ($newId -and $newId.Trim()) {
            [void]$ids.Add($newId.Trim())
        }
    } else {
        Write-Host ''
        Write-Host '--- Buoc 2: Device ID may CU (neu co) ---' -ForegroundColor Cyan
        Write-Host 'Neu may cu da gui Device ID — dan vao. Khong co thi Enter bo qua.'
        while ($true) {
            $line = Read-Host 'Device ID may cu (Enter = xong)'
            if (-not $line) { break }
            $trimmed = $line.Trim()
            if ($ids -contains $trimmed) {
                Write-Warn 'Da co roi, bo qua.'
                continue
            }
            [void]$ids.Add($trimmed)
        }
    }

    return @($ids | Select-Object -Unique)
}

function Write-InstallResultHtml {
    param(
        [string]$ScriptDir,
        [string]$DeviceId,
        [string]$SyncFolder,
        [string]$GuiUrl
    )

    $outPath = Join-Path $ScriptDir 'KET-QUA-CAI-DAT.html'
    $safeId = [System.Net.WebUtility]::HtmlEncode($DeviceId)
    $safeFolder = [System.Net.WebUtility]::HtmlEncode($SyncFolder)
    $safeUrl = [System.Net.WebUtility]::HtmlEncode($GuiUrl)

    @"
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
  <p>Thu muc dong bo: <b>$safeFolder</b></p>
  <p><b>DEVICE ID MAY NAY</b> — gui cho nguoi dung may KIA:</p>
  <div class="id" id="did">$safeId</div>
  <button type="button" onclick="copyId()">Copy Device ID</button>
  <button type="button" class="secondary" onclick="location.href='$safeUrl'">Mo trang quan ly Syncthing</button>
  <div class="step"><b>Tiep theo:</b> Tren may KIA, chay <b>Cai-Dat-Sync</b> (Windows) hoac <b>Cai-Dat-Cho-Mac</b> (Mac), dan Device ID o tren, Enter.</div>
  <div class="step">Sau do tha file vao thu muc Sync — cac may tu dong dong bo.</div>
</div>
<script>
function copyId(){
  var t=document.getElementById('did').innerText;
  navigator.clipboard.writeText(t).then(function(){
    alert('Da copy Device ID! Dan (Ctrl+V / Cmd+V) gui cho may kia.');
  }).catch(function(){
    prompt('Copy bang tay:', t);
  });
}
copyId();
</script>
</body>
</html>
"@ | Set-Content -LiteralPath $outPath -Encoding UTF8

    return $outPath
}
