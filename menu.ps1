# GKG-Sync - Menu chinh (Windows GUI)

param(
    [ValidateSet('Menu', 'Install', 'Restart', 'OpenSync', 'Guide', 'Manage')]
    [string]$Action = 'Menu'
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-DefaultSyncFolder {
    return Join-Path $env:USERPROFILE 'Documents\Sync'
}

function Get-ConfiguredSyncFolder {
    try {
        . (Join-Path $ScriptDir 'load-config.ps1')
        Import-GkgConfig -ScriptDir $ScriptDir
        return $script:PackConfig.SyncFolder
    } catch {
        return Get-DefaultSyncFolder
    }
}

function Start-InstallConsole {
    $installScript = Join-Path $ScriptDir 'install.ps1'
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-NoExit',
        '-File', "`"$installScript`""
    ) | Out-Null
}

function Start-JoinConsole {
    $installScript = Join-Path $ScriptDir 'install.ps1'
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-NoExit',
        '-File', "`"$installScript`"",
        '-Mode', 'Join'
    ) | Out-Null
}

function Start-RestartConsole {
    $restartScript = Join-Path $ScriptDir 'khoi-dong-sync.ps1'
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-NoExit',
        '-File', "`"$restartScript`""
    ) | Out-Null
}

function Start-SyncNowConsole {
    $syncNowScript = Join-Path $ScriptDir 'sync-now.ps1'
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-NoExit',
        '-File', "`"$syncNowScript`""
    ) | Out-Null
}

function Open-SyncFolder {
    $folder = Get-ConfiguredSyncFolder
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
    }
    Start-Process $folder | Out-Null
}

function Open-Guide {
    $startHere = Join-Path $ScriptDir 'START-HERE.html'
    $huongDan = Join-Path $ScriptDir 'HUONG-DAN.html'
    if (Test-Path $startHere) {
        Start-Process $startHere | Out-Null
    } elseif (Test-Path $huongDan) {
        Start-Process $huongDan | Out-Null
    }
}

function Open-ManagePage {
    $url = 'http://127.0.0.1:8384'
    try {
        . (Join-Path $ScriptDir 'load-config.ps1')
        Import-GkgConfig -ScriptDir $ScriptDir
        $url = Get-SyncthingGuiUrl
    } catch {
        # default 8384
    }
    Start-Process $url | Out-Null
}

function Show-MainMenu {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'GKG Sync - File sync'
    $form.Size = New-Object System.Drawing.Size(440, 540)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox = $false
    $form.MinimizeBox = $true
    $form.TopMost = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'Sync files between your machines'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(24, 16)
    $form.Controls.Add($title)

    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Text = 'What do you want to do?'
    $subtitle.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $subtitle.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
    $subtitle.AutoSize = $true
    $subtitle.Location = New-Object System.Drawing.Point(26, 48)
    $form.Controls.Add($subtitle)

    function New-MenuButton {
        param(
            [string]$Text,
            [int]$Top,
            [System.Drawing.Color]$BackColor,
            [scriptblock]$OnClick
        )
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $Text
        $btn.Size = New-Object System.Drawing.Size(380, 44)
        $btn.Location = New-Object System.Drawing.Point(24, $Top)
        $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $btn.BackColor = $BackColor
        $btn.ForeColor = [System.Drawing.Color]::White
        $btn.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
        $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
        $btn.Add_Click($OnClick)
        $form.Controls.Add($btn)
        return $btn
    }

    $green = [System.Drawing.Color]::FromArgb(22, 163, 74)
    $blue = [System.Drawing.Color]::FromArgb(37, 99, 235)
    $slate = [System.Drawing.Color]::FromArgb(100, 116, 139)

    [void](New-MenuButton -Text '1. Install / Add machine' -Top 82 -BackColor $green -OnClick {
        Start-InstallConsole
    })

    [void](New-MenuButton -Text '2. Restart sync' -Top 134 -BackColor $blue -OnClick {
        Start-RestartConsole
    })

    [void](New-MenuButton -Text '3. Open Sync folder' -Top 186 -BackColor $blue -OnClick {
        Open-SyncFolder
    })

    [void](New-MenuButton -Text '4. Guide' -Top 238 -BackColor $slate -OnClick {
        Open-Guide
    })

    [void](New-MenuButton -Text '5. Syncthing dashboard' -Top 290 -BackColor $slate -OnClick {
        Open-ManagePage
    })

    [void](New-MenuButton -Text '6. Join network' -Top 342 -BackColor $blue -OnClick {
        Start-JoinConsole
    })

    [void](New-MenuButton -Text '7. Sync now' -Top 394 -BackColor $green -OnClick {
        Start-SyncNowConsole
    })

    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = 'First time? Click item 1 and follow the instructions in the new window.'
    $hint.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $hint.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
    $hint.AutoSize = $false
    $hint.Size = New-Object System.Drawing.Size(380, 36)
    $hint.Location = New-Object System.Drawing.Point(26, 458)
    $form.Controls.Add($hint)

    [void]$form.ShowDialog()
}

switch ($Action) {
    'Install' { Start-InstallConsole; break }
    'Restart' { Start-RestartConsole; break }
    'OpenSync' { Open-SyncFolder; break }
    'Guide' { Open-Guide; break }
    'Manage' { Open-ManagePage; break }
    default { Show-MainMenu }
}
