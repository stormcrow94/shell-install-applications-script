#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive Windows installer menu (parallel to installer.sh).
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\windows\Installer.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$windowsRoot = $PSScriptRoot
Import-Module (Join-Path $windowsRoot 'lib\Common.psm1') -Force

$repo = Get-InstallerRepoRoot
$settingsPath = Join-Path $repo 'config\settings.conf'
$settings = Read-InstallerSettingsConf -Path $settingsPath

$logDir = if ($settings['LOG_DIR']) { $settings['LOG_DIR'] } else { './logs' }
Initialize-InstallerLogging -LogDirectory $logDir

function Show-InstallerBanner {
    Clear-Host
    Write-Host ''
    Write-Host "`e[36m"
    @'
+===============================================================+
|                                                               |
|     Windows Application Installer / Configuration Menu        |
|     (PowerShell port — Zabbix, Wazuh, Hostname, Domain)       |
|                                                               |
+===============================================================+
'@
    Write-Host "`e[0m"
}

function Get-InstallerPrimaryIPv4 {
    try {
        $candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' }
        if (-not $candidates) { return '' }
        $sorted = $candidates | Sort-Object { if ($_.InterfaceMetric) { $_.InterfaceMetric } else { 999 } }
        return ($sorted | Select-Object -First 1 -ExpandProperty IPAddress)
    }
    catch {
        return ''
    }
}

function Show-InstallerSystemInfo {
    $os = ''
    try {
        $os = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
    }
    catch { }

    $ip = Get-InstallerPrimaryIPv4
    Write-Host ("`e[37mOS:`e[0m {0}" -f $(if ($os) { $os } else { 'Windows' }))
    Write-Host ("`e[37mComputer:`e[0m {0}" -f $env:COMPUTERNAME)
    Write-Host ("`e[37mIPv4:`e[0m {0}" -f $(if ($ip) { $ip } else { '(unknown)' }))
    Write-Host ''
}

function Show-InstallerMainMenu {
    Write-Host "`e[35m+=================================================+`e[0m"
    Write-Host "`e[35m|              MAIN MENU                          |`e[0m"
    Write-Host "`e[35m+=================================================+`e[0m"
    Write-Host ''
    Write-Host "  `e[32m1`e[0m) `e[36mInstall Zabbix Agent`e[0m"
    Write-Host '     Download MSI and install/configure the agent'
    Write-Host ''
    Write-Host "  `e[32m2`e[0m) `e[36mSet computer name (hostname)`e[0m"
    Write-Host '     Rename the computer (reboot required)'
    Write-Host ''
    Write-Host "  `e[32m3`e[0m) `e[36mInstall Wazuh Agent`e[0m"
    Write-Host '     Download MSI and register with Wazuh manager'
    Write-Host ''
    Write-Host "  `e[32m4`e[0m) `e[36mSophos`e[0m"
    Write-Host '     Not automated on Windows in this repo (use Sophos Central / Windows installer)'
    Write-Host ''
    Write-Host "  `e[32m5`e[0m) `e[36mJoin Active Directory domain`e[0m"
    Write-Host '     Online domain join (not Linux SSSD/realm)'
    Write-Host ''
    Write-Host "  `e[32m6`e[0m) `e[36mRun full sequence`e[0m"
    Write-Host '     Hostname, Zabbix, Wazuh, optional Sophos note, optional domain join'
    Write-Host ''
    Write-Host "  `e[33m7`e[0m) `e[36mOpen settings file`e[0m"
    Write-Host "     Edit config\settings.conf"
    Write-Host ''
    Write-Host "  `e[33m8`e[0m) `e[36mView logs`e[0m"
    Write-Host '     List recent installer logs'
    Write-Host ''
    Write-Host "  `e[31m0`e[0m) `e[31mExit`e[0m"
    Write-Host ''
    Write-Host "`e[34m---------------------------------------------------`e[0m"
}

function Invoke-InstallerChildScript {
    param([string]$RelativePath)
    $path = Join-Path $windowsRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        Write-InstallerError "Script not found: $path"
        return 1
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path
    return $LASTEXITCODE
}

