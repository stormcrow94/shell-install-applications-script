# Windows PowerShell installer

This folder mirrors the Linux Bash installer in the repository root. It installs **Zabbix Agent** and **Wazuh Agent** from official HTTPS MSIs, can **rename the computer**, and can **join Active Directory** using the same `config/settings.conf` values as the Linux scripts.

## Requirements

- Windows 10 / 11 or Windows Server (64-bit) for the default Zabbix MSI (amd64).
- **PowerShell 5.1 or later**, run **as Administrator**.
- Outbound **HTTPS** access to `cdn.zabbix.com` and `packages.wazuh.com`.
- For domain join: DNS resolution of the domain, connectivity to domain controllers, and an account that may join computers to the domain.

## Usage

From the repository root:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd <path-to-repo>
.\windows\Installer.ps1
```

Or run individual scripts:

```powershell
.\windows\Install-Zabbix.ps1
.\windows\Install-Wazuh.ps1
.\windows\Set-Hostname.ps1
.\windows\Join-Domain.ps1
```

Optional overrides (same idea as passing `$1` on Linux):

```powershell
.\windows\Install-Zabbix.ps1 -ZabbixServer 'zabbix.example.com'
.\windows\Install-Wazuh.ps1 -WazuhManager 'manager.example.com'
```

## Configuration

Edit `config/settings.conf` in the repo root. Windows-specific defaults include:

- `ZABBIX_WINDOWS_MSI_URL` — official Zabbix Windows MSI (OpenSSL amd64).
- `ZABBIX_PROXY_SERVER`, `ZABBIX_SERVER_PORT`, `ZABBIX_AGENT_PORT` — passed into the Zabbix MSI as `SERVER`, `SERVERACTIVE`, and `LISTENPORT`.
- `WAZUH_VERSION`, `WAZUH_REVISION`, `WAZUH_MANAGER` — used to build the Wazuh MSI URL and `WAZUH_MANAGER` for `msiexec`.

## Sophos

There is **no** bundled Sophos Windows installer here. Use Sophos Central or Sophos-supplied Windows packages for your tenant.

## Domain join vs Linux `register_domain.sh`

Linux domain registration in this repo uses **realm/SSSD** (Ubuntu-oriented). On Windows, **Join-Domain.ps1** uses **`Add-Computer`** for a standard AD join. Fine-grained login and remote access rules are normally handled by **Group Policy** and **AD group membership**, not by SSSD options.

## Logs

Installer scripts append to timestamped files under the repository `logs/` directory (same `LOG_DIR` convention as Linux).
