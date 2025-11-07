# 📚 Exemplos de Uso

Este documento fornece exemplos práticos de como usar os scripts.

## 🎯 Casos de Uso Comuns

### 1. Configuração Inicial de Servidor

Setup completo de um novo servidor Linux:

```bash
# Executar instalação completa via menu
sudo ./installer.sh
# Selecionar: 5) Executar Tudo (Modo Completo)
```

Ou passo a passo:

```bash
# 1. Configurar hostname
sudo ./hostname.sh

# 2. Instalar Zabbix
sudo ./install_zabbix.sh

# 3. Instalar Wazuh
sudo ./install_wazuh.sh

# 4. Registrar no domínio
sudo ./register_domain.sh
```

### 2. Instalação Rápida do Zabbix

```bash
# Com servidor padrão (configurado em settings.conf)
sudo ./install_zabbix.sh

# Com servidor customizado
sudo ./install_zabbix.sh 192.168.1.100
```

### 2.1. Instalação Rápida do Wazuh

```bash
# Com manager padrão (configurado em settings.conf)
sudo ./install_wazuh.sh

# Com manager customizado
sudo ./install_wazuh.sh wazuh.seudominio.com.br

# Verificar status após instalação
systemctl status wazuh-agent

# Ver logs do Wazuh
tail -f /var/ossec/logs/ossec.log
```

### 3. Múltiplos Servidores

Script para instalar Zabbix em múltiplos servidores:

```bash
#!/bin/bash
# install_multiple.sh

SERVERS="server1 server2 server3"
ZABBIX_IP="10.130.3.201"

for server in $SERVERS; do
    echo "Configurando $server..."
    ssh root@$server "cd /opt/scripts && ./install_zabbix.sh $ZABBIX_IP"
    ssh root@$server "cd /opt/scripts && ./install_wazuh.sh wazuh.vantix.com.br"
done
```

### 4. Automação com Ansible

Exemplo de playbook Ansible:

```yaml
---
- name: Configurar servidores Linux
  hosts: linux_servers
  become: yes
  
  tasks:
    - name: Copiar scripts
      copy:
        src: /path/to/scripts/
        dest: /opt/scripts/
        mode: '0755'
    
    - name: Executar instalação do Zabbix
      command: /opt/scripts/install_zabbix.sh
      args:
        chdir: /opt/scripts
    
    - name: Executar instalação do Wazuh
      command: /opt/scripts/install_wazuh.sh
      args:
        chdir: /opt/scripts
```

### 5. Instalação Silenciosa

Pré-configurar e executar sem interação:

```bash
# 1. Editar config/settings.conf
cat > config/settings.conf << EOF
ZABBIX_PROXY_SERVER="10.130.3.201"
WAZUH_MANAGER="wazuh.vantix.com.br"
WAZUH_VERSION="4.14.0"
DEFAULT_DOMAIN="empresa.com"
DEFAULT_ADMIN_USER="admin"
DEFAULT_ADMIN_GROUP="linux-admins"
CHECK_INTERNET="true"
EOF

# 2. Executar scripts
sudo ./install_zabbix.sh
sudo ./install_wazuh.sh
```

## 🔧 Integrações

### Integração com Terraform

```hcl
resource "null_resource" "configure_server" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_rsa")
    host        = aws_instance.server.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "cd /tmp",
      "git clone https://github.com/seu-usuario/shell-install-applications-script.git",
      "cd shell-install-applications-script",
      "chmod +x *.sh",
      "./install_zabbix.sh ${var.zabbix_server}",
      "./install_wazuh.sh ${var.wazuh_manager}",
    ]
  }
}
```

### Integração com Docker

```dockerfile
FROM ubuntu:24.04

# Copiar scripts
COPY . /opt/scripts
WORKDIR /opt/scripts

# Instalar dependências
RUN apt-get update && \
    apt-get install -y sudo && \
    chmod +x *.sh

# Executar configuração
RUN ./install_zabbix.sh
```

### Integração com Kubernetes (Init Container)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-monitoring
spec:
  initContainers:
  - name: setup-monitoring
    image: ubuntu:24.04
    command:
    - /bin/bash
    - -c
    - |
      cd /scripts
      ./install_zabbix.sh
    volumeMounts:
    - name: scripts
      mountPath: /scripts
  volumes:
  - name: scripts
    configMap:
      name: install-scripts
```

## 🔄 Uso Programático

### Importar Biblioteca em Seus Scripts

```bash
#!/bin/bash

# Carregar biblioteca
source /opt/scripts/lib/common.sh

# Usar funções
init_logging
check_root

print_header "Meu Script Customizado"
print_info "Detectando sistema..."

detect_distro
print_success "Sistema: $DISTRO_NAME $DISTRO_VERSION"

# Instalar pacotes
install_packages "curl" "wget" "git"

# Gerenciar serviços
restart_service "nginx"
enable_service "nginx"

print_success "Configuração concluída!"
```

### Criar Script Personalizado

```bash
#!/bin/bash
# custom_install.sh

# Carregar biblioteca
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Configurar logging
init_logging

