#!/bin/bash

#==============================================================================
# Script de Instalação do Zabbix Agent
# Detecta automaticamente a distribuição e instala o agente Zabbix apropriado
# Pode ser executado individualmente ou através do menu principal
#==============================================================================

# Obter o diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carregar biblioteca de funções comuns
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    echo "ERRO: Biblioteca comum não encontrada em $SCRIPT_DIR/lib/common.sh"
    exit 1
fi

# Carregar configurações
if [ -f "$SCRIPT_DIR/config/settings.conf" ]; then
    source "$SCRIPT_DIR/config/settings.conf"
else
    print_warning "Arquivo de configuração não encontrado, usando valores padrão"
    ZABBIX_PROXY_SERVER="10.130.3.201"
    ZABBIX_SERVER_PORT="10051"
    ZABBIX_AGENT_PORT="10050"
    ZABBIX_DEBUG_LEVEL="3"
    ZABBIX_LOG_SIZE="10"
fi

#==============================================================================
# Funções Específicas do Zabbix
#==============================================================================

# Instalar repositório do Zabbix para Ubuntu
install_zabbix_repo_ubuntu() {
    local version="${ZABBIX_VERSION_UBUNTU:-7.0}"
    local ubuntu_version
    
    # Detectar versão do Ubuntu
    ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "24.04")
    
    print_info "Instalando repositório Zabbix $version para Ubuntu $ubuntu_version..."
    log_info "Instalando repositório Zabbix para Ubuntu"
    
    local repo_url="https://repo.zabbix.com/zabbix/${version}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${version}-2+ubuntu${ubuntu_version}_all.deb"
    local temp_deb="/tmp/zabbix-release.deb"
    
    # Baixar pacote do repositório
    if ! wget -q "$repo_url" -O "$temp_deb" 2>> "$LOG_FILE"; then
        print_warning "Falha ao baixar repositório específico, tentando versão genérica..."
        repo_url="https://repo.zabbix.com/zabbix/${version}/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu${ubuntu_version}_all.deb"
        wget -q "$repo_url" -O "$temp_deb" 2>> "$LOG_FILE" || return 1
    fi
    
    # Instalar repositório
    dpkg -i "$temp_deb" >> "$LOG_FILE" 2>&1
    rm -f "$temp_deb"
    
    # Atualizar cache
    apt-get update >> "$LOG_FILE" 2>&1
    
    print_success "Repositório Zabbix instalado"
    log_success "Repositório Zabbix instalado para Ubuntu"
    return 0
}

# Instalar repositório do Zabbix para Debian
install_zabbix_repo_debian() {
    local version="${ZABBIX_VERSION_DEBIAN:-6.0}"
    local debian_version
    
    # Detectar versão do Debian
    debian_version=$(lsb_release -rs 2>/dev/null || cat /etc/debian_version 2>/dev/null | cut -d'.' -f1 || echo "12")
    
    print_info "Instalando repositório Zabbix $version para Debian $debian_version..."
    log_info "Instalando repositório Zabbix para Debian"
    
    local repo_url="https://repo.zabbix.com/zabbix/${version}/debian/pool/main/z/zabbix-release/zabbix-release_latest_${version}+debian${debian_version}_all.deb"
    local temp_deb="/tmp/zabbix-release.deb"
    
    # Baixar pacote do repositório
    print_info "Baixando pacote do repositório..."
    if ! wget -q "$repo_url" -O "$temp_deb" 2>> "$LOG_FILE"; then
        print_warning "Falha ao baixar versão latest, tentando formato alternativo..."
        repo_url="https://repo.zabbix.com/zabbix/${version}/debian/pool/main/z/zabbix-release/zabbix-release_${version}-2+debian${debian_version}_all.deb"
        wget -q "$repo_url" -O "$temp_deb" 2>> "$LOG_FILE" || return 1
    fi
    
    # Instalar repositório
    print_info "Instalando pacote do repositório..."
    dpkg -i "$temp_deb" >> "$LOG_FILE" 2>&1
    rm -f "$temp_deb"
    
    # Atualizar cache
    print_info "Atualizando cache de pacotes..."
    apt-get update >> "$LOG_FILE" 2>&1
    
    print_success "Repositório Zabbix instalado"
    log_success "Repositório Zabbix instalado para Debian $debian_version"
    return 0
}

