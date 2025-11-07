# 🔄 Guia de Migração v1.0 → v2.0

Este guia ajuda na transição dos scripts antigos para a nova versão refatorada.

## 📋 Resumo das Mudanças

### Scripts Antigos → Novos

| Script Antigo | Script Novo | Status |
|--------------|-------------|--------|
| `instalador_linux.sh` | `installer.sh` | ✅ Substituído |
| `menu_instalador.sh` | `installer.sh` | ✅ Substituído |
| `instalacao-zabbix2.sh` | `install_zabbix.sh` | ✅ Unificado |
| `install_zabbix_rocky.sh` | `install_zabbix.sh` | ✅ Unificado |
| `install_zabbix_ubuntu.sh` | `install_zabbix.sh` | ✅ Unificado |
| `registrar_no_dominio.sh` | `register_domain.sh` | ✅ Unificado |
| `registrar_no_dominio_ubuntu.sh` | `register_domain.sh` | ✅ Unificado |
| `hostname.sh` | `hostname.sh` | ✅ Melhorado |
| `KASPERSKY.sh` | `KASPERSKY.sh` | ✅ Melhorado |

## 🚀 Como Migrar

### Opção 1: Usar Menu Novo (Recomendado)

```bash
# Simplesmente use o novo menu
sudo ./installer.sh
```

O novo menu detecta automaticamente sua distribuição e executa o script apropriado.

### Opção 2: Usar Scripts Individuais

Se você estava usando scripts individuais, a migração é simples:

#### Instalação do Zabbix

**Antes (específico por distro):**
```bash
# Ubuntu
sudo ./install_zabbix_ubuntu.sh

# Rocky Linux
sudo ./install_zabbix_rocky.sh

# RHEL/CentOS 7
sudo ./instalacao-zabbix2.sh
```

**Agora (único script):**
```bash
# Funciona em todas as distribuições
sudo ./install_zabbix.sh
```

#### Registro no Domínio

**Antes:**
```bash
# Ubuntu
sudo ./registrar_no_dominio_ubuntu.sh

# RHEL/Rocky
sudo ./registrar_no_dominio.sh
```

**Agora:**
```bash
# Funciona em todas as distribuições
sudo ./register_domain.sh
```

### Opção 3: Scripts Legados

Se você preferir continuar usando os scripts antigos, eles ainda estão disponíveis no repositório.

## ⚙️ Configurações

### Antes (hardcoded nos scripts)

As configurações estavam fixas em cada script. Para mudar, era necessário editar cada arquivo.

### Agora (centralizado)

Todas as configurações estão em um único arquivo:

```bash
# Editar configurações
nano config/settings.conf

# Ou pelo menu
sudo ./installer.sh
# Opção: 6) Configurações
```

### Principais Configurações

```bash
# Zabbix
ZABBIX_PROXY_SERVER="10.130.3.201"

# Kaspersky
KASPERSKY_FILE_SERVER="10.130.2.10"
KASPERSKY_SHARE_NAME="KASPERSKY-STAND-ALONE-INSTALL"

# Domínio
DEFAULT_DOMAIN=""
DEFAULT_ADMIN_GROUP=""
```

## 🎯 Vantagens da Nova Versão

### 1. Simplicidade
- Um único script Zabbix para todas as distribuições
- Menu unificado mais intuitivo
- Configuração centralizada

### 2. Robustez
- Validações de entrada
- Tratamento de erros
- Sistema de logging
- Backups automáticos

### 3. Usabilidade
- Interface colorida
- Mensagens claras
- Confirmações de segurança
- Visualizador de logs integrado

### 4. Manutenibilidade
- Código modular
- Funções reutilizáveis
- Documentação completa
- Fácil adicionar novos scripts

## 🔧 Compatibilidade

### Sistemas Suportados

A versão 2.0 suporta as mesmas distribuições da v1.0, mas com detecção automática:

