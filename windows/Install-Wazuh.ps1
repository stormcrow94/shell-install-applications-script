#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Wazuh Agent on Windows from packages.wazuh.com MSI (settings.conf).
.PARAMETER WazuhManager
    Optional override for WAZUH_MANAGER.
#>
[CmdletBinding()]
param(
    [string]$WazuhManager
)

$ErrorActionPreference = 'Stop'
$windowsRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $windowsRoot 'lib\Common.psm1') -Force

$repo = Get-InstallerRepoRoot
$settingsPath = Join-Path $repo 'config\settings.conf'
$settings = Read-InstallerSettingsConf -Path $settingsPath

$logDir = if ($settings['LOG_DIR']) { $settings['LOG_DIR'] } else { './logs' }
Initialize-InstallerLogging -LogDirectory $logDir

try {
    Write-InstallerHeader 'Wazuh Agent installation'
    Assert-InstallerAdministrator

    if (Get-InstallerSettingsBool -Settings $settings -Key 'CHECK_INTERNET' -Default $true) {
        if (-not (Test-InstallerInternetConnectivity)) {
            Write-InstallerError 'Internet is required for this installation.'
            exit 1
        }
    }

    $ver = if ($settings['WAZUH_VERSION']) { $settings['WAZUH_VERSION'].Trim() } else { '4.14.0' }
    $rev = if ($settings['WAZUH_REVISION']) { $settings['WAZUH_REVISION'].Trim() } else { '1' }
    $manager = if ($WazuhManager) { $WazuhManager.Trim() } else { $settings['WAZUH_MANAGER'].Trim() }

    if ([string]::IsNullOrWhiteSpace($manager)) {
        Write-InstallerError 'WAZUH_MANAGER is empty in config/settings.conf.'
        exit 1
    }

    $msiUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$ver-$rev.msi"
    $msiLocal = Join-Path $env:TEMP ("wazuh-agent-$ver-$rev.msi")

    Write-InstallerInfo "Downloading: $msiUrl"
    Invoke-WebRequest -Uri $msiUrl -OutFile $msiLocal -UseBasicParsing

    $msiArgs = @(
        '/i', "`"$msiLocal`"",
        '/qn', '/norestart',
        "WAZUH_MANAGER=$manager"
    )

    $argLine = $msiArgs -join ' '
    Write-InstallerInfo "Running msiexec $argLine"
    Write-InstallerLogLine 'INFO' "msiexec $argLine"

    $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -ne 0) {
        Write-InstallerError ("msiexec exited with code {0}." -f $p.ExitCode)
        exit $p.ExitCode
    }

    $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match 'Wazuh' -or $_.DisplayName -match 'Wazuh'
    } | Select-Object -First 1

    if ($svc) {
        Set-Service -Name $svc.Name -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name $svc.Name -ErrorAction Stop
        Start-Sleep -Seconds 2
        $svc2 = Get-Service -Name $svc.Name
        if ($svc2.Status -ne 'Running') {
            Write-InstallerWarning "Service $($svc.Name) status: $($svc2.Status)"
        }
        else {
            Write-InstallerSuccess "Wazuh Agent service is running ($($svc.Name))."
        }
    }
    else {
        Write-InstallerWarning 'Wazuh Windows service not found; verify installation manually.'
    }

    Write-InstallerInfo 'Configuration is typically under "C:\Program Files (x86)\ossec-agent" or "C:\Program Files\ossec-agent".'

    Write-InstallerSeparator
    Write-InstallerSuccess 'Wazuh Agent installation finished.'
    Write-InstallerInfo ("Log file: {0}" -f (Get-InstallerLogFile))
}
finally {
    Write-InstallerLogEnd
}
