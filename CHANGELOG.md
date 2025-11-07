# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

## [2.1.0] - 2025-11-07

### ✨ Novo

- **Suporte ao Wazuh Agent**: 
  - Novo script `install_wazuh.sh` para instalação automática do Wazuh Agent
  - Detecção automática de distribuição (Ubuntu/Debian com DEB, RHEL/Rocky/CentOS com RPM)
  - Configuração automática do Wazuh Manager durante instalação
  - Habilitação e inicialização automática do serviço
  - Verificação de status pós-instalação
  - Versão padrão: 4.14.0-1
  - Manager padrão: wazuh.vantix.com.br

### ⚙️ Configuração

- Adicionadas configurações do Wazuh ao `config/settings.conf`:
  - `WAZUH_MANAGER` - Endereço do Wazuh Manager
  - `WAZUH_VERSION` - Versão do Wazuh Agent
  - `WAZUH_REVISION` - Revisão do pacote

### 🎨 Interface

- Menu principal atualizado com opção "3) Instalar Wazuh Agent"
- Renumeração das opções existentes do menu
- Modo completo agora inclui instalação do Wazuh (passo 3/5)

### 📚 Documentação

- README atualizado com seção completa sobre o Wazuh
- EXAMPLES.md atualizado com exemplos de uso do Wazuh
- Estrutura do projeto atualizada
- Tabela de configurações expandida

### 🔧 Funcionalidades do Script Wazuh

- Download automático do pacote apropriado (.deb ou .rpm)
- Instalação com variável de ambiente `WAZUH_MANAGER` configurada
- Comandos pós-instalação:
  - `systemctl daemon-reload`
  - `systemctl enable wazuh-agent`
  - `systemctl start wazuh-agent`
- Verificação completa da instalação
- Informações detalhadas sobre configuração e logs
- Integração completa com biblioteca comum (logging, cores, validações)

---

## [2.0.1] - 2025-11-07

### 🐛 Correções

- **Caminho de logs corrigido**: Sistema de logging agora usa caminho relativo correto (`./logs/`)
- Eliminado erro "No such file or directory" ao inicializar logging

### ✨ Novo

- **Suporte completo ao Debian 11/12**: 
  - Função `install_zabbix_repo_debian()` para instalação do repositório
  - Função `install_zabbix_debian()` para instalação completa
  - Detecção automática de versão do Debian
  - Seguindo [documentação oficial do Zabbix](https://www.zabbix.com/download?zabbix=6.0&os_distribution=debian&os_version=12&components=agent)
- Configuração `ZABBIX_VERSION_DEBIAN="6.0"` adicionada ao settings.conf

### 📝 Documentação

- README atualizado com informações do Debian
- Tabela de compatibilidade expandida

---

## [2.0.0] - 2025-11-07

### 🎉 Novo - Refatoração Completa

#### Adicionado
- ✨ Menu interativo principal com interface colorida (`installer.sh`)
- 📚 Biblioteca de funções comuns (`lib/common.sh`)
- ⚙️ Sistema de configuração centralizado (`config/settings.conf`)
- 📝 Sistema de logging completo e estruturado
- 🔍 Detecção automática de distribuição Linux
- 🛡️ Validações robustas de entrada do usuário
- 🔄 Sistema de backup automático de arquivos de configuração
- 🎨 Interface colorida com símbolos Unicode
- 📊 Visualizador de logs integrado no menu

#### Scripts Unificados
- `install_zabbix.sh` - Detecta automaticamente Ubuntu/Debian/RHEL/Rocky
- `register_domain.sh` - Integração ao domínio com melhorias
- `hostname.sh` - Configuração de hostname com validações
- `KASPERSKY.sh` - Instalação do Kaspersky melhorada

#### Melhorias
- ✅ Tratamento de erros aprimorado
- ✅ Mensagens de sucesso/erro mais claras
- ✅ Confirmações antes de operações críticas
- ✅ Suporte a execução via menu ou scripts individuais
- ✅ Documentação completa e detalhada
- ✅ Estrutura modular e reutilizável

#### Funcionalidades da Biblioteca Comum
- Funções de output colorido
- Sistema de logging automático
- Detecção de distribuição
- Gerenciamento de pacotes multi-distro
- Validações de entrada
- Gerenciamento de serviços
- Funções de backup
- Funções de rede

### Compatibilidade
- Ubuntu 20.04, 22.04, 24.04
- Debian 11+
- Rocky Linux 8, 9
- RHEL 7, 8, 9
- CentOS 7, 8
- AlmaLinux 8, 9

---

## [1.0.0] - Anterior

### Scripts Originais
- `instalador_linux.sh` - Menu básico
- `menu_instalador.sh` - Menu alternativo
- `instalacao-zabbix2.sh` - Zabbix RHEL/CentOS 7
- `install_zabbix_rocky.sh` - Zabbix Rocky Linux
- `install_zabbix_ubuntu.sh` - Zabbix Ubuntu
- `registrar_no_dominio.sh` - Domínio RHEL/CentOS
- `registrar_no_dominio_ubuntu.sh` - Domínio Ubuntu
- `hostname.sh` - Hostname básico
- `KASPERSKY.sh` - Kaspersky básico

### Características
- Scripts funcionais independentes
- Suporte básico para diferentes distribuições
- Configurações hardcoded

---

**Legenda:**
- ✨ Novo recurso
- 🐛 Correção de bug
- 📚 Documentação
- ⚙️ Configuração
- 🔧 Manutenção
- ⚠️ Obsoleto

