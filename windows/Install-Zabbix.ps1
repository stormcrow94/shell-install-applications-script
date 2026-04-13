#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Zabbix Agent on Windows from the official MSI (settings.conf).
.PARAMETER ZabbixServer
    Optional override for Zabbix server/proxy (maps to SERVER / SERVERACTIVE).
#>
[CmdletBinding()]
param(
    [string]$ZabbixServer
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
    Write-InstallerHeader 'Zabbix Agent installation'
    Assert-InstallerAdministrator

    if (Get-InstallerSettingsBool -Settings $settings -Key 'CHECK_INTERNET' -Default $true) {
        if (-not (Test-InstallerInternetConnectivity)) {
            Write-InstallerError 'Internet is required for this installation.'
            exit 1
        }
    }

    if (-not [Environment]::Is64BitOperatingSystem) {
        Write-InstallerError 'This MSI is for 64-bit Windows (amd64).'
        exit 1
    }

    $msiUrl = if ($settings['ZABBIX_WINDOWS_MSI_URL']) {
        $settings['ZABBIX_WINDOWS_MSI_URL'].Trim()
    }
    else {
        'https://cdn.zabbix.com/zabbix/binaries/stable/7.0/7.0.25/zabbix_agent-7.0.25-windows-amd64-openssl.msi'
    }

    $server = if ($ZabbixServer) { $ZabbixServer.Trim() } else { $settings['ZABBIX_PROXY_SERVER'].Trim() }
    if ([string]::IsNullOrWhiteSpace($server)) {
        Write-InstallerError 'ZABBIX_PROXY_SERVER is empty in config/settings.conf.'
        exit 1
    }

    $serverPort = if ($settings['ZABBIX_SERVER_PORT']) { $settings['ZABBIX_SERVER_PORT'].Trim() } else { '10051' }
    $listenPort = if ($settings['ZABBIX_AGENT_PORT']) { [int]$settings['ZABBIX_AGENT_PORT'] } else { 10050 }
    $hostname = $env:COMPUTERNAME
    $serverActive = '{0}:{1}' -f $server, $serverPort

    $msiLocal = Join-Path $env:TEMP ('zabbix_agent_windows_{0}.msi' -f (Get-Date -Format 'yyyyMMddHHmmss'))

    Write-InstallerInfo "Downloading: $msiUrl"
    Invoke-WebRequest -Uri $msiUrl -OutFile $msiLocal -UseBasicParsing

    # Public properties per Zabbix Windows MSI documentation (Server, ServerActive, ListenPort, Hostname).
    $msiArgs = @(
        '/i', "`"$msiLocal`"",
        '/qn', '/norestart',
        "SERVER=$server",
        "SERVERACTIVE=$serverActive",
        "LISTENPORT=$listenPort",
        "HOSTNAME=$hostname",
        'HOSTMETADATA=Windows'
    )

    $argLine = $msiArgs -join ' '
    Write-InstallerInfo "Running msiexec $argLine"
    Write-InstallerLogLine 'INFO' "msiexec $argLine"

    $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -ne 0) {
        Write-InstallerError ("msiexec exited with code {0}. See Windows Application log or run with /l*v for verbose MSI logging." -f $p.ExitCode)
        exit $p.ExitCode
    }

    Add-InstallerFirewallTcpPort -Port $listenPort -DisplayName 'Zabbix Agent inbound'

    $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Zabbix*' -or $_.DisplayName -like '*Zabbix*' } | Select-Object -First 1
    if ($svc) {
        Set-Service -Name $svc.Name -StartupType Automatic -ErrorAction SilentlyContinue
        Restart-Service -Name $svc.Name -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        $svc2 = Get-Service -Name $svc.Name
        if ($svc2.Status -ne 'Running') {
            Write-InstallerError "Service $($svc.Name) is not running (status: $($svc2.Status))."
            exit 1
        }
        Write-InstallerSuccess "Zabbix Agent service is running ($($svc.Name))."
    }
    else {
        Write-InstallerWarning 'Zabbix Windows service not found by name pattern; verify installation manually.'
    }

    Write-InstallerSeparator
    Write-InstallerSuccess 'Zabbix Agent installation finished.'
    Write-InstallerInfo ("Log file: {0}" -f (Get-InstallerLogFile))
}
finally {
    Write-InstallerLogEnd
}