# Instalar repositório do Zabbix para RHEL/Rocky/CentOS
install_zabbix_repo_rhel() {
    local version="${ZABBIX_VERSION_RHEL:-6.4}"
    local rhel_version="${DISTRO_VERSION%%.*}"
    local pkg_manager=$(get_package_manager)
    
    print_info "Instalando repositório Zabbix $version para RHEL/Rocky $rhel_version..."
    log_info "Instalando repositório Zabbix para RHEL/Rocky"
    
    # Remover repositório antigo se existir
    $pkg_manager remove -y zabbix-release >> "$LOG_FILE" 2>&1
    
    local repo_url="https://repo.zabbix.com/zabbix/${version}/rhel/${rhel_version}/x86_64/zabbix-release-${version}-1.el${rhel_version}.noarch.rpm"
    
    # Instalar repositório
    $pkg_manager install -y "$repo_url" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        print_error "Falha ao instalar repositório Zabbix"
        log_error "Falha ao instalar repositório Zabbix"
        return 1
    fi
    
    # Limpar e atualizar cache
    $pkg_manager clean all >> "$LOG_FILE" 2>&1
    
    print_success "Repositório Zabbix instalado"
    log_success "Repositório Zabbix instalado para RHEL/Rocky"
    return 0
}

# Criar arquivo de configuração do Zabbix Agent
create_zabbix_config() {
    local config_file="$1"
    local hostname=$(get_hostname)
    local ip_address=$(get_ip_address)
    local pid_file
    
    print_info "Criando arquivo de configuração do Zabbix..."
    log_info "Criando configuração do Zabbix Agent"
    
    # Fazer backup do arquivo original se existir
    if [ -f "$config_file" ]; then
        backup_file "$config_file"
    fi
    
    # Determinar caminho do PID file baseado na distribuição
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
        pid_file="/var/run/zabbix/zabbix_agentd.pid"
    else
        pid_file="/run/zabbix/zabbix_agentd.pid"
    fi
    
    # Criar configuração
    cat > "$config_file" <<EOL
# Arquivo de configuração do Zabbix Agent
# Gerado automaticamente em $(date)
# Hostname: $hostname | IP: $ip_address

############ PARÂMETROS GERAIS #################

### Option: PidFile
PidFile=$pid_file

### Option: LogFile
LogFile=/var/log/zabbix/zabbix_agentd.log

### Option: LogFileSize
# Tamanho máximo do arquivo de log em MB
LogFileSize=$ZABBIX_LOG_SIZE

### Option: DebugLevel
# 0 - informações básicas
# 1 - informações críticas
# 2 - informações de erro
# 3 - avisos
# 4 - debug (produz muitas informações)
# 5 - debug estendido
DebugLevel=$ZABBIX_DEBUG_LEVEL

### Option: Server
# Lista de IPs dos servidores/proxies Zabbix separados por vírgula
Server=$ZABBIX_PROXY_SERVER

### Option: ListenPort
# Porta em que o agente escutará conexões do servidor
ListenPort=$ZABBIX_AGENT_PORT

### Option: ListenIP
# Lista de IPs em que o agente deve escutar
ListenIP=0.0.0.0

### Option: StartAgents
# Número de instâncias pré-forked do zabbix_agentd
StartAgents=3

### Option: ServerActive
# Lista de servidores/proxies Zabbix para verificações ativas
ServerActive=$ZABBIX_PROXY_SERVER:$ZABBIX_SERVER_PORT

### Option: Hostname
# Nome único do host (case sensitive)
Hostname=$hostname

### Option: HostMetadata
# Metadados do host para auto-registro
HostMetadata=Linux

### Option: Include
# Incluir arquivos de configuração adicionais
Include=/etc/zabbix/zabbix_agentd.d/*.conf

############ FIM DA CONFIGURAÇÃO #################
EOL

    # Ajustar permissões
    chown -R zabbix:zabbix /etc/zabbix 2>/dev/null || true
    chmod 644 "$config_file"
    
    print_success "Arquivo de configuração criado: $config_file"
    log_success "Configuração do Zabbix Agent criada"
    
    # Exibir informações
    print_info "Configuração:"
    echo "  - Hostname: $hostname"
    echo "  - IP: $ip_address"
    echo "  - Servidor Zabbix: $ZABBIX_PROXY_SERVER"
    echo "  - Porta do Agente: $ZABBIX_AGENT_PORT"
    
    return 0
}

# Configurar firewall (se necessário)
configure_firewall() {
    print_info "Configurando firewall..."
    log_info "Configurando regras de firewall"
    
    # Verificar se firewalld está ativo
    if systemctl is-active --quiet firewalld; then
        print_info "Firewalld detectado, abrindo porta $ZABBIX_AGENT_PORT/tcp..."
        firewall-cmd --add-port=${ZABBIX_AGENT_PORT}/tcp --permanent >> "$LOG_FILE" 2>&1
        firewall-cmd --reload >> "$LOG_FILE" 2>&1
        print_success "Regra de firewall adicionada"
        log_success "Porta $ZABBIX_AGENT_PORT/tcp liberada no firewalld"
    # Verificar se ufw está ativo
    elif command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        print_info "UFW detectado, abrindo porta $ZABBIX_AGENT_PORT/tcp..."
        ufw allow ${ZABBIX_AGENT_PORT}/tcp >> "$LOG_FILE" 2>&1
        print_success "Regra de firewall adicionada"
        log_success "Porta $ZABBIX_AGENT_PORT/tcp liberada no ufw"
    else
        print_info "Nenhum firewall ativo detectado, pulando configuração"
        log_info "Nenhum firewall ativo detectado"
    fi
}

# Instalar Zabbix Agent no Ubuntu
install_zabbix_ubuntu() {
    print_header "Instalação do Zabbix Agent - Ubuntu"
    
    # Instalar repositório
    if ! install_zabbix_repo_ubuntu; then
        print_error "Falha ao instalar repositório Zabbix"
        return 1
    fi
    
    # Instalar agente
    if ! install_package "zabbix-agent"; then
        print_error "Falha ao instalar zabbix-agent"
        return 1
    fi
    
    # Criar configuração
    create_zabbix_config "/etc/zabbix/zabbix_agentd.conf"
    
    # Configurar firewall
    configure_firewall
    
    # Reiniciar e habilitar serviço
    restart_service "zabbix-agent"
    enable_service "zabbix-agent"
    
    # Verificar status
    print_separator
    check_service_status "zabbix-agent"
    
    return 0
}

# Instalar Zabbix Agent no Debian
install_zabbix_debian() {
    print_header "Instalação do Zabbix Agent - Debian"
    
    # Instalar repositório
    if ! install_zabbix_repo_debian; then
        print_error "Falha ao instalar repositório Zabbix"
        return 1
    fi
    
    # Instalar agente
    if ! install_package "zabbix-agent"; then
        print_error "Falha ao instalar zabbix-agent"
        return 1
    fi
    
    # Criar configuração
    create_zabbix_config "/etc/zabbix/zabbix_agentd.conf"
    
    # Configurar firewall
    configure_firewall
    
    # Reiniciar e habilitar serviço
    restart_service "zabbix-agent"
    enable_service "zabbix-agent"
    
    # Verificar status
    print_separator
    check_service_status "zabbix-agent"
    
    return 0
}

# Instalar Zabbix Agent no RHEL/Rocky/CentOS
install_zabbix_rhel() {
    print_header "Instalação do Zabbix Agent - RHEL/Rocky/CentOS"
    
    # Instalar repositório
    if ! install_zabbix_repo_rhel; then
        print_error "Falha ao instalar repositório Zabbix"
        return 1
    fi
    
    # Instalar agente
    if ! install_package "zabbix-agent"; then
        print_error "Falha ao instalar zabbix-agent"
        return 1
    fi
    
    # Criar configuração
    create_zabbix_config "/etc/zabbix/zabbix_agentd.conf"
    
    # Configurar firewall
    configure_firewall
    
    # Reiniciar e habilitar serviço
    restart_service "zabbix-agent"
    enable_service "zabbix-agent"
    
    # Verificar status
    print_separator
    check_service_status "zabbix-agent"
    
    return 0
}

#==============================================================================
# Função Principal
#==============================================================================

main() {
    # Inicializar logging
    init_logging
    
    print_header "Instalador do Zabbix Agent"
    
    # Verificar root
    check_root
    
    # Verificar internet se configurado
    if [ "${CHECK_INTERNET:-true}" = "true" ]; then
        if ! check_internet; then
            print_error "Conexão com internet é necessária para instalação"
            exit 1
        fi
    fi
    
    # Detectar distribuição
    detect_distro
    print_info "Sistema: $DISTRO_NAME $DISTRO_VERSION"
    
    # Permitir override do servidor Zabbix via argumento
    if [ -n "$1" ]; then
        ZABBIX_PROXY_SERVER="$1"
        print_info "Usando servidor Zabbix: $ZABBIX_PROXY_SERVER"
    fi
    
    # Instalar baseado na distribuição
    case "$DISTRO" in
        ubuntu)
            install_zabbix_ubuntu
            ;;
        debian)
            install_zabbix_debian
            ;;
        rhel|centos|rocky|almalinux)
            install_zabbix_rhel
            ;;
        *)
            print_error "Distribuição não suportada: $DISTRO"
            log_error "Distribuição não suportada: $DISTRO"
            exit 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_separator
        print_success "Instalação do Zabbix Agent concluída com sucesso!"
        print_info "Log salvo em: $LOG_FILE"
        log_success "Instalação concluída com sucesso"
        return 0
    else
        print_error "Falha na instalação do Zabbix Agent"
        print_info "Verifique o log em: $LOG_FILE"
        log_error "Falha na instalação"
        return 1
    fi
}

# Executar apenas se for o script principal
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

