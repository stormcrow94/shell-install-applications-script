#Requires -Version 5.1
<#
.SYNOPSIS
    Joins the computer to an Active Directory domain (Windows equivalent of domain registration).
.NOTES
    This is not the same as Linux realm/SSSD. Access control is governed by AD/GPO and local groups.
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
    Write-InstallerHeader 'Domain join'
    Assert-InstallerAdministrator

    $defaultDomain = if ($settings['DEFAULT_DOMAIN']) { $settings['DEFAULT_DOMAIN'].Trim() } else { '' }
    $defaultUser = if ($settings['DEFAULT_ADMIN_USER']) { $settings['DEFAULT_ADMIN_USER'].Trim() } else { '' }
    $defaultGroup = if ($settings['DEFAULT_ADMIN_GROUP']) { $settings['DEFAULT_ADMIN_GROUP'].Trim() } else { '' }
    $presetComputerName = if ($settings['DOMAIN_COMPUTER_NAME']) { $settings['DOMAIN_COMPUTER_NAME'].Trim() } else { '' }

    $domain = Invoke-InstallerUserPrompt -PromptText 'DNS domain name (e.g. corp.example.com)' -DefaultValue $defaultDomain
    if ([string]::IsNullOrWhiteSpace($domain)) {
        Write-InstallerError 'Domain name is required.'
        exit 1
    }

    Write-InstallerInfo 'You will be prompted for domain credentials (user with rights to join the domain).'
    $user = Invoke-InstallerUserPrompt -PromptText 'User name (DOMAIN\user or user@domain.com)' -DefaultValue $defaultUser
    if ([string]::IsNullOrWhiteSpace($user)) {
        Write-InstallerError 'User name is required.'
        exit 1
    }

    $plain = Read-InstallerPasswordPlain -PromptText 'Password'
    if ([string]::IsNullOrWhiteSpace($plain)) {
        Write-InstallerError 'Password cannot be empty.'
        exit 1
    }

    $secure = ConvertTo-SecureString -String $plain -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($user, $secure)
    $plain = $null

    $newComputerName = $presetComputerName
    if ([string]::IsNullOrWhiteSpace($newComputerName)) {
        $useNew = Read-InstallerConfirm -PromptText 'Rename computer before joining? (max 15 chars NetBIOS)' -DefaultYes $false
        if ($useNew) {
            $newComputerName = Invoke-InstallerUserPrompt -PromptText 'New computer name (leave empty to keep current)'
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($newComputerName)) {
        if ($newComputerName.Length -gt 15) {
            Write-InstallerError 'Computer NetBIOS name must be 15 characters or fewer.'
            exit 1
        }
    }

    Write-InstallerSeparator
    Write-InstallerInfo 'Choose post-join local group membership for a domain group (optional).'
    Write-InstallerInfo '1) Do not add domain groups to local groups (use GPO/AD only)'
    Write-InstallerInfo '2) Add a domain group to local Administrators'
    Write-InstallerInfo '3) Add a domain group to Remote Desktop Users'
    $mode = Invoke-InstallerUserPrompt -PromptText 'Choice [1-3]' -DefaultValue '1'

    $groupToAdd = $null
    $localTarget = $null
    switch ($mode) {
        '2' {
            $localTarget = 'Administrators'
            $groupToAdd = Invoke-InstallerUserPrompt -PromptText 'Domain group (e.g. CONTOSO\Server-Admins)' -DefaultValue $defaultGroup
        }
        '3' {
            $localTarget = 'Remote Desktop Users'
            $groupToAdd = Invoke-InstallerUserPrompt -PromptText 'Domain group (e.g. CONTOSO\RDS-Users)' -DefaultValue $defaultGroup
        }
        Default { }
    }

    Write-InstallerSeparator
    Write-InstallerInfo "Joining domain '$domain'..."

    $joinParams = @{
        DomainName   = $domain
        Credential   = $cred
        Force        = $true
        ErrorAction  = 'Stop'
    }
    if (-not [string]::IsNullOrWhiteSpace($newComputerName)) {
        $joinParams['NewName'] = $newComputerName
    }

    Add-Computer @joinParams
    Write-InstallerSuccess 'Domain join completed.'
    Write-InstallerWarning 'A reboot is usually required to finish the domain join.'

    if ($localTarget -and -not [string]::IsNullOrWhiteSpace($groupToAdd)) {
        try {
            Add-LocalGroupMember -Group $localTarget -Member $groupToAdd -ErrorAction Stop
            Write-InstallerSuccess "Added '$groupToAdd' to local '$localTarget'."
        }
        catch {
            Write-InstallerWarning "Could not add group to '$localTarget': $($_.Exception.Message)"
        }
    }
    elseif ($localTarget) {
        Write-InstallerWarning 'No domain group entered; skipping local group update.'
    }

    Write-InstallerInfo ("Log file: {0}" -f (Get-InstallerLogFile))
}
finally {
    Write-InstallerLogEnd
}
