# Project Documentation

## 1. Objective

This repository provides Bash scripts to automate Linux server baseline tasks:

- hostname configuration
- Zabbix Agent installation and configuration
- Wazuh Agent installation and configuration
- Sophos installation through the official `SophosSetup.sh` script
- domain join via Realmd/SSSD

Execution is available through an interactive menu (`installer.sh`) or direct script calls.

## 2. Repository Components

### Core scripts

- `installer.sh`: interactive menu and full sequence orchestrator
- `install_zabbix.sh`: installs and configures Zabbix Agent
- `install_wazuh.sh`: installs and configures Wazuh Agent
- `hostname.sh`: changes system hostname and updates `/etc/hosts` when needed
- `register_domain.sh`: joins machine to domain and configures SSSD/sudo access
- `SophosSetup.sh`: official Sophos installer provided by vendor

### Shared modules and config

- `lib/common.sh`: shared functions (logging, distro detection, package handling, prompts)
- `config/settings.conf`: default parameters used by scripts

### Existing guides

- `README.md`
- `WIKI.md`
- `QUICKSTART.md`
- `QUICKSTART_WAZUH.md`
- `WAZUH_IMPLEMENTATION.md`
- `DEBIAN_GUIDE.md`
- `EXAMPLES.md`

## 3. Runtime Model

### 3.1 Logging

Most scripts using `lib/common.sh` create logs at:

`logs/installer_YYYYMMDD_HHMMSS.log`

This includes:

- timestamps
- log level (`INFO`, `SUCCESS`, `WARNING`, `ERROR`)
- operation details

`register_domain.sh` is more direct and prints to terminal instead of using the shared logger.

### 3.2 Privilege model

All scripts require root privileges. Run using `sudo`.

### 3.3 Menu flow (`installer.sh`)

Menu options:

1. Install Zabbix Agent
2. Configure Hostname
3. Install Wazuh Agent
4. Install Sophos
5. Register in Domain
6. Full mode (hostname -> zabbix -> wazuh -> sophos optional -> domain optional)
7. Edit settings file
8. View generated logs
0. Exit

## 4. Script Behavior Details

### 4.1 `install_zabbix.sh`

- Loads defaults from `config/settings.conf`
- Detects distro and picks installation path:
  - Ubuntu: `zabbix-release` DEB repo flow
  - Debian: `zabbix-release` DEB repo flow
  - RHEL/CentOS/Rocky/AlmaLinux: RPM repo flow
- Generates `/etc/zabbix/zabbix_agentd.conf`
- Opens agent port in firewall when firewalld or UFW is active
- Restarts and enables `zabbix-agent`
- Optional first argument overrides `ZABBIX_PROXY_SERVER`

### 4.2 `install_wazuh.sh`

- Loads defaults from `config/settings.conf`
- Detects distro and installs package:
  - Ubuntu/Debian: `.deb`
  - RHEL/CentOS/Rocky/AlmaLinux: `.rpm`
- Uses `WAZUH_MANAGER` at install time
- Enables and starts `wazuh-agent`
- Validates service and binary presence
- Optional first argument overrides `WAZUH_MANAGER`

### 4.3 `hostname.sh`

- Prompts for new hostname
- Validates format
- Calls `hostnamectl set-hostname`
- Updates `127.0.1.1` line in `/etc/hosts` when present
- Creates backup before editing `/etc/hosts`

### 4.4 `register_domain.sh`

- Interactive domain join and access configuration
- Installs required packages with `apt-get`/`dpkg` checks
- Configures `/etc/krb5.conf`
- Joins domain using `realm join`
- Updates `/etc/sssd/sssd.conf`
- Supports permissive or restricted access mode
- Creates sudo rule for selected domain group
- Enables/restarts SSSD and SSH services

Important current limitation:

- This script currently assumes Debian/Ubuntu package tooling (`apt-get`, `dpkg`).

