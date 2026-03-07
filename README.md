# Shell Install Applications Script

Colecao de scripts Bash para preparar servidores Linux com:

- configuracao de hostname
- instalacao de Zabbix Agent
- instalacao de Wazuh Agent
- instalacao do Sophos (script oficial `SophosSetup.sh`)
- registro no dominio via Realmd/SSSD

O projeto pode ser executado por menu interativo (`installer.sh`) ou por scripts individuais.

## Principais recursos

- Menu interativo com deteccao automatica de distribuicao
- Biblioteca compartilhada com funcoes de validacao, log e operacoes comuns (`lib/common.sh`)
- Configuracao centralizada em `config/settings.conf`
- Logs por execucao em `logs/installer_YYYYMMDD_HHMMSS.log`
- Suporte para Ubuntu, Debian, RHEL, Rocky, CentOS e AlmaLinux (conforme script)

## Estrutura atual do repositorio

```text
.
├── installer.sh
├── install_zabbix.sh
├── install_wazuh.sh
├── register_domain.sh
├── hostname.sh
├── SophosSetup.sh
├── lib/
│   └── common.sh
├── config/
│   └── settings.conf
├── README.md
├── PROJECT_DOCUMENTATION.md
├── QUICKSTART.md
├── QUICKSTART_WAZUH.md
├── WAZUH_IMPLEMENTATION.md
├── DEBIAN_GUIDE.md
├── EXAMPLES.md
└── WIKI.md
```

## Pre-requisitos

- Linux com systemd
- Bash 4+
- Acesso root (ou `sudo`)
- Conectividade de rede para baixar pacotes

## Uso rapido

No diretorio do projeto:

```bash
chmod +x *.sh lib/common.sh
sudo ./installer.sh
```

### Menu principal (`installer.sh`)

Opcoes disponiveis:

1. Instalar Zabbix Agent
2. Configurar Hostname
3. Instalar Wazuh Agent
4. Instalar Sophos
5. Registrar no Dominio
6. Executar Tudo (Modo Completo)
7. Configuracoes
8. Ver Logs
0. Sair

## Execucao por script individual

```bash
sudo ./install_zabbix.sh [IP_OU_HOST_ZABBIX]
sudo ./install_wazuh.sh [WAZUH_MANAGER]
sudo ./hostname.sh
sudo ./register_domain.sh
sudo ./SophosSetup.sh
```

## Configuracao

Edite `config/settings.conf` para ajustar parametros como:

- `ZABBIX_PROXY_SERVER`
- `ZABBIX_SERVER_PORT`
- `ZABBIX_AGENT_PORT`
- `WAZUH_MANAGER`
- `WAZUH_VERSION`
- `DEFAULT_DOMAIN`
- `DEFAULT_ADMIN_GROUP`
- `CHECK_INTERNET`

## Logs

Todos os scripts geram logs em `logs/`:

```bash
ls -lh logs/
```

Para acompanhar a ultima execucao:

```bash
tail -f logs/installer_*.log
```

## Validacao basica pos-instalacao

```bash
systemctl status zabbix-agent
systemctl status wazuh-agent
realm list
```

## Documentacao

- [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md) - documentacao tecnica consolidada do projeto
- [WIKI.md](WIKI.md) - guia geral em formato wiki
- [QUICKSTART.md](QUICKSTART.md) - inicio rapido
- [QUICKSTART_WAZUH.md](QUICKSTART_WAZUH.md) - guia rapido de Wazuh
- [WAZUH_IMPLEMENTATION.md](WAZUH_IMPLEMENTATION.md) - detalhes de implementacao Wazuh
- [DEBIAN_GUIDE.md](DEBIAN_GUIDE.md) - orientacoes para Debian
- [EXAMPLES.md](EXAMPLES.md) - exemplos praticos de uso