main() {
    print_header "Instalação Customizada"
    check_root
    
    # Sua lógica aqui
    detect_distro
    
    if [[ "$DISTRO" == "ubuntu" ]]; then
        install_package "nginx"
        install_package "postgresql"
    elif [[ "$DISTRO" == "rocky" ]]; then
        install_package "nginx"
        install_package "postgresql-server"
    fi
    
    print_success "Instalação concluída!"
}

main "$@"
```

## 📊 Monitoramento e Logs

### Analisar Logs

```bash
# Ver últimas instalações
ls -lt logs/ | head -5

# Buscar erros
grep -i error logs/*.log

# Buscar instalações do Zabbix
grep -i zabbix logs/*.log

# Buscar instalações do Wazuh
grep -i wazuh logs/*.log

# Verificar instalações bem-sucedidas
grep -i success logs/installer_*.log
```

### Script de Monitoramento

```bash
#!/bin/bash
# monitor_installations.sh

LOG_DIR="/opt/scripts/logs"

echo "=== Resumo de Instalações ==="
echo ""

echo "Total de logs: $(ls -1 $LOG_DIR/*.log 2>/dev/null | wc -l)"
echo ""

echo "Instalações bem-sucedidas:"
grep -h "SUCCESS" $LOG_DIR/*.log 2>/dev/null | wc -l

echo ""
echo "Erros encontrados:"
grep -h "ERROR" $LOG_DIR/*.log 2>/dev/null | wc -l

echo ""
echo "Últimas 5 operações:"
tail -5 $LOG_DIR/installer_*.log 2>/dev/null | grep -E "SUCCESS|ERROR"
```

## 🧪 Testes

### Testar em Container

```bash
# Ubuntu
docker run -it --rm ubuntu:24.04 bash
apt-get update && apt-get install -y git sudo
git clone https://github.com/seu-usuario/shell-install-applications-script.git
cd shell-install-applications-script
./installer.sh

# Rocky Linux
docker run -it --rm rockylinux:9 bash
dnf install -y git sudo
git clone https://github.com/seu-usuario/shell-install-applications-script.git
cd shell-install-applications-script
./installer.sh
```

### Script de Teste Automatizado

```bash
#!/bin/bash
# test_scripts.sh

TEST_DISTROS=("ubuntu:24.04" "rockylinux:9" "debian:12")

for distro in "${TEST_DISTROS[@]}"; do
    echo "Testando em $distro..."
    
    docker run --rm $distro bash -c "
        apt-get update 2>/dev/null || dnf install -y 2>/dev/null
        cd /tmp
        git clone https://github.com/seu-usuario/shell-install-applications-script.git
        cd shell-install-applications-script
        ./install_zabbix.sh
    "
    
    if [ $? -eq 0 ]; then
        echo "✓ $distro: OK"
    else
        echo "✗ $distro: FALHOU"
    fi
done
```

## 🔐 Uso Seguro

### Gerenciamento de Senhas

Use ferramentas de gerenciamento de segredos:

```bash
# Com Vault
export DOMAIN_PASSWORD=$(vault kv get -field=password secret/domain)
echo "$DOMAIN_PASSWORD" | ./register_domain.sh

# Com pass
export DOMAIN_PASSWORD=$(pass domain/admin)
echo "$DOMAIN_PASSWORD" | ./register_domain.sh

# Com arquivo de credenciais
cat > /tmp/creds <<EOF
dominio.com
admin
senha_segura
linux-admins
EOF

./register_domain.sh < /tmp/creds
rm -f /tmp/creds
```

### Auditoria

```bash
# Registrar execuções
echo "$(date): Instalação iniciada por $USER" >> /var/log/script_audit.log
./installer.sh
echo "$(date): Instalação concluída" >> /var/log/script_audit.log

# Com mais detalhes
logger -t installer "Iniciando instalação do Zabbix"
./install_zabbix.sh
logger -t installer "Instalação do Zabbix concluída"
```

## 🎨 Customização

### Personalizar Configurações

```bash
# Criar configuração personalizada
cp config/settings.conf config/settings.local.conf

# Editar para seu ambiente
nano config/settings.local.conf

# Carregar configuração personalizada
export CONFIG_FILE="config/settings.local.conf"
./install_zabbix.sh
```

### Adicionar Novo Script ao Menu

Edite `installer.sh`:

```bash
# Na função show_main_menu(), adicione:
echo -e "  ${COLOR_GREEN}8${COLOR_RESET}) ${COLOR_CYAN}Meu Script Novo${COLOR_RESET}"

# Na função process_menu_choice(), adicione:
8)
    bash "$SCRIPT_DIR/meu_script_novo.sh"
    pause_for_user
    ;;
```

## 📖 Mais Exemplos

### Pipeline CI/CD

```yaml
# .gitlab-ci.yml
deploy:
  stage: deploy
  script:
    - scp -r . root@server:/opt/scripts/
    - ssh root@server "cd /opt/scripts && ./install_zabbix.sh"
  only:
    - main
```

### Cron Job

```bash
# Atualizar agente Zabbix semanalmente
0 2 * * 0 cd /opt/scripts && ./install_zabbix.sh >> /var/log/zabbix_update.log 2>&1
```

### Systemd Service

```ini
[Unit]
Description=Configuração Inicial do Servidor
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/scripts/installer.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

---

**Mais exemplos?** Contribua com seus casos de uso abrindo um PR!