### 4.5 `SophosSetup.sh`

- Vendor script for Sophos installation.
- Keep vendor-provided content unchanged unless required by Sophos documentation.

## 5. Configuration Reference (`config/settings.conf`)

| Variable | Purpose | Default |
| --- | --- | --- |
| `ZABBIX_PROXY_SERVER` | Zabbix server/proxy endpoint | `10.130.3.201` |
| `ZABBIX_SERVER_PORT` | Active server port | `10051` |
| `ZABBIX_AGENT_PORT` | Agent listening port | `10050` |
| `ZABBIX_DEBUG_LEVEL` | Agent debug level | `3` |
| `ZABBIX_LOG_SIZE` | Max log size MB | `10` |
| `ZABBIX_VERSION_UBUNTU` | Zabbix repo version for Ubuntu | `7.0` |
| `ZABBIX_VERSION_DEBIAN` | Zabbix repo version for Debian | `6.0` |
| `ZABBIX_VERSION_RHEL` | Zabbix repo version for RHEL-like distros | `6.4` |
| `WAZUH_MANAGER` | Wazuh manager endpoint | `wazuh.vantix.com.br` |
| `WAZUH_VERSION` | Wazuh agent version | `4.14.0` |
| `WAZUH_REVISION` | Wazuh package revision | `1` |
| `DEFAULT_DOMAIN` | Optional default domain | empty |
| `DEFAULT_ADMIN_GROUP` | Optional default admin group | empty |
| `DEFAULT_ADMIN_USER` | Optional default domain admin user | empty |
| `DOMAIN_COMPUTER_NAME` | Optional NetBIOS machine name | empty |
| `LOG_DIR` | Log directory (not currently consumed by all scripts) | `./logs` |
| `AUTO_BACKUP` | Enable backups for config changes | `true` |
| `NETWORK_TIMEOUT` | Network operation timeout seconds | `30` |
| `CHECK_INTERNET` | Validate internet before install | `true` |
| `EXECUTION_MODE` | Execution style hint | `interactive` |
| `CONTINUE_ON_WARNING` | Continue on warnings | `true` |
| `VERBOSE_MODE` | Verbose command output | `false` |

## 6. Compatibility Summary

### Implemented support by script

- `install_zabbix.sh`: Ubuntu, Debian, RHEL, CentOS, Rocky, AlmaLinux
- `install_wazuh.sh`: Ubuntu, Debian, RHEL, CentOS, Rocky, AlmaLinux
- `register_domain.sh`: Debian/Ubuntu oriented implementation
- `hostname.sh`: generic systemd-based Linux environments

## 7. Operational Runbook

### 7.1 First-time setup

```bash
chmod +x *.sh lib/common.sh
sudo ./installer.sh
```

### 7.2 Direct script usage

```bash
sudo ./install_zabbix.sh [ZABBIX_SERVER]
sudo ./install_wazuh.sh [WAZUH_MANAGER]
sudo ./hostname.sh
sudo ./register_domain.sh
sudo ./SophosSetup.sh
```

### 7.3 Basic validation commands

```bash
systemctl status zabbix-agent
systemctl status wazuh-agent
realm list
```

## 8. Troubleshooting

- Permission errors: run with `sudo`
- Missing library error: verify `lib/common.sh` exists and is readable
- Network failures: verify connectivity and repository reachability
- Domain join failures: validate DNS, credentials, and AD reachability
- Service not active: inspect logs and run `systemctl status <service>`

For script-based logs:

```bash
ls -lh logs/
tail -f logs/installer_*.log
```

## 9. Maintenance Notes

- Keep `settings.conf` aligned with infrastructure endpoints
- Validate package versions periodically (`ZABBIX_VERSION_*`, `WAZUH_VERSION`)
- Review documentation links whenever files are added/removed
- If domain support is needed on RPM-based distros, extend `register_domain.sh` with package-manager abstraction
