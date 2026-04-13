#Requires -Version 5.1
<#
.SYNOPSIS
    Renames the computer (Windows equivalent of hostname.sh).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$windowsRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $windowsRoot 'lib\Common.psm1') -Force

$repo = Get-InstallerRepoRoot
$settingsPath = Join-Path $repo 'config\settings.conf'
$settings = Read-InstallerSettingsConf -Path $settingsPath

$logDir = if ($settings['LOG_DIR']) { $settings['LOG_DIR'] } else { './logs' }
Initialize-InstallerLogging -LogDirectory $logDir

try {
    Write-InstallerHeader 'Hostname configuration'
    Assert-InstallerAdministrator

    $current = $env:COMPUTERNAME
    Write-InstallerInfo "Current computer name: $current"
    Write-InstallerSeparator

    $newName = Invoke-InstallerUserPrompt -PromptText 'Enter new computer name (hostname)'
    if ([string]::IsNullOrWhiteSpace($newName)) {
        Write-InstallerError 'Name cannot be empty.'
        exit 1
    }

    if ($newName -notmatch '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$') {
        Write-InstallerError 'Invalid name. Use letters, numbers, and hyphens; must start and end with a letter or number.'
        exit 1
    }

    Write-InstallerWarning "Rename computer from '$current' to '$newName'"
    if (-not (Read-InstallerConfirm -PromptText 'Confirm rename?' -DefaultYes $false)) {
        Write-InstallerInfo 'Cancelled.'
        exit 0
    }

    Write-InstallerSeparator
    Write-InstallerInfo 'Renaming computer...'
    Rename-Computer -NewName $newName -Force
    Write-InstallerSuccess "Computer will use name '$newName' after reboot."
    Write-InstallerWarning 'Reboot the system for the name change to take full effect.'
    Write-InstallerInfo ("Log file: {0}" -f (Get-InstallerLogFile))
}
finally {
    Write-InstallerLogEnd
}
