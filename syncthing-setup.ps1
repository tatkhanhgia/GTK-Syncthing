# Syncthing setup helpers for GKG-Syncthing

function Write-Info([string]$Message) {
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host $Message -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Err([string]$Message) {
    Write-Host $Message -ForegroundColor Red
}

function Ensure-SyncFolder {
    param($Config)
    New-Item -ItemType Directory -Force -Path $Config.SyncFolder | Out-Null
}

function Test-SyncthingInstalled {
    param($Config)
    if (Get-Command syncthing -ErrorAction SilentlyContinue) {
        return $true
    }
    $portable = Join-Path $Config.InstallDir 'syncthing\syncthing.exe'
    return Test-Path $portable
}

function Get-SyncthingExe {
    param($Config)

    if (Get-Command syncthing -ErrorAction SilentlyContinue) {
        return (Get-Command syncthing).Source
    }

    $commonPaths = @(
        (Join-Path $Config.InstallDir 'syncthing\syncthing.exe'),
        "$env:ProgramFiles\Syncthing\syncthing.exe",
        "$env:LocalAppData\Programs\Syncthing\syncthing.exe"
    )
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

function Install-SyncthingPackage {
    param($Config)

    Write-Info 'Installing Syncthing...'

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host 'Trying winget install...'
        cmd /c "winget install --id Syncthing.Syncthing -e --accept-source-agreements --accept-package-agreements --silent" | Out-Null
        Start-Sleep -Seconds 3
        if (Get-Command syncthing -ErrorAction SilentlyContinue) {
            Write-Ok 'Syncthing installed via winget.'
            return
        }
    }

    $installRoot = Join-Path $Config.InstallDir 'syncthing'
    $exePath = Join-Path $installRoot 'syncthing.exe'
    if (Test-Path $exePath) {
        Write-Ok 'Syncthing portable is already present.'
        return
    }

    Write-Host 'Downloading Syncthing portable...'
    New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
    $zipPath = Join-Path $env:TEMP 'syncthing-windows.zip'
    $url = 'https://github.com/syncthing/syncthing/releases/download/v1.29.3/syncthing-windows-amd64-v1.29.3.zip'

    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $installRoot -Force

    $extracted = Get-ChildItem -Path $installRoot -Recurse -Filter 'syncthing.exe' | Select-Object -First 1
    if (-not $extracted) {
        throw 'Could not find syncthing.exe after extracting.'
    }

    Copy-Item $extracted.FullName $exePath -Force
    Write-Ok 'Syncthing portable downloaded.'
}

function Start-SyncthingProcess {
    param($Config)

    $exe = Get-SyncthingExe -Config $Config
    if (-not $exe) {
        throw 'Syncthing is not installed.'
    }

    $running = Get-Process syncthing -ErrorAction SilentlyContinue
    if ($running) {
        Write-Ok 'Syncthing is already running.'
        return
    }

    Write-Info 'Starting Syncthing...'
    Start-Process -FilePath $exe -WindowStyle Hidden
    Start-Sleep -Seconds 4
}

function Wait-SyncthingConfig {
    param([int]$TimeoutSec = 60)

    $configPath = Get-SyncthingConfigPath
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $configPath) {
            return $configPath
        }
        Start-Sleep -Seconds 2
    }
    throw 'Could not find Syncthing config file.'
}

function Get-SyncthingApiKey {
    param([string]$ConfigPath)

    [xml]$xml = Get-Content $ConfigPath
    return $xml.configuration.gui.apikey
}

function Invoke-SyncthingApi {
    param(
        [string]$ApiKey,
        [string]$Method,
        [string]$Path,
        [object]$Body = $null
    )

    $port = 8384
    if ($script:PackConfig -and $script:PackConfig.SyncthingPort) {
        $port = $script:PackConfig.SyncthingPort
    }
    $uri = "http://127.0.0.1:$port$Path"
    $params = @{
        Uri         = $uri
        Method      = $Method
        Headers     = @{ 'X-API-Key' = $ApiKey }
        ContentType = 'application/json'
    }
    if ($null -ne $Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10)
    }
    return Invoke-RestMethod @params
}

function Ensure-SyncthingFolder {
    param(
        $Config,
        [string]$ApiKey,
        [string[]]$DeviceIds = @()
    )

    $folders = Invoke-SyncthingApi -ApiKey $ApiKey -Method GET -Path '/rest/config/folders'
    $existing = $folders | Where-Object { $_.id -eq $Config.SyncthingFolderId }

    $deviceEntries = @()
    foreach ($id in $DeviceIds) {
        if ($id) {
            $deviceEntries += @{ deviceID = $id.Trim() }
        }
    }

    $folder = @{
        id                 = $Config.SyncthingFolderId
        label              = $Config.SyncthingFolderLabel
        path               = $Config.SyncFolder
        type               = 'sendreceive'
        devices            = $deviceEntries
        rescanIntervalS    = 3600
        fsWatcherEnabled   = $true
        fsWatcherDelayS    = 10
        versioning         = @{ type = '' }
        ignorePatterns     = @()
    }

    if ($existing) {
        Invoke-SyncthingApi -ApiKey $ApiKey -Method PUT -Path "/rest/config/folders/$($Config.SyncthingFolderId)" -Body $folder | Out-Null
    } else {
        Invoke-SyncthingApi -ApiKey $ApiKey -Method POST -Path '/rest/config/folders' -Body $folder | Out-Null
    }
}

