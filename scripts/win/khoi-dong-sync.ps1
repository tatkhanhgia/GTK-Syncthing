# Start Syncthing and open the Sync folder (no reinstall)
$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir 'load-config.ps1')
try {
    Import-GkgConfig -ScriptDir $ScriptDir
} catch {
    Write-Host ''
    Write-Host '[ERROR] No config.ini found. Run Cai-Dat-Sync.cmd first.' -ForegroundColor Red
    Write-Host ''
    exit 1
}
. (Join-Path $ScriptDir 'syncthing-setup.ps1')

if (-not (Test-SyncthingInstalled -Config $PackConfig)) {
    Write-Host ''
    Write-Host '[ERROR] Syncthing is not installed.' -ForegroundColor Red
    Write-Host 'Run Cai-Dat-Sync.cmd first.' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

Write-Host ''
Write-Host 'Starting Syncthing...' -ForegroundColor Cyan
Start-SyncthingProcess -Config $PackConfig
Start-Sleep -Seconds 2

if ($PackConfig.IsHub) {
    Write-Host 'Hub detected — syncing folder membership...' -ForegroundColor Cyan
    try {
        $configPath = Wait-SyncthingConfig
        $apiKey = Get-SyncthingApiKey -ConfigPath $configPath
        $myId = Get-LocalSyncthingDeviceId -ApiKey $apiKey
        Sync-FolderMembership -ApiKey $apiKey -FolderId $PackConfig.SyncthingFolderId -SelfDeviceId $myId
    } catch {
        Write-Host ('[Warning] Membership sync: ' + $_.Exception.Message) -ForegroundColor Yellow
    }
}

Write-Host 'Opening Sync folder...' -ForegroundColor Green
try {
    Start-Process $PackConfig.SyncFolder | Out-Null
} catch {
    Write-Host "Open folder manually: $($PackConfig.SyncFolder)" -ForegroundColor Yellow
}

$url = Get-SyncthingGuiUrl
Write-Host "Syncthing management page: $url" -ForegroundColor Green
try {
    Start-Process $url | Out-Null
} catch {
    Write-Host 'Open your browser manually if needed.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Done. Files in the Sync folder will sync automatically.' -ForegroundColor Green
Write-Host ''