- ✅ Ubuntu 20.04, 22.04, 24.04
- ✅ Debian 11+
- ✅ Rocky Linux 8, 9
- ✅ RHEL 7, 8, 9
- ✅ CentOS 7, 8
- ✅ AlmaLinux 8, 9

### Funcionalidades

Todas as funcionalidades da v1.0 estão presentes na v2.0, com melhorias:

| Funcionalidade | v1.0 | v2.0 |
|---------------|------|------|
| Instalar Zabbix | ✅ | ✅ Melhorado |
| Hostname | ✅ | ✅ Melhorado |
| Kaspersky | ✅ | ✅ Melhorado |
| Domínio | ✅ | ✅ Melhorado |
| Menu | ✅ Básico | ✅ Avançado |
| Logs | ❌ | ✅ Novo |
| Validações | ⚠️ Parcial | ✅ Completo |
| Backups | ⚠️ Parcial | ✅ Automático |

## 📝 Exemplos de Migração

### Exemplo 1: Instalação do Zabbix no Ubuntu

**Versão 1.0:**
```bash
cd /caminho/scripts
sudo ./install_zabbix_ubuntu.sh
# Editar IP do servidor manualmente no script
```

**Versão 2.0:**
```bash
cd /caminho/scripts
# Editar config uma vez
nano config/settings.conf
# ZABBIX_PROXY_SERVER="seu_ip"

# Executar (funciona em qualquer distro)
sudo ./install_zabbix.sh

# Ou via menu
sudo ./installer.sh
# Escolher opção 1
```

### Exemplo 2: Registro no Domínio

**Versão 1.0:**
```bash
# Escolher script manualmente baseado na distro
sudo ./registrar_no_dominio_ubuntu.sh  # ou registrar_no_dominio.sh
```

**Versão 2.0:**
```bash
# Um script para todas as distros
sudo ./register_domain.sh

# Com valores padrão em config/settings.conf
DEFAULT_DOMAIN="empresa.com"
DEFAULT_ADMIN_GROUP="admins-linux"
```

## 🔍 Verificação Pós-Migração

Após migrar, verifique se tudo está funcionando:

```bash
# 1. Verificar estrutura
ls -la lib/ config/ logs/

# 2. Testar menu
sudo ./installer.sh

# 3. Ver logs
ls -la logs/

# 4. Verificar configurações
cat config/settings.conf
```

## ❓ FAQ

### Os scripts antigos ainda funcionam?

Sim, os scripts antigos ainda estão no repositório e funcionam. Porém, recomendamos migrar para os novos.

### Preciso reconfigurar tudo?

Não. As configurações padrão já funcionam. Você só precisa editar `config/settings.conf` se quiser personalizar.

### Posso usar scripts individuais sem o menu?

Sim! Cada script pode ser executado independentemente, como antes.

### O que acontece se eu atualizar o repositório?

Os scripts antigos serão mantidos para compatibilidade. Você pode escolher qual versão usar.

### Como voltar para a versão antiga?

Basta usar os scripts antigos que ainda estão no repositório:
- `instalador_linux.sh` ou `menu_instalador.sh`
- Scripts específicos por distribuição

## 🆘 Suporte

Se encontrar problemas durante a migração:

1. Verifique os logs em `logs/`
2. Consulte o README.md
3. Abra uma issue no GitHub
4. Use os scripts legados temporariamente

## 📌 Recomendações

1. ✅ **Teste primeiro**: Teste os novos scripts em ambiente de desenvolvimento
2. ✅ **Configure uma vez**: Edite `config/settings.conf` com suas configurações
3. ✅ **Use o menu**: É a forma mais simples e segura
4. ✅ **Verifique logs**: Sistema de logging ajuda a debugar problemas
5. ✅ **Backups**: A v2.0 faz backup automático, mas faça backups manuais também

---

**Dúvidas?** Consulte o [README.md](README.md) ou abra uma issue no GitHub.

