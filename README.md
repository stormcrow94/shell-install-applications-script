# 🚀 Shell Install Applications Script

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/platform-linux-lightgrey.svg)](https://www.linux.org/)

Coleção de scripts em Bash para instalar hostname, Zabbix, Wazuh, Sophos e registrar máquinas em domínio usando um menu único ou executando cada script isoladamente.

## ✨ Destaques

- Menu interativo com detecção da distribuição
- Scripts independentes com validações, logs e backups automáticos
- Configurações centralizadas em `config/settings.conf`
- Suporte a Ubuntu, Debian, RHEL, Rocky, CentOS e AlmaLinux

## 🚀 Uso Rápido

```bash
git clone https://github.com/seu-usuario/shell-install-applications-script.git
cd shell-install-applications-script
chmod +x installer.sh
sudo ./installer.sh
```

## 🔧 Scripts Disponíveis

- installer.sh — menu principal e modo completo
- install_zabbix.sh
- install_wazuh.sh
- register_domain.sh
- hostname.sh
- SophosSetup.sh

Execute qualquer script individualmente com `sudo ./script.sh`.

## 📚 Documentação

A documentação completa está na [Wiki do projeto](WIKI.md) e nos arquivos `SUMMARY.md`, `QUICKSTART*.md`, `WAZUH_IMPLEMENTATION.md`, `DEBIAN_GUIDE.md` e `config/`.

Criado por stormcrow94