function Edit-InstallerSettingsFile {
    Write-InstallerHeader 'Settings'
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        Write-InstallerError "Configuration file not found: $settingsPath"
        Wait-InstallerKey
        return
    }
    Write-InstallerInfo 'Opening settings in your default editor...'
    Write-InstallerWarning 'Edit carefully; invalid values can break installs.'
    try {
        if (Get-Command notepad.exe -ErrorAction SilentlyContinue) {
            Start-Process -FilePath 'notepad.exe' -ArgumentList "`"$settingsPath`"" -Wait
        }
        else {
            Invoke-Item -LiteralPath $settingsPath
        }
        Write-InstallerSuccess 'Editor closed.'
    }
    catch {
        Write-InstallerError $_.Exception.Message
    }
    Wait-InstallerKey
}

function Show-InstallerLogs {
    Write-InstallerHeader 'Installation logs'
    $logsDir = Join-Path $repo 'logs'
    if (-not (Test-Path -LiteralPath $logsDir)) {
        Write-InstallerError "Log directory not found: $logsDir"
        Wait-InstallerKey
        return
    }

    $logs = Get-ChildItem -LiteralPath $logsDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    if (-not $logs) {
        Write-InstallerInfo 'No log files found.'
        Wait-InstallerKey
        return
    }

    Write-InstallerInfo 'Available logs:'
    Write-Host ''
    $i = 1
    foreach ($f in $logs) {
        Write-Host ("  {0}) {1} ({2} bytes) - {3}" -f $i, $f.Name, $f.Length, $f.LastWriteTime)
        $i++
    }
    Write-Host ''
    Write-Host '  0) Back'
    Write-Host ''
    $choice = Read-Host 'Select a log number to view (0 = back)'
    if ($choice -eq '0' -or [string]::IsNullOrWhiteSpace($choice)) { return }

    $idx = 0
    if ([int]::TryParse($choice, [ref]$idx) -and $idx -ge 1 -and $idx -le $logs.Count) {
        $sel = $logs[$idx - 1]
        Write-InstallerInfo "Showing: $($sel.Name)"
        Write-Host ''
        Get-Content -LiteralPath $sel.FullName -Tail 200 | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-InstallerError 'Invalid selection.'
    }
    Wait-InstallerKey
}

function Show-InstallerSophosStub {
    Write-InstallerHeader 'Sophos'
    Write-InstallerInfo 'Sophos for Windows is not installed by this repository.'
    Write-InstallerInfo 'Use Sophos Central or the official Windows installer from Sophos.'
    Write-InstallerLogLine 'INFO' 'Sophos menu: stub only'
    Wait-InstallerKey
}

function Invoke-InstallerFullSequence {
    Write-InstallerHeader 'Full installation sequence'
    Write-InstallerWarning 'This will run, in order:'
    Write-Host '  1) Set computer name (you can cancel inside the script)'
    Write-Host '  2) Install Zabbix Agent'
    Write-Host '  3) Install Wazuh Agent'
    Write-Host '  4) Sophos — skipped (see menu item 4)'
    Write-Host '  5) Join domain — optional'
    Write-Host ''
    if (-not (Read-InstallerConfirm -PromptText 'Continue with full sequence?' -DefaultYes $false)) {
        Write-InstallerInfo 'Cancelled.'
        Wait-InstallerKey
        return
    }

    $failed = 0

    Write-InstallerSeparator
    Write-InstallerInfo 'Step 1/5: Computer name'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $windowsRoot 'Set-Hostname.ps1')
    if ($LASTEXITCODE -ne 0) { $failed++ }

    Write-InstallerSeparator
    Write-InstallerInfo 'Step 2/5: Zabbix Agent'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $windowsRoot 'Install-Zabbix.ps1')
    if ($LASTEXITCODE -ne 0) { $failed++ }

    Write-InstallerSeparator
    Write-InstallerInfo 'Step 3/5: Wazuh Agent'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $windowsRoot 'Install-Wazuh.ps1')
    if ($LASTEXITCODE -ne 0) { $failed++ }

    Write-InstallerSeparator
    Write-InstallerInfo 'Step 4/5: Sophos — skipped by design on Windows'

    Write-InstallerSeparator
    Write-InstallerInfo 'Step 5/5: Domain join'
    if (Read-InstallerConfirm -PromptText 'Join this computer to a domain now?' -DefaultYes $false) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $windowsRoot 'Join-Domain.ps1')
        if ($LASTEXITCODE -ne 0) { $failed++ }
    }
    else {
        Write-InstallerInfo 'Domain join skipped.'
    }

    Write-InstallerSeparator
    Write-InstallerHeader 'Summary'
    if ($failed -eq 0) {
        Write-InstallerSuccess 'Full sequence completed without reported script failures.'
    }
    else {
        Write-InstallerWarning "$failed step(s) returned a non-zero exit code. Review logs in logs\"
    }
    Write-InstallerInfo ("Session log: {0}" -f (Get-InstallerLogFile))
    Wait-InstallerKey
}

Assert-InstallerAdministrator

try {
    while ($true) {
        Show-InstallerBanner
        Show-InstallerSystemInfo
        Show-InstallerMainMenu
        $choice = Read-Host "`e[32mEnter choice`e[0m"

        switch ($choice) {
            '1' {
                Write-InstallerHeader 'Zabbix Agent'
                Invoke-InstallerChildScript 'Install-Zabbix.ps1' | Out-Null
                Wait-InstallerKey
            }
            '2' {
                Write-InstallerHeader 'Computer name'
                Invoke-InstallerChildScript 'Set-Hostname.ps1' | Out-Null
                Wait-InstallerKey
            }
            '3' {
                Write-InstallerHeader 'Wazuh Agent'
                Invoke-InstallerChildScript 'Install-Wazuh.ps1' | Out-Null
                Wait-InstallerKey
            }
            '4' { Show-InstallerSophosStub }
            '5' {
                Write-InstallerHeader 'Domain join'
                Invoke-InstallerChildScript 'Join-Domain.ps1' | Out-Null
                Wait-InstallerKey
            }
            '6' { Invoke-InstallerFullSequence }
            '7' { Edit-InstallerSettingsFile }
            '8' { Show-InstallerLogs }
            '0' {
                Write-InstallerInfo 'Exiting.'
                Write-InstallerLogEnd
                exit 0
            }
            Default {
                Write-InstallerError "Invalid option: $choice"
                Wait-InstallerKey
            }
        }
    }
}
finally {
    Write-InstallerLogEnd
}