function Add-SyncthingRemoteDevice {
    param(
        [string]$ApiKey,
        [string]$DeviceId,
        [string]$Name = 'Remote device',
        [switch]$Introducer
    )

    if (-not $DeviceId) {
        return
    }

    $deviceId = $DeviceId.Trim()
    $devices = Invoke-SyncthingApi -ApiKey $ApiKey -Method GET -Path '/rest/config/devices'
    $exists = $devices | Where-Object { $_.deviceID -eq $deviceId }
    if ($exists) {
        if ($Introducer -and -not $exists.introducer) {
            $exists.introducer = $true
            Invoke-SyncthingApi -ApiKey $ApiKey -Method PUT -Path "/rest/config/devices/$deviceId" -Body $exists | Out-Null
        }
        return
    }

    $device = @{
        deviceID            = $deviceId
        name                = $Name
        addresses           = @('dynamic')
        compression         = 'metadata'
        introducer          = $Introducer.IsPresent
        skipIntroductionRemovals = $false
        paused              = $false
    }
    Invoke-SyncthingApi -ApiKey $ApiKey -Method POST -Path '/rest/config/devices' -Body $device | Out-Null
}

function Get-LocalSyncthingDeviceId {
    param([string]$ApiKey)
    $status = Invoke-SyncthingApi -ApiKey $ApiKey -Method GET -Path '/rest/system/status'
    return $status.myID
}

function Test-SyncthingDeviceId {
    param([string]$DeviceId)

    if (-not $DeviceId) { return $false }
    return ($DeviceId.Trim() -match '^[0-9A-Z]{7}(-[0-9A-Z]{7}){7}$')
}

function Sync-FolderMembership {
    param(
        [string]$ApiKey,
        [string]$FolderId,
        [string]$SelfDeviceId = ''
    )

    if (-not $FolderId) { return }

    $folder = Invoke-SyncthingApi -ApiKey $ApiKey -Method GET -Path "/rest/config/folders/$FolderId"
    if (-not $folder) { return }

    $knownDevices = Invoke-SyncthingApi -ApiKey $ApiKey -Method GET -Path '/rest/config/devices'

    $devices = @()
    foreach ($d in @($folder.devices)) {
        if ($d -and $d.deviceID) { $devices += $d }
    }

    $present = @{}
    foreach ($d in $devices) { $present[$d.deviceID] = $true }

    $added = 0
    foreach ($dev in @($knownDevices)) {
        $devId = $dev.deviceID
        if (-not $devId) { continue }
        if ($SelfDeviceId -and $devId -eq $SelfDeviceId) { continue }
        if ($present.ContainsKey($devId)) { continue }
        $devices += @{ deviceID = $devId }
        $present[$devId] = $true
        $added++
    }

    if ($added -eq 0) { return }

    $folder.devices = $devices

    $attempt = 0
    while ($true) {
        $attempt++
        try {
            Invoke-SyncthingApi -ApiKey $ApiKey -Method PUT -Path "/rest/config/folders/$FolderId" -Body $folder | Out-Null
            Write-Ok "Folder '$FolderId': added $added device(s) (membership sync)."
            return
        } catch {
            $status = 0
            try { $status = [int]$_.Exception.Response.StatusCode } catch { }
            if (($status -eq 409 -or $status -eq 500) -and $attempt -lt 3) {
                Start-Sleep -Seconds 2
                continue
            }
            throw
        }
    }
}

function Register-SyncthingStartup {
    param($Config)

    $exe = Get-SyncthingExe -Config $Config
    if (-not $exe) {
        return
    }

    $startup = [Environment]::GetFolderPath('Startup')
    $shortcutPath = Join-Path $startup 'GKG Syncthing.lnk'
    if (Test-Path $shortcutPath) {
        return
    }

    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $exe
    $shortcut.WindowStyle = 7
    $shortcut.Description = 'GKG folder sync'
    $shortcut.Save()
    Write-Ok 'Added Syncthing to Windows startup.'
}

function New-SyncFolderShortcut {
    param($Config)

    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktop 'Sync - GKG.lnk'
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $Config.SyncFolder
    $shortcut.Description = 'Two-way sync folder'
    $shortcut.Save()
}

function Install-SyncthingMode {
    param(
        $Config,
        [string[]]$RemoteDeviceIds = @(),
        [string]$IntroducerDeviceId = ''
    )

    Ensure-SyncFolder -Config $Config
    Install-SyncthingPackage -Config $Config
    Start-SyncthingProcess -Config $Config

    $configPath = Wait-SyncthingConfig
    $apiKey = Get-SyncthingApiKey -ConfigPath $configPath

    $sharedDevices = @()
    foreach ($id in $RemoteDeviceIds) {
        if ($id) {
            Add-SyncthingRemoteDevice -ApiKey $apiKey -DeviceId $id
            $sharedDevices += $id.Trim()
        }
    }

    if ($IntroducerDeviceId) {
        $hubId = $IntroducerDeviceId.Trim()
        Add-SyncthingRemoteDevice -ApiKey $apiKey -DeviceId $hubId -Name 'Hub (introducer)' -Introducer $true
        if ($sharedDevices -notcontains $hubId) {
            $sharedDevices += $hubId
        }
    }

    Ensure-SyncthingFolder -Config $Config -ApiKey $apiKey -DeviceIds $sharedDevices
    Register-SyncthingStartup -Config $Config
    New-SyncFolderShortcut -Config $Config

    $myId = Get-LocalSyncthingDeviceId -ApiKey $apiKey
    return @{
        DeviceId = $myId
        GuiUrl   = Get-SyncthingGuiUrl
        SyncFolder = $Config.SyncFolder
    }
}
