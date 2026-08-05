# Doc config.ini chung cho Windows (va tuong thich config.ps1 cu)

function Read-IniFile {
    param([string]$Path)

    $sections = @{}
    $current = ''

    foreach ($rawLine in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $line = $rawLine.Trim()
        if (-not $line -or $line.StartsWith(';') -or $line.StartsWith('#')) {
            continue
        }
        if ($line -match '^\[(.+)\]\s*$') {
            $current = $Matches[1]
            if (-not $sections.ContainsKey($current)) {
                $sections[$current] = @{}
            }
            continue
        }
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            if (-not $sections.ContainsKey($current)) {
                $sections[$current] = @{}
            }
            $sections[$current][$key] = $value
        }
    }

    return $sections
}

function Expand-ConfigPath {
    param([string]$Path)

    if (-not $Path) {
        return $null
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if ($expanded -match '^~(/|\\|$)') {
        $expanded = $expanded -replace '^~', $env:USERPROFILE
    }
    return $expanded
}

function Export-LegacyConfigToIni {
    param(
        [string]$ScriptDir,
        [string]$IniPath
    )

    . (Join-Path $ScriptDir 'config.ps1')

    $lines = @(
        '; Auto-migrated from config.ps1'
        ''
        '[local]'
        "machine_name=$LocalMachineName"
        "tailscale_ip=$LocalMachineIp"
        "sync_folder=$($PackConfig.SyncFolder)"
        ''
        '[syncthing]'
        "folder_id=$($PackConfig.SyncthingFolderId)"
        "folder_label=$($PackConfig.SyncthingFolderLabel)"
        "port=$($PackConfig.SyncthingPort)"
    )

    $index = 1
    foreach ($peer in $Peers) {
        $lines += ''
        $lines += "[peer.$index]"
        $lines += "name=$($peer.Name)"
        $lines += "tailscale_ip=$($peer.TailscaleIp)"
        $lines += "device_id=$($peer.SyncthingDeviceId)"
        $index++
    }

    $lines | Set-Content -LiteralPath $IniPath -Encoding UTF8
    Write-Host 'Da chuyen config.ps1 -> config.ini (dung chung Windows + Mac)' -ForegroundColor Green
    Write-Host ''
}

function Import-GkgConfig {
    param([string]$ScriptDir)

    $iniPath = Join-Path $ScriptDir 'config.ini'
    $legacyPath = Join-Path $ScriptDir 'config.ps1'
    $examplePath = Join-Path $ScriptDir 'config.example.ini'

    if (-not (Test-Path $iniPath)) {
        if (Test-Path $legacyPath) {
            Export-LegacyConfigToIni -ScriptDir $ScriptDir -IniPath $iniPath
        } elseif (Test-Path $examplePath) {
            Copy-Item $examplePath $iniPath
            Write-Host 'Da tao config.ini tu config.example.ini' -ForegroundColor Yellow
            Write-Host ''
        } else {
            throw 'Khong tim thay config.ini hoac config.example.ini'
        }
    }

    $ini = Read-IniFile -Path $iniPath
    $local = $ini['local']
    $syncthing = $ini['syncthing']

    if (-not $local) { $local = @{} }
    if (-not $syncthing) { $syncthing = @{} }

    $syncFolder = Expand-ConfigPath $local['sync_folder']
    if (-not $syncFolder) {
        $syncFolder = Join-Path $env:USERPROFILE 'Documents\Sync'
    }

    $machineName = $local['machine_name']
    if (-not $machineName) {
        $machineName = $env:COMPUTERNAME
    }

    $tailscaleIp = $local['tailscale_ip']
    if (-not $tailscaleIp) {
        $tailscaleIp = 'CHANGE-ME'
    }

    $port = 8384
    if ($syncthing['port']) {
        [void][int]::TryParse($syncthing['port'], [ref]$port)
    }

    $script:PackConfig = @{
        SyncFolder           = $syncFolder
        LocalMachineIp       = $tailscaleIp
        LocalMachineName     = $machineName
        SyncthingFolderId    = if ($syncthing['folder_id']) { $syncthing['folder_id'] } else { 'documents-sync' }
        SyncthingFolderLabel = if ($syncthing['folder_label']) { $syncthing['folder_label'] } else { 'Documents Sync' }
        SyncthingPort        = $port
        InstallDir           = "$env:LOCALAPPDATA\GKG-Syncthing"
    }

    $script:Peers = @()
    foreach ($sectionName in ($ini.Keys | Sort-Object)) {
        if ($sectionName -match '^peer\.(.+)$') {
            $peer = $ini[$sectionName]
            $script:Peers += @{
                Name              = if ($peer['name']) { $peer['name'] } else { "Peer $($Matches[1])" }
                TailscaleIp       = if ($peer['tailscale_ip']) { $peer['tailscale_ip'] } else { 'CHANGE-ME' }
                SyncthingDeviceId = if ($peer['device_id']) { $peer['device_id'] } else { '' }
            }
        }
    }

    $script:SyncConfig = @{
        RemoteHost    = if ($script:Peers.Count -gt 0) { $script:Peers[0].TailscaleIp } else { 'CHANGE-ME' }
        RemoteUser    = 'admin'
        LocalMachine  = $tailscaleIp
        SyncFolder    = $syncFolder
        WslSyncPath   = ConvertTo-WslPath $syncFolder
        UnisonProfile = 'sync'
    }
}

function ConvertTo-WslPath {
    param([string]$WindowsPath)
    $normalized = $WindowsPath -replace '\\', '/'
    if ($normalized -match '^([A-Za-z]):(.*)$') {
        $drive = $Matches[1].ToLower()
        $rest = $Matches[2]
        return "/mnt/$drive$rest"
    }
    return $normalized
}

function Get-SyncthingConfigPath {
    return Join-Path $env:LOCALAPPDATA 'Syncthing\config.xml'
}

function Get-SyncthingGuiUrl {
    return "http://127.0.0.1:$($script:PackConfig.SyncthingPort)"
}

function Get-PeerList {
    param($Peers = $script:Peers)
    return $Peers
}

function Get-PeerDeviceIds {
    param($Peers = $script:Peers)
    return @($Peers | ForEach-Object { $_.SyncthingDeviceId.Trim() } | Where-Object { $_ })
}

function Get-SyncRemoteUri {
    param($Config = $script:SyncConfig)
    $winPath = $Config.SyncFolder -replace '\\', '/'
    return "ssh://$($Config.RemoteUser)@$($Config.RemoteHost)//$winPath"
}
