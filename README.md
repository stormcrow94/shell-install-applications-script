# 🚀 Shell Install Applications Script

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/platform-linux-lightgrey.svg)](https://www.linux.org/)

Coleção profissional de scripts em Bash para automatizar a instalação e configuração de serviços em sistemas Linux. O repositório oferece um menu interativo intuitivo com interface colorida, além de scripts individuais que podem ser executados separadamente.

## ✨ Características

- 🎨 **Interface moderna** com menu interativo colorido
- 🔍 **Detecção automática** de distribuição Linux
- 📝 **Sistema de logging** completo para todas as operações
- 🛡️ **Validações robustas** e tratamento de erros
- ⚙️ **Configuração centralizada** em arquivo separado
- 🔄 **Backup automático** de arquivos de configuração
- 📦 **Suporte multi-distribuição** (Ubuntu, Debian, RHEL, Rocky, CentOS, AlmaLinux)
- 🎯 **Scripts modulares** que funcionam individualmente ou via menu

## 📋 Pré-requisitos

- **Sistema Operacional**: Linux (Ubuntu 20.04+, Debian 11/12, RHEL 7-9, Rocky 8-9, CentOS 7-8, AlmaLinux 8-9)
- **Shell**: Bash 4.0 ou superior
- **Privilégios**: Root ou sudo
- **Rede**: Conexão com internet para download de pacotes
- **Espaço em disco**: Mínimo 500MB disponível

## 🗂️ Estrutura do Projeto

```
shell-install-applications-script/
├── installer.sh                    # Menu principal (RECOMENDADO)
├── install_zabbix.sh               # Instalação do Zabbix (unificado)
├── install_wazuh.sh                # Instalação do Wazuh (novo)
├── register_domain.sh              # Registro no domínio (unificado)
├── hostname.sh                     # Configuração de hostname
├── KASPERSKY.sh                    # Instalação do Kaspersky
├── lib/
│   └── common.sh                   # Biblioteca de funções compartilhadas
├── config/
│   └── settings.conf               # Arquivo de configuração
├── logs/                           # Diretório de logs (gerado automaticamente)
├── README.md                       # Este arquivo
└── [scripts legados]               # Scripts antigos mantidos para compatibilidade
```

## 🚀 Início Rápido

### Opção 1: Menu Interativo (Recomendado)

```bash
# 1. Clonar o repositório
git clone https://github.com/seu-usuario/shell-install-applications-script.git
cd shell-install-applications-script

# 2. Tornar o instalador executável
chmod +x installer.sh

# 3. Executar o menu principal
sudo ./installer.sh
```

### Opção 2: Scripts Individuais

Cada script pode ser executado independentemente:

```bash
# Instalar Zabbix Agent
sudo ./install_zabbix.sh

# Instalar Wazuh Agent
sudo ./install_wazuh.sh

# Configurar hostname
sudo ./hostname.sh

# Instalar Kaspersky
sudo ./KASPERSKY.sh

# Registrar no domínio
sudo ./register_domain.sh
```

## 📚 Guia de Uso Detalhado

### Menu Principal

O menu principal (`installer.sh`) oferece as seguintes opções:

```
╔═══════════════════════════════════════════════════════╗
║              MENU PRINCIPAL                           ║
╚═══════════════════════════════════════════════════════╝

  1) Instalar Zabbix Agent
     Instala e configura o agente Zabbix

  2) Configurar Hostname
     Altera o nome do host do sistema

  3) Instalar Wazuh Agent
     Instala e configura o agente Wazuh

  4) Instalar Kaspersky
     Instala Kaspersky Endpoint Security

  5) Registrar no Domínio
     Integra o sistema ao domínio via SSSD/Realmd

  6) Executar Tudo (Modo Completo)
     Executa todas as instalações sequencialmente

  7) Configurações
     Editar configurações do instalador

  8) Ver Logs
     Visualizar logs de instalação

  0) Sair
```

### 1. Instalação do Zabbix Agent

O script detecta automaticamente a distribuição e versão do sistema, instalando o repositório e agente apropriados.

**Características:**
- Detecção automática de Ubuntu/Debian/RHEL/Rocky/CentOS
- Instalação de repositório apropriado
- Configuração automática com hostname e IP
- Configuração de firewall (se necessário)
- Verificação de serviço

**Uso individual:**
```bash
sudo ./install_zabbix.sh

# Ou com servidor customizado:
sudo ./install_zabbix.sh 192.168.1.100
```

**Configurações editáveis** (em `config/settings.conf`):
```bash
ZABBIX_PROXY_SERVER="10.130.3.201"
ZABBIX_SERVER_PORT="10051"
ZABBIX_AGENT_PORT="10050"
ZABBIX_DEBUG_LEVEL="3"
```

### 2. Configuração de Hostname

Altera o hostname do sistema com validação de formato.

**Características:**
- Validação de formato RFC 952/1123
- Confirmação antes de aplicar
- Atualização automática de `/etc/hosts`
- Backup de configurações

**Uso individual:**
```bash
sudo ./hostname.sh
```

### 3. Instalação do Wazuh Agent

O script detecta automaticamente a distribuição e instala o agente Wazuh apropriado (RPM ou DEB).

**Características:**
- Detecção automática de Ubuntu/Debian (DEB) e RHEL/Rocky/CentOS (RPM)
- Download e instalação automática do agente
- Configuração do Wazuh Manager durante instalação
- Habilitação e inicialização automática do serviço
- Verificação de status pós-instalação

**Uso individual:**
```bash
sudo ./install_wazuh.sh

# Ou com manager customizado:
sudo ./install_wazuh.sh wazuh.seudominio.com.br
```

**Configurações editáveis** (em `config/settings.conf`):
```bash
WAZUH_MANAGER="wazuh.vantix.com.br"
WAZUH_VERSION="4.14.0"
WAZUH_REVISION="1"
```

**Verificar instalação:**
```bash
# Status do serviço
systemctl status wazuh-agent

# Logs do Wazuh
tail -f /var/ossec/logs/ossec.log
```

### 4. Instalação do Kaspersky

Monta um compartilhamento SMB e instala o Kaspersky Endpoint Security.

**Características:**
- Instalação automática de pacotes SMB
- Montagem segura de compartilhamento
- Instalação de KLNA (Network Agent) e KESL (Endpoint Security)
- Desmontagem automática ao finalizar

**Uso individual:**
```bash
sudo ./KASPERSKY.sh
```

**Configurações editáveis**:
```bash
KASPERSKY_FILE_SERVER="10.130.2.10"
KASPERSKY_SHARE_NAME="KASPERSKY-STAND-ALONE-INSTALL"
```

### 5. Registro no Domínio

Integra o sistema ao domínio Active Directory via SSSD/Realmd.

**Características:**
- Detecção automática de distribuição
- Instalação de pacotes necessários
- Configuração de SSSD e PAM
- Configuração de permissões sudo para grupo do domínio
- Criação automática de home directories

**Uso individual:**
```bash
sudo ./register_domain.sh
```

**Após o registro:**
```bash
# Verificar status
realm list

# Testar autenticação
id usuario@dominio.com

# Fazer login
ssh usuario@dominio.com@hostname
```

### 6. Modo Completo

Executa todas as instalações sequencialmente, ideal para configuração inicial de uma nova máquina.

**Ordem de execução:**
1. Configuração de hostname
2. Instalação do Zabbix Agent
3. Instalação do Wazuh Agent
4. Instalação do Kaspersky (opcional)
5. Registro no domínio (opcional)

## ⚙️ Configuração

Edite o arquivo `config/settings.conf` para personalizar as configurações:

```bash
# Editar configurações
nano config/settings.conf

# Ou via menu
sudo ./installer.sh
# Selecione: 7) Configurações
```

### Principais configurações:

| Configuração | Descrição | Padrão |
|-------------|-----------|--------|
| `ZABBIX_PROXY_SERVER` | IP do servidor Zabbix | 10.130.3.201 |
| `WAZUH_MANAGER` | Endereço do Wazuh Manager | wazuh.vantix.com.br |
| `WAZUH_VERSION` | Versão do Wazuh Agent | 4.14.0 |
| `KASPERSKY_FILE_SERVER` | IP do servidor SMB | 10.130.2.10 |
| `DEFAULT_DOMAIN` | Domínio padrão | (vazio) |
| `AUTO_BACKUP` | Backup automático | true |
| `CHECK_INTERNET` | Verificar conexão | true |

## 📊 Sistema de Logs

Todos os scripts geram logs detalhados em `logs/`:

```bash
# Visualizar logs pelo menu
sudo ./installer.sh
# Selecione: 7) Ver Logs

# Ou diretamente
ls -lh logs/
tail -f logs/installer_YYYYMMDD_HHMMSS.log
```

**Informações registradas:**
- ✅ Operações bem-sucedidas
- ❌ Erros e falhas
- ⚠️ Avisos
- ℹ️ Informações gerais
- 🕐 Timestamps de todas as operações

## 🔧 Solução de Problemas

### Problema: Erro de permissão

```bash
# Verifique se está executando como root
sudo su
./installer.sh
```

### Problema: Repositório não encontrado

```bash
# Atualize os repositórios do sistema
sudo apt update  # Ubuntu/Debian
sudo dnf update  # Rocky/RHEL
```

### Problema: Script não é executável

```bash
# Tornar todos os scripts executáveis
chmod +x *.sh
chmod +x lib/common.sh
```

### Problema: Biblioteca comum não encontrada

```bash
# Verifique a estrutura de diretórios
ls -la lib/common.sh

# Se necessário, recriar o link
cd /caminho/para/o/script
```

### Logs e Debug

```bash
# Ver log mais recente
tail -100 logs/installer_*.log | less

# Buscar erros nos logs
grep "ERROR" logs/*.log

# Modo verbose (edite settings.conf)
VERBOSE_MODE="true"
```

## 🆘 Suporte e Contribuição

### Reportar Problemas

Se encontrar algum problema:

1. Verifique os logs em `logs/`
2. Consulte a seção de Solução de Problemas
3. Abra uma issue no GitHub com:
   - Distribuição e versão do sistema
   - Comando executado
   - Mensagem de erro
   - Log relevante

### Contribuir

Contribuições são bem-vindas! Para contribuir:

1. Fork o repositório
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📝 Compatibilidade

| Distribuição | Versão | Status | Zabbix |
|-------------|--------|--------|--------|
| Ubuntu | 20.04+ | ✅ Testado | 7.0 |
| Ubuntu | 24.04 | ✅ Testado | 7.0 |
| Debian | 11 | ✅ Suportado | 6.0 |
| Debian | 12 | ✅ Suportado | 6.0 |
| Rocky Linux | 8, 9 | ✅ Testado | 6.4 |
| RHEL | 7, 8, 9 | ✅ Suportado | 6.4 |
| CentOS | 7, 8 | ✅ Suportado | 6.4 |
| AlmaLinux | 8, 9 | ✅ Suportado | 6.4 |

## 🔐 Segurança

- ✅ Senhas nunca são armazenadas em logs
- ✅ Backup automático antes de modificar configurações
- ✅ Validação de inputs do usuário
- ✅ Verificação de privilégios adequados
- ⚠️ Scripts devem ser executados apenas de fontes confiáveis

## 📜 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo LICENSE para detalhes.

## 👤 Autor

**Stormcrowm94**

## 🙏 Agradecimentos

- Comunidade open source
- Contribuidores do projeto
- Zabbix, Kaspersky e projetos relacionados

---

**Nota**: Sempre revise os scripts antes de executá-los em ambiente de produção. É recomendado testar em ambiente controlado primeiro.

## 📞 Links Úteis

- [Documentação do Zabbix](https://www.zabbix.com/documentation)
- [Documentação do SSSD](https://sssd.io/)
- [Guia do Bash](https://www.gnu.org/software/bash/manual/)

---

*Última atualização: Novembro 2025*
