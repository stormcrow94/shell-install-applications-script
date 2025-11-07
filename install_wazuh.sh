#!/bin/bash

#==============================================================================
# Script de Instalação do Wazuh Agent
# Detecta automaticamente a distribuição e instala o agente Wazuh apropriado
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
    WAZUH_MANAGER="wazuh.vantix.com.br"
    WAZUH_VERSION="4.14.0"
    WAZUH_REVISION="1"
fi

#==============================================================================
# Funções Específicas do Wazuh
#==============================================================================

# Instalar Wazuh Agent no Ubuntu/Debian (DEB)
install_wazuh_debian() {
    print_header "Instalação do Wazuh Agent - Ubuntu/Debian"
    
    local package_name="wazuh-agent_${WAZUH_VERSION}-${WAZUH_REVISION}_amd64.deb"
    local package_url="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/${package_name}"
    local temp_package="/tmp/${package_name}"
    
    # Instalar dependências
    print_info "Instalando dependências..."
    log_info "Instalando dependências para Wazuh Agent"
    
    install_packages wget curl
    
    if [ $? -ne 0 ]; then
        print_error "Falha ao instalar dependências"
        return 1
    fi
    
    # Baixar pacote do Wazuh
    print_info "Baixando Wazuh Agent ${WAZUH_VERSION}..."
    log_info "Baixando pacote: $package_url"
    
    if ! wget -q "$package_url" -O "$temp_package" 2>> "$LOG_FILE"; then
        print_error "Falha ao baixar o pacote Wazuh"
        log_error "Falha ao baixar: $package_url"
        cleanup_temp_file "$temp_package"
        return 1
    fi
    
    print_success "Pacote baixado com sucesso"
    
    # Instalar o pacote com a variável WAZUH_MANAGER
    print_info "Instalando Wazuh Agent..."
    log_info "Instalando com WAZUH_MANAGER=$WAZUH_MANAGER"
    
    WAZUH_MANAGER="$WAZUH_MANAGER" dpkg -i "$temp_package" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        print_error "Falha ao instalar Wazuh Agent"
        log_error "Falha na instalação do pacote DEB"
        cleanup_temp_file "$temp_package"
        return 1
    fi
    
    print_success "Wazuh Agent instalado com sucesso"
    log_success "Wazuh Agent instalado"
    
    # Limpar arquivo temporário
    cleanup_temp_file "$temp_package"
    
    return 0
}

# Instalar Wazuh Agent no RHEL/Rocky/CentOS (RPM)
install_wazuh_rhel() {
    print_header "Instalação do Wazuh Agent - RHEL/Rocky/CentOS"
    
    local package_name="wazuh-agent-${WAZUH_VERSION}-${WAZUH_REVISION}.x86_64.rpm"
    local package_url="https://packages.wazuh.com/4.x/yum/${package_name}"
    local temp_package="/tmp/${package_name}"
    
    # Instalar dependências
    print_info "Instalando dependências..."
    log_info "Instalando dependências para Wazuh Agent"
    
    install_packages wget curl
    
    if [ $? -ne 0 ]; then
        print_error "Falha ao instalar dependências"
        return 1
    fi
    
    # Baixar pacote do Wazuh
    print_info "Baixando Wazuh Agent ${WAZUH_VERSION}..."
    log_info "Baixando pacote: $package_url"
    
    if ! curl -so "$temp_package" "$package_url" 2>> "$LOG_FILE"; then
        print_error "Falha ao baixar o pacote Wazuh"
        log_error "Falha ao baixar: $package_url"
        cleanup_temp_file "$temp_package"
        return 1
    fi
    
    print_success "Pacote baixado com sucesso"
    
    # Instalar o pacote com a variável WAZUH_MANAGER
    print_info "Instalando Wazuh Agent..."
    log_info "Instalando com WAZUH_MANAGER=$WAZUH_MANAGER"
    
    WAZUH_MANAGER="$WAZUH_MANAGER" rpm -ihv "$temp_package" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        print_error "Falha ao instalar Wazuh Agent"
        log_error "Falha na instalação do pacote RPM"
        cleanup_temp_file "$temp_package"
        return 1
    fi
    
    print_success "Wazuh Agent instalado com sucesso"
    log_success "Wazuh Agent instalado"
    
    # Limpar arquivo temporário
    cleanup_temp_file "$temp_package"
    
    return 0
}

