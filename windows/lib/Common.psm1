#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helpers for the Windows PowerShell installer (parallel to lib/common.sh).
#>

$script:InstallerLogFile = $null
$script:InstallerLogDir = $null

function Get-InstallerRepoRoot {
    <#
    PSScriptRoot for this module is <repo>/windows/lib — repo root is two levels up.
    #>
    $windowsDir = Split-Path -Parent $PSScriptRoot
    return (Split-Path -Parent $windowsDir)
}

function Get-InstallerWindowsRoot {
    Split-Path -Parent $PSScriptRoot
}

function Initialize-InstallerLogging {
    [CmdletBinding()]
    param(
        [string]$LogDirectory
    )

    $repo = Get-InstallerRepoRoot
    if (-not $LogDirectory) {
        $LogDirectory = Join-Path $repo 'logs'
    }
    elseif ($LogDirectory -match '^\./') {
        $LogDirectory = Join-Path $repo ($LogDirectory.TrimStart('.', '/').TrimStart('\'))
    }
    elseif (-not [System.IO.Path]::IsPathRooted($LogDirectory)) {
        $LogDirectory = Join-Path $repo $LogDirectory
    }

    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }

    $script:InstallerLogDir = $LogDirectory
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:InstallerLogFile = Join-Path $LogDirectory "installer_$stamp.log"
    New-Item -ItemType File -Path $script:InstallerLogFile -Force | Out-Null

    Write-InstallerLogLine 'INFO' "Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

function Get-InstallerLogFile {
    $script:InstallerLogFile
}

function Write-InstallerLogLine {
    param(
        [Parameter(Mandatory)][string]$Level,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $script:InstallerLogFile) { return }
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $script:InstallerLogFile -Value $line -Encoding UTF8
}

function Write-InstallerSuccess {
    param([string]$Message)
    Write-Host ("`e[32m✓ {0}`e[0m" -f $Message)
    Write-InstallerLogLine 'SUCCESS' $Message
}

function Write-InstallerError {
    param([string]$Message)
    Write-Host ("`e[31m✗ {0}`e[0m" -f $Message)
    Write-InstallerLogLine 'ERROR' $Message
}

function Write-InstallerWarning {
    param([string]$Message)
    Write-Host ("`e[33m⚠ {0}`e[0m" -f $Message)
    Write-InstallerLogLine 'WARNING' $Message
}

function Write-InstallerInfo {
    param([string]$Message)
    Write-Host ("`e[36mℹ {0}`e[0m" -f $Message)
    Write-InstallerLogLine 'INFO' $Message
}

function Write-InstallerHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host ("`e[35m================================`e[0m")
    Write-Host ("`e[35m  {0}`e[0m" -f $Title)
    Write-Host ("`e[35m================================`e[0m")
    Write-Host ""
    Write-InstallerLogLine 'INFO' "HEADER: $Title"
}

function Write-InstallerSeparator {
    Write-Host ("`e[34m────────────────────────────────`e[0m")
}

function Test-InstallerAdministrator {
    $principal = [Security.Principal.WindowsPrincipal]::new(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-InstallerAdministrator {
    if (-not (Test-InstallerAdministrator)) {
        Write-InstallerError 'Run PowerShell as Administrator.'
        Write-InstallerLogLine 'ERROR' 'Elevation required'
        exit 1
    }
    Write-InstallerLogLine 'INFO' 'Administrator check: OK'
}

function Test-InstallerInternetConnectivity {
    try {
        Write-InstallerInfo 'Checking internet connectivity...'
        $ok = Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($ok) {
            Write-InstallerSuccess 'Internet connectivity: OK'
            Write-InstallerLogLine 'SUCCESS' 'Internet check passed'
            return $true
        }
    }
    catch { }
    Write-InstallerError 'No internet connectivity (ping to 8.8.8.8 failed).'
    Write-InstallerLogLine 'ERROR' 'Internet check failed'
    return $false
}

function Get-InstallerSettingsPath {
    Join-Path (Get-InstallerRepoRoot) 'config\settings.conf'
}

function Read-InstallerSettingsConf {
    [CmdletBinding()]
    param(
        [string]$Path = (Get-InstallerSettingsPath)
    )

    $result = @{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $result
    }

    foreach ($rawLine in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $line = $rawLine.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }

        if ($line -match '^\s*([A-Za-z0-9_]+)\s*=\s*(.+)\s*$') {
            $key = $Matches[1]
            $val = $Matches[2].Trim()

            if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
                $val = $val.Substring(1, $val.Length - 2)
            }
            $result[$key] = $val
        }
    }

    return $result
}

function Get-InstallerSettingsBool {
    param(
        [hashtable]$Settings,
        [string]$Key,
        [bool]$Default = $true
    )
    if (-not $Settings.ContainsKey($Key)) { return $Default }
    $v = $Settings[$Key].ToString().Trim().ToLowerInvariant()
    return @('1', 'true', 'yes', 'y', 'on') -contains $v
}

function Invoke-InstallerUserPrompt {
    param(
        [string]$PromptText,
        [string]$DefaultValue
    )
    if ($DefaultValue) {
        $read = Read-Host ("{0} [{1}]" -f $PromptText, $DefaultValue)
        if ([string]::IsNullOrWhiteSpace($read)) { return $DefaultValue }
        return $read
    }
    return Read-Host $PromptText
}

function Read-InstallerConfirm {
    param(
        [string]$PromptText,
        [bool]$DefaultYes = $false
    )
    $suffix = if ($DefaultYes) { '[Y/n]' } else { '[y/N]' }
    $resp = Read-Host ("{0} {1}" -f $PromptText, $suffix)
    if ([string]::IsNullOrWhiteSpace($resp)) {
        return $DefaultYes
    }
    return $resp -match '^(y|yes|s|sim)$'
}

function Read-InstallerPasswordPlain {
    param([string]$PromptText = 'Password')
    $sec = Read-Host $PromptText -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) | Out-Null
    }
}

