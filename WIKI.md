## Shell Install Applications Script — Wiki

Esta wiki reúne a documentação completa do projeto, condensando as informações que estavam anteriormente no `README.md`.

### Sumário

1. [Visão Geral](#visão-geral)
2. [Pré-requisitos](#pré-requisitos)
3. [Estrutura do Projeto](#estrutura-do-projeto)
4. [Menu Principal](#menu-principal)
5. [Scripts Individuais](#scripts-individuais)
6. [Configuração](#configuração)
7. [Sistema de Logs](#sistema-de-logs)
8. [Solução de Problemas](#solução-de-problemas)
9. [Compatibilidade](#compatibilidade)
10. [Segurança](#segurança)
11. [Suporte e Contribuição](#suporte-e-contribuição)

---

### Visão Geral

Coleção profissional de scripts em Bash para automatizar a instalação e configuração de serviços em sistemas Linux. O repositório oferece um menu interativo com interface colorida, além de scripts individuais executáveis separadamente.

**Principais características**

- Interface moderna com menu colorido
- Detecção automática de distribuição Linux
- Sistema de logging completo
- Validações robustas e tratamento de erros
- Configuração centralizada
- Backup automático de arquivos críticos
- Suporte multi-distribuição (Ubuntu, Debian, RHEL, Rocky, CentOS, AlmaLinux)
- Scripts modulares executáveis pelo menu ou individualmente

---

### Pré-requisitos

- **Sistema Operacional:** Ubuntu 20.04+, Debian 11/12, RHEL 7-9, Rocky 8-9, CentOS 7-8, AlmaLinux 8-9
- **Shell:** Bash 4.0+
- **Privilégios:** Root ou sudo
- **Rede:** Acesso à internet para download de pacotes
- **Espaço em disco:** Mínimo de 500 MB livres

---

### Estrutura do Projeto

```
shell-install-applications-script/
├── installer.sh                    # Menu principal (RECOMENDADO)
├── install_zabbix.sh               # Instalação do Zabbix (unificado)
├── install_wazuh.sh                # Instalação do Wazuh (novo)
├── register_domain.sh              # Registro no domínio (unificado)
├── hostname.sh                     # Configuração de hostname
├── SophosSetup.sh                  # Instalador oficial da Sophos
├── lib/
│   └── common.sh                   # Biblioteca de funções compartilhadas
├── config/
│   └── settings.conf               # Arquivo de configuração
├── logs/                           # Diretório de logs (gerado automaticamente)
└── docs legados                    # Scripts antigos mantidos para compatibilidade
```

---

### Menu Principal

O `installer.sh` apresenta um menu interativo com as seguintes opções:

```
╔═══════════════════════════════════════════════════════╗
║              MENU PRINCIPAL                           ║
╚═══════════════════════════════════════════════════════╝

  1) Instalar Zabbix Agent
  2) Configurar Hostname
  3) Instalar Wazuh Agent
  4) Instalar Sophos
  5) Registrar no Domínio
  6) Executar Tudo (Modo Completo)
  7) Configurações
  8) Ver Logs
  0) Sair
```

- **Modo Completo** executa a sequência: hostname → Zabbix → Wazuh → Sophos (opcional) → registro no domínio (opcional).

---

### Scripts Individuais

Todos os scripts podem ser executados diretamente:

```bash
sudo ./installer.sh          # Menu principal
sudo ./install_zabbix.sh     # Instalação Zabbix
sudo ./install_wazuh.sh      # Instalação Wazuh
sudo ./hostname.sh           # Configuração de hostname
sudo ./SophosSetup.sh        # Instalação Sophos
sudo ./register_domain.sh    # Registro no domínio
```

#### 1. `install_zabbix.sh`

- Detecta automaticamente Ubuntu/Debian/RHEL/Rocky/CentOS
- Configura repositórios, firewall e serviço
- Aceita servidor customizado via argumento CLI

Configurações relevantes em `config/settings.conf`:

```bash
ZABBIX_PROXY_SERVER="10.130.3.201"
ZABBIX_SERVER_PORT="10051"
ZABBIX_AGENT_PORT="10050"
ZABBIX_DEBUG_LEVEL="3"
```

#### 2. `hostname.sh`

- Valida hostname conforme RFC 952/1123
- Confirmação interativa e backup automático
- Atualiza `/etc/hosts`

#### 3. `install_wazuh.sh`

- Detecta distro e instala pacote DEB/RPM adequado
- Configura `WAZUH_MANAGER`, habilita e verifica serviço

Configurações:

```bash
WAZUH_MANAGER="wazuh.vantix.com.br"
WAZUH_VERSION="4.14.0"
WAZUH_REVISION="1"
```

#### 4. `SophosSetup.sh`

- Script oficial fornecido pela Sophos (thin installer)
- Verifica dependências, espaço em disco e conexão com Sophos Central
- Permite passar argumentos como `--group`, `--device-type`, `--mr-use-creds`
- Gera logs completos em `/opt/sophos-spl/logs`

> Dica: configure variáveis como `SOPHOS_INSTALL`, `SOPHOS_CREDENTIALS` ou grupos diretamente via argumentos ao executar o script.

#### 5. `register_domain.sh`

- Integra com domínio Active Directory via SSSD/Realmd
- Configura pacotes, SSSD, PAM e permissões sudo
- Suporte a `DOMAIN_COMPUTER_NAME` (máx 15 caracteres) e detecção automática de hostname compatível

---

### Configuração

Use `config/settings.conf` para personalizar o comportamento:

| Variável | Descrição | Padrão |
| --- | --- | --- |
| `ZABBIX_PROXY_SERVER` | IP do servidor Zabbix | `10.130.3.201` |
| `WAZUH_MANAGER` | Endereço do Wazuh Manager | `wazuh.vantix.com.br` |
| `WAZUH_VERSION` | Versão do Wazuh Agent | `4.14.0` |
| `DEFAULT_DOMAIN` | Domínio padrão | vazio |
| `DOMAIN_COMPUTER_NAME` | Nome NetBIOS (15 chars) | vazio |
| `AUTO_BACKUP` | Backup automático | `true` |
| `CHECK_INTERNET` | Verifica conectividade | `true` |
| `VERBOSE_MODE` | Logs detalhados | `false` |

> Para editar: `nano config/settings.conf` ou opção **Configurações** no menu.
> O instalador `SophosSetup.sh` não usa variáveis dedicadas; personalize passando argumentos diretamente ao script conforme a documentação oficial.

---

### Sistema de Logs

- Todos os scripts registram logs em `logs/`
- Timestamps, status e mensagens (INFO/WARN/ERROR)
- Acesso rápido:

```bash
tail -f logs/installer_YYYYMMDD_HHMMSS.log
grep "ERROR" logs/*.log
```

Menu → **Ver Logs** também lista arquivos gerados.

---

### Solução de Problemas

- **Erro de permissão:** executar com `sudo` ou como root
- **Repositório ausente:** `sudo apt update` ou `sudo dnf update`
- **Script não executável:** `chmod +x *.sh lib/common.sh`
- **Biblioteca comum não encontrada:** confirmar `lib/common.sh`
- **Hostname longo para AD:** definir `DOMAIN_COMPUTER_NAME`

Logs detalhados ajudam a identificar falhas; use `VERBOSE_MODE="true"` para depuração avançada.

---

### Compatibilidade

| Distribuição | Versão | Status | Zabbix |
| --- | --- | --- | --- |
| Ubuntu | 20.04+ | ✅ Testado | 7.0 |
| Ubuntu | 24.04 | ✅ Testado | 7.0 |
| Debian | 11 | ✅ Suportado | 6.0 |
| Debian | 12 | ✅ Suportado | 6.0 |
| Rocky Linux | 8, 9 | ✅ Testado | 6.4 |
| RHEL | 7, 8, 9 | ✅ Suportado | 6.4 |
| CentOS | 7, 8 | ✅ Suportado | 6.4 |
| AlmaLinux | 8, 9 | ✅ Suportado | 6.4 |

---

### Segurança

- Senhas não são armazenadas em logs
- Backup automático antes de alterações
- Validação de inputs
- Verificação de privilégios
- Execute apenas a partir de fontes confiáveis

---

### Suporte e Contribuição

1. Verifique os logs em `logs/`
2. Consulte esta wiki e `SUMMARY.md`, `QUICKSTART.md`, `WAZUH_IMPLEMENTATION.md` para guias específicos
3. Abra uma issue com distribuição, comando executado e logs relevantes

**Fluxo para contribuir**

1. Fork do repositório
2. `git checkout -b feature/sua-feature`
3. `git commit -m "feat: descreva sua alteração"`
4. `git push origin feature/sua-feature`
5. Abra um Pull Request

---

**Links úteis**

- [Documentação do Zabbix](https://www.zabbix.com/documentation)
- [Documentação do SSSD](https://sssd.io/)
- [Guia do Bash](https://www.gnu.org/software/bash/manual/)