# Configurar e iniciar serviço Wazuh
configure_wazuh_service() {
    print_info "Configurando serviço Wazuh Agent..."
    log_info "Iniciando configuração do serviço Wazuh"
    
    # Recarregar daemon do systemd
    print_info "Recarregando systemd daemon..."
    systemctl daemon-reload >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        print_warning "Aviso ao recarregar systemd daemon"
        log_warning "Falha ao executar daemon-reload"
    else
        print_success "Systemd daemon recarregado"
    fi
    
    # Habilitar serviço na inicialização
    if ! enable_service "wazuh-agent"; then
        print_error "Falha ao habilitar serviço wazuh-agent"
        return 1
    fi
    
    # Iniciar serviço
    print_info "Iniciando serviço Wazuh Agent..."
    systemctl start wazuh-agent >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        print_error "Falha ao iniciar serviço wazuh-agent"
        log_error "Falha ao iniciar serviço wazuh-agent"
        return 1
    fi
    
    print_success "Serviço Wazuh Agent iniciado"
    log_success "Serviço wazuh-agent iniciado com sucesso"
    
    # Verificar status do serviço
    sleep 2
    print_separator
    check_service_status "wazuh-agent"
    
    return 0
}

# Exibir informações de configuração
show_wazuh_info() {
    local hostname=$(get_hostname)
    local ip_address=$(get_ip_address)
    
    print_separator
    print_header "Informações do Wazuh Agent"
    
    echo -e "${COLOR_CYAN}Hostname:${COLOR_RESET} $hostname"
    echo -e "${COLOR_CYAN}IP:${COLOR_RESET} $ip_address"
    echo -e "${COLOR_CYAN}Wazuh Manager:${COLOR_RESET} $WAZUH_MANAGER"
    echo -e "${COLOR_CYAN}Versão:${COLOR_RESET} ${WAZUH_VERSION}-${WAZUH_REVISION}"
    
    # Verificar arquivo de configuração
    if [ -f /var/ossec/etc/ossec.conf ]; then
        echo -e "${COLOR_CYAN}Arquivo de configuração:${COLOR_RESET} /var/ossec/etc/ossec.conf"
    fi
    
    # Verificar diretório de logs
    if [ -d /var/ossec/logs ]; then
        echo -e "${COLOR_CYAN}Diretório de logs:${COLOR_RESET} /var/ossec/logs"
    fi
    
    print_separator
}

# Verificar status e conectividade
verify_wazuh_installation() {
    print_info "Verificando instalação do Wazuh Agent..."
    log_info "Iniciando verificação da instalação"
    
    local errors=0
    
    # Verificar se o binário existe
    if [ -f /var/ossec/bin/wazuh-control ]; then
        print_success "Binário do Wazuh encontrado"
    else
        print_error "Binário do Wazuh não encontrado"
        errors=$((errors + 1))
    fi
    
    # Verificar se o serviço está rodando
    if systemctl is-active --quiet wazuh-agent; then
        print_success "Serviço wazuh-agent está ativo"
    else
        print_error "Serviço wazuh-agent não está ativo"
        errors=$((errors + 1))
    fi
    
    # Verificar se está habilitado
    if systemctl is-enabled --quiet wazuh-agent; then
        print_success "Serviço wazuh-agent está habilitado"
    else
        print_warning "Serviço wazuh-agent não está habilitado na inicialização"
    fi
    
    return $errors
}

#==============================================================================
# Função Principal
#==============================================================================

main() {
    # Inicializar logging
    init_logging
    
    print_header "Instalador do Wazuh Agent"
    
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
    
    # Permitir override do servidor Wazuh via argumento
    if [ -n "$1" ]; then
        WAZUH_MANAGER="$1"
        print_info "Usando Wazuh Manager: $WAZUH_MANAGER"
    else
        print_info "Wazuh Manager: $WAZUH_MANAGER"
    fi
    
    # Instalar baseado na distribuição
    local install_success=false
    
    case "$DISTRO" in
        ubuntu|debian)
            if install_wazuh_debian; then
                install_success=true
            fi
            ;;
        rhel|centos|rocky|almalinux)
            if install_wazuh_rhel; then
                install_success=true
            fi
            ;;
        *)
            print_error "Distribuição não suportada: $DISTRO"
            log_error "Distribuição não suportada: $DISTRO"
            exit 1
            ;;
    esac
    
    # Se a instalação foi bem-sucedida, configurar serviço
    if [ "$install_success" = true ]; then
        print_separator
        
        if configure_wazuh_service; then
            print_separator
            show_wazuh_info
            
            print_separator
            if verify_wazuh_installation; then
                print_separator
                print_success "Instalação do Wazuh Agent concluída com sucesso!"
                print_info "O agente está conectado ao manager: $WAZUH_MANAGER"
                print_info "Log salvo em: $LOG_FILE"
                log_success "Instalação concluída com sucesso"
                return 0
            else
                print_warning "Instalação concluída, mas há problemas na verificação"
                print_info "Verifique o log em: $LOG_FILE"
                log_warning "Instalação com avisos"
                return 0
            fi
        else
            print_error "Falha ao configurar o serviço Wazuh"
            print_info "Verifique o log em: $LOG_FILE"
            log_error "Falha na configuração do serviço"
            return 1
        fi
    else
        print_error "Falha na instalação do Wazuh Agent"
        print_info "Verifique o log em: $LOG_FILE"
        log_error "Falha na instalação"
        return 1
    fi
}

# Executar apenas se for o script principal
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

