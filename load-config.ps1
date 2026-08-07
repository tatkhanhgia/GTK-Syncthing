# Shared config.ini loader for Windows (legacy config.ps1 compatible)

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

function Get-LocalTailscaleIp {
    if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) {
        return $null
    }
    try {
        $ip = (& tailscale ip -4 2>$null | Select-Object -First 1)
        if ($ip) { return $ip.ToString().Trim() }
    } catch { }
    return $null
}

function Set-IniSectionValue {
    param(
        [string]$IniPath,
        [string]$Section,
        [string]$Key,
        [string]$Value
    )

    $lines = Get-Content -LiteralPath $IniPath -Encoding UTF8
    $out = New-Object System.Collections.Generic.List[string]
    $inSection = $false
    $foundKey = $false
    $seenSection = $false

    foreach ($line in $lines) {
        if ($line -match '^\[(.+)\]\s*$') {
            if ($inSection -and -not $foundKey) {
                $out.Add("${Key}=${Value}")
                $foundKey = $true
            }
            $inSection = ($Matches[1] -eq $Section)
            if ($inSection) { $seenSection = $true }
            $out.Add($line)
            continue
        }

        if ($inSection -and $line -match "^\s*$([regex]::Escape($Key))\s*=") {
            $out.Add("${Key}=${Value}")
            $foundKey = $true
            continue
        }

        $out.Add($line)
    }

    if ($inSection -and -not $foundKey) {
        $out.Add("${Key}=${Value}")
        $foundKey = $true
    }

    if (-not $seenSection) {
        $out.Add('')
        $out.Add("[$Section]")
        $out.Add("${Key}=${Value}")
    }

    $out | Set-Content -LiteralPath $IniPath -Encoding UTF8
}

function Test-IniPeerDeviceExists {
    param(
        [string]$IniPath,
        [string]$DeviceId
    )

    $ini = Read-IniFile -Path $IniPath
    foreach ($sectionName in ($ini.Keys | Sort-Object)) {
        if ($sectionName -match '^peer\.') {
            $peerId = $ini[$sectionName]['device_id']
            if ($peerId -and $peerId.Trim() -eq $DeviceId.Trim()) {
                return $true
            }
        }
    }
    return $false
}

function Get-NextPeerIndex {
    param([string]$IniPath)

    $ini = Read-IniFile -Path $IniPath
    $max = 0
    foreach ($sectionName in $ini.Keys) {
        if ($sectionName -match '^peer\.(\d+)$') {
            $n = [int]$Matches[1]
            if ($n -gt $max) { $max = $n }
        }
    }
    return ($max + 1)
}

function Update-LocalTailscaleIpInConfig {
    param([string]$IniPath)

    $ini = Read-IniFile -Path $IniPath
    $current = $ini['local']['tailscale_ip']
    if ($current -and $current.Trim() -and $current.Trim() -ne 'CHANGE-ME') {
        return
    }

    $ip = Get-LocalTailscaleIp
    if ($ip) {
        Set-IniSectionValue -IniPath $IniPath -Section 'local' -Key 'tailscale_ip' -Value $ip
    }
}

function Save-GkgConfigAfterInstall {
    param(
        [string]$IniPath,
        [string]$DeviceId,
        [string[]]$AddedPeerIds = @()
    )

    if (-not (Test-Path $IniPath)) { return }

    $machineName = $script:PackConfig.LocalMachineName
    if (-not $machineName) {
        $machineName = $env:COMPUTERNAME
    }

    Set-IniSectionValue -IniPath $IniPath -Section 'local' -Key 'machine_name' -Value $machineName

    $ip = Get-LocalTailscaleIp
    if ($ip) {
        Set-IniSectionValue -IniPath $IniPath -Section 'local' -Key 'tailscale_ip' -Value $ip
    }

    Set-IniSectionValue -IniPath $IniPath -Section 'local' -Key 'device_id' -Value $DeviceId

    foreach ($peerId in $AddedPeerIds) {
        if (-not $peerId) { continue }
        $peerId = $peerId.Trim()
        if (-not $peerId -or $peerId -eq $DeviceId) { continue }
        if (Test-IniPeerDeviceExists -IniPath $IniPath -DeviceId $peerId) { continue }

        $next = Get-NextPeerIndex -IniPath $IniPath
        Add-Content -LiteralPath $IniPath -Encoding UTF8 -Value @(
            '',
            "[peer.$next]",
            "name=Remote device $next",
            'tailscale_ip=CHANGE-ME',
            "device_id=$peerId"
        )
    }
}

function Clear-DuplicateLocalDeviceId {
    param([string]$IniPath)

    if (-not (Test-Path $IniPath)) { return }

    $ini = Read-IniFile -Path $IniPath
    $localId = $ini['local']['device_id']
    if (-not $localId) { return }
    $localId = $localId.Trim()
    if (-not $localId) { return }

    if (Test-IniPeerDeviceExists -IniPath $IniPath -DeviceId $localId) {
        Set-IniSectionValue -IniPath $IniPath -Section 'local' -Key 'device_id' -Value ''
    }
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
        'device_id='
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
    Write-Host 'Migrated config.ps1 -> config.ini (shared Windows + Mac)' -ForegroundColor Green
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
            Write-Host 'Created config.ini from config.example.ini' -ForegroundColor Yellow
            Write-Host ''
        } else {
            throw 'Could not find config.ini or config.example.ini'
        }
    }

    $script:ConfigIniPath = $iniPath

    Update-LocalTailscaleIpInConfig -IniPath $iniPath

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

    $selfId = $null
    if ($script:ConfigIniPath -and (Test-Path $script:ConfigIniPath)) {
        $ini = Read-IniFile -Path $script:ConfigIniPath
        if ($ini['local'] -and $ini['local']['device_id']) {
            $selfId = $ini['local']['device_id'].Trim()
        }
    }

    return @(
        $Peers |
            ForEach-Object { $_.SyncthingDeviceId.Trim() } |
            Where-Object {
                $_ -and (-not $selfId -or $_ -ne $selfId)
            }
    )
}

function Get-SyncRemoteUri {
    param($Config = $script:SyncConfig)
    $winPath = $Config.SyncFolder -replace '\\', '/'
    return "ssh://$($Config.RemoteUser)@$($Config.RemoteHost)//$winPath"
}
