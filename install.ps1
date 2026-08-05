# GKG-Syncthing - one-click installer (Syncthing)

param(
    [ValidateSet('Syncthing', 'Ssh', 'Menu')]
    [string]$Mode = 'Syncthing',
    [string[]]$RemoteDeviceIds = @(),
    [switch]$SkipPrompt
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir 'load-config.ps1')
Import-GkgConfig -ScriptDir $ScriptDir
. (Join-Path $ScriptDir 'syncthing-setup.ps1')
. (Join-Path $ScriptDir 'preflight.ps1')

function Show-Banner {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Green
    Write-Host '   DONG BO FILE - TU DONG CAI DAT' -ForegroundColor Green
    Write-Host '========================================' -ForegroundColor Green
    Write-Host ''
    Write-Host 'Chi can lam theo huong dan tung buoc.' -ForegroundColor DarkGray
    Write-Host ''
}

function Show-SyncthingResult {
    param($Result)

    $htmlPath = Write-InstallResultHtml `
        -ScriptDir $ScriptDir `
        -DeviceId $Result.DeviceId `
        -SyncFolder $Result.SyncFolder `
        -GuiUrl $Result.GuiUrl

    Write-Host ''
    Write-Host '========================================' -ForegroundColor Green
    Write-Host '   CAI DAT XONG!' -ForegroundColor Green
    Write-Host '========================================' -ForegroundColor Green
    Write-Host ''
    Write-Ok "Thu muc sync: $($Result.SyncFolder)"
    Write-Host ''
    Write-Host 'Trang ket qua dang mo — bam Copy Device ID va gui cho may KIA.' -ForegroundColor Cyan
    Write-Host ''

    Show-DeviceIdDialog -DeviceId $Result.DeviceId -HtmlPath $htmlPath

    try {
        Start-Process $Result.GuiUrl | Out-Null
    } catch {
        Write-Warn "Mo trinh duyet thu cong: $($Result.GuiUrl)"
    }
}

function Install-SshMode {
    $legacyDir = Join-Path $ScriptDir 'legacy'
    Write-Info 'Che do nang cao: SSH + Unison (legacy)'
    $installUnison = Join-Path $legacyDir 'install-unison.cmd'
    $setupSync = Join-Path $legacyDir 'setup-sync.cmd'

    if (-not (Test-Path $installUnison)) {
        throw "Khong tim thay: $installUnison"
    }

    Write-Host ''
    Write-Warn 'Che do nay can WSL + Unison. Chi ho tro 2 may.'
    Write-Host ''

    cmd /c "`"$installUnison`""
    cmd /c "`"$setupSync`""

    Write-Host ''
    Write-Ok 'SSH sync da setup. Chay sync bang: legacy\sync-folder.cmd'
    Write-Host ''
}

Show-Banner
Ensure-Tailscale

if ($Mode -eq 'Menu') {
    Write-Host 'Chon che do cai dat:' -ForegroundColor Cyan
    Write-Host '  [1] Syncthing - mac dinh (tu dong sync nhieu may)'
    Write-Host '  [2] SSH/Unison - nang cao (legacy, chi 2 may)'
    Write-Host ''
    $choice = Read-Host 'Nhap 1 hoac 2 (mac dinh: 1)'
    if (-not $choice -or $choice -eq '1') {
        $Mode = 'Syncthing'
    } else {
        $Mode = 'Ssh'
    }
}

if ($Mode -eq 'Syncthing') {
    if ($RemoteDeviceIds.Count -eq 0) {
        if ($SkipPrompt) {
            $RemoteDeviceIds = @(Get-PeerDeviceIds)
        } else {
            $RemoteDeviceIds = Invoke-SetupWizard -ExistingIds @(Get-PeerDeviceIds)
        }
    }

    Write-Host ''
    Write-Info 'Dang cai dat... (cho vai phut)'
    $result = Install-SyncthingMode -Config $PackConfig -RemoteDeviceIds $RemoteDeviceIds
    Show-SyncthingResult -Result $result
    exit 0
}

if ($Mode -eq 'Ssh') {
    Install-SshMode
    exit 0
}

throw "Che do khong hop le: $Mode"