function Wait-InstallerKey {
    Write-Host ""
    Write-Host "`e[33mPress Enter to continue...`e[0m"
    Read-Host | Out-Null
}

function Test-InstallerIpAddress {
    param([string]$Ip)
    if ([string]::IsNullOrWhiteSpace($Ip)) { return $false }
    return [bool]($Ip -as [System.Net.IPAddress])
}

function Add-InstallerFirewallTcpPort {
    param(
        [int]$Port,
        [string]$DisplayName
    )

    try {
        $profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue |
            Where-Object { $_.Enabled -eq 'True' }
        if (-not $profiles) {
            Write-InstallerInfo 'No enabled firewall profiles detected; skipping firewall rule.'
            return
        }

        $existing = Get-NetFirewallRule -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $DisplayName }
        if ($existing) {
            Write-InstallerInfo "Firewall rule already exists: $DisplayName"
            return
        }

        New-NetFirewallRule -DisplayName $DisplayName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -ErrorAction Stop | Out-Null
        Write-InstallerSuccess "Firewall: inbound TCP $Port ($DisplayName)"
        Write-InstallerLogLine 'SUCCESS' "Firewall rule added: $DisplayName port $Port"
    }
    catch {
        Write-InstallerWarning "Could not add firewall rule: $($_.Exception.Message)"
        Write-InstallerLogLine 'WARNING' $_.Exception.Message
    }
}

function Stop-InstallerTranscriptIfAny {
    try { Stop-Transcript | Out-Null } catch { }
}

function Write-InstallerLogEnd {
    if ($script:InstallerLogFile) {
        Write-InstallerLogLine 'INFO' ("End: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    }
}

Export-ModuleMember -Function @(
    'Get-InstallerRepoRoot',
    'Get-InstallerWindowsRoot',
    'Initialize-InstallerLogging',
    'Get-InstallerLogFile',
    'Write-InstallerSuccess',
    'Write-InstallerError',
    'Write-InstallerWarning',
    'Write-InstallerInfo',
    'Write-InstallerHeader',
    'Write-InstallerSeparator',
    'Write-InstallerLogLine',
    'Test-InstallerAdministrator',
    'Assert-InstallerAdministrator',
    'Test-InstallerInternetConnectivity',
    'Get-InstallerSettingsPath',
    'Read-InstallerSettingsConf',
    'Get-InstallerSettingsBool',
    'Invoke-InstallerUserPrompt',
    'Read-InstallerConfirm',
    'Read-InstallerPasswordPlain',
    'Wait-InstallerKey',
    'Test-InstallerIpAddress',
    'Add-InstallerFirewallTcpPort',
    'Stop-InstallerTranscriptIfAny',
    'Write-InstallerLogEnd'
)
