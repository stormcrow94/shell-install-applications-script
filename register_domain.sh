#!/bin/bash

#==============================================================================
# Script de Registro no Domínio
# Integra o sistema ao domínio via SSSD/Realmd
# Detecta automaticamente a distribuição e instala os pacotes apropriados
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
fi

#==============================================================================
# Funções Específicas de Domínio
#==============================================================================

# Obter lista de pacotes necessários baseado na distribuição
get_required_packages() {
    local distro="$1"
    
    case "$distro" in
        ubuntu|debian)
            echo "sssd realmd oddjob oddjob-mkhomedir adcli samba-common-bin krb5-user ldap-utils"
            ;;
        rhel|centos|rocky|almalinux)
            echo "sssd realmd oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation openldap-clients"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Instalar pacotes necessários
install_domain_packages() {
    print_info "Instalando pacotes necessários para integração ao domínio..."
    log_info "Instalando pacotes de domínio"
    
    local packages=$(get_required_packages "$DISTRO")
    
    if [ -z "$packages" ]; then
        print_error "Distribuição não suportada: $DISTRO"
        log_error "Distribuição não suportada: $DISTRO"
        return 1
    fi
    
    # Atualizar repositórios
    update_repositories
    
    # Instalar pacotes
    install_packages $packages
    
    if [ $? -eq 0 ]; then
        print_success "Todos os pacotes foram instalados"
        log_success "Pacotes de domínio instalados com sucesso"
        return 0
    else
        print_error "Falha ao instalar alguns pacotes"
        log_error "Falha na instalação de pacotes de domínio"
        return 1
    fi
}

# Coletar informações do domínio
collect_domain_info() {
    print_header "Informações do Domínio"
    
    # Domínio
    if [ -n "$DEFAULT_DOMAIN" ]; then
        DOMAIN=$(prompt_user "Digite o domínio" "$DEFAULT_DOMAIN")
    else
        DOMAIN=$(prompt_user "Digite o domínio (exemplo: example.com)")
    fi
    
    validate_not_empty "$DOMAIN" "Domínio" || return 1
    log_info "Domínio informado: $DOMAIN"
    
    # Usuário
    if [ -n "$DEFAULT_ADMIN_USER" ]; then
        USERNAME=$(prompt_user "Digite o usuário administrador" "$DEFAULT_ADMIN_USER")
    else
        USERNAME=$(prompt_user "Digite o usuário administrador do domínio")
    fi
    
    validate_not_empty "$USERNAME" "Usuário" || return 1
    log_info "Usuário informado: $USERNAME"
    
    # Senha
    PASSWORD=$(prompt_password "Digite a senha do usuário $USERNAME")
    validate_not_empty "$PASSWORD" "Senha" || return 1
    
    # Grupo para acesso SSH e Sudo
    if [ -n "$DEFAULT_ADMIN_GROUP" ]; then
        ADMIN_GROUP=$(prompt_user "Digite o grupo para acesso SSH e Sudo" "$DEFAULT_ADMIN_GROUP")
    else
        ADMIN_GROUP=$(prompt_user "Digite o grupo do domínio para acesso SSH e Sudo")
    fi
    
    validate_not_empty "$ADMIN_GROUP" "Grupo" || return 1
    log_info "Grupo informado: $ADMIN_GROUP"
    
    print_separator
    return 0
}

# Ingressar no domínio
join_domain() {
    print_info "Ingressando no domínio $DOMAIN..."
    log_info "Iniciando ingresso no domínio: $DOMAIN"
    
    # Usar expect ou passar senha via echo baseado na distribuição
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
        echo "$PASSWORD" | realm join --user="$USERNAME" "$DOMAIN" >> "$LOG_FILE" 2>&1
    else
        realm join --user="$USERNAME" "$DOMAIN" << EOF >> "$LOG_FILE" 2>&1
$PASSWORD
EOF
    fi
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "Computador registrado no domínio com sucesso"
        log_success "Ingresso no domínio realizado com sucesso"
        return 0
    else
        print_error "Falha ao ingressar no domínio"
        log_error "Falha no ingresso no domínio (código: $exit_code)"
        
        # Exibir possíveis causas
        print_warning "Possíveis causas:"
        echo "  - Credenciais incorretas"
        echo "  - Domínio não acessível"
        echo "  - Configuração de DNS incorreta"
        echo "  - Firewall bloqueando portas necessárias"
        
        return 1
    fi
}

# Configurar SSSD
configure_sssd() {
    local sssd_conf="/etc/sssd/sssd.conf"
    
    print_info "Configurando SSSD..."
    log_info "Configurando arquivo $sssd_conf"
    
    # Fazer backup
    backup_file "$sssd_conf"
    
    # Modificar configurações
    if grep -q "use_fully_qualified_names" "$sssd_conf"; then
        sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/' "$sssd_conf"
        sed -i 's/use_fully_qualified_names = true/use_fully_qualified_names = False/' "$sssd_conf"
    else
        # Adicionar após a linha [domain/...]
        sed -i "/\[domain\//a use_fully_qualified_names = False" "$sssd_conf"
    fi
    
    # Configurar fallback_homedir
    if grep -q "fallback_homedir" "$sssd_conf"; then
        sed -i 's|fallback_homedir = .*|fallback_homedir = /home/%u|' "$sssd_conf"
    else
        sed -i "/\[domain\//a fallback_homedir = /home/%u" "$sssd_conf"
    fi
    
    # Modificar access_provider para simple
    sed -i 's/access_provider = ad/access_provider = simple/' "$sssd_conf"
    sed -i 's/access_provider = AD/access_provider = simple/' "$sssd_conf"
    
    # Adicionar grupo ao acesso
    if ! grep -q "simple_allow_groups" "$sssd_conf"; then
        sed -i "/access_provider = simple/a simple_allow_groups = $ADMIN_GROUP" "$sssd_conf"
    else
        sed -i "s/simple_allow_groups = .*/simple_allow_groups = $ADMIN_GROUP/" "$sssd_conf"
    fi
    
    # Ajustar permissões
    chmod 600 "$sssd_conf"
    
    print_success "SSSD configurado"
    log_success "Configuração do SSSD atualizada"
    
    return 0
}

# Configurar sudoers
configure_sudoers() {
    local sudoers_dir="/etc/sudoers.d"
    local sudoers_file="$sudoers_dir/domain_admins"
    
    print_info "Configurando permissões sudo para o grupo $ADMIN_GROUP..."
    log_info "Configurando sudoers para grupo: $ADMIN_GROUP"
    
    # Criar diretório se não existir
    mkdir -p "$sudoers_dir"
    
    # Criar arquivo sudoers
    echo "# Permissões sudo para grupo do domínio" > "$sudoers_file"
    echo "# Gerado automaticamente em $(date)" >> "$sudoers_file"
    echo "%$ADMIN_GROUP ALL=(ALL) ALL" >> "$sudoers_file"
    
    # Ajustar permissões
    chmod 440 "$sudoers_file"
    
    # Validar sintaxe
    if visudo -c -f "$sudoers_file" >> "$LOG_FILE" 2>&1; then
        print_success "Permissões sudo configuradas para %$ADMIN_GROUP"
        log_success "Sudoers configurado com sucesso"
        return 0
    else
        print_error "Erro na sintaxe do arquivo sudoers"
        log_error "Erro de sintaxe no arquivo sudoers"
        rm -f "$sudoers_file"
        return 1
    fi
}

# Configurar PAM para criar home directories
configure_pam() {
    print_info "Configurando PAM para criar diretórios home automaticamente..."
    log_info "Configurando PAM"
    
    local pam_file
    
    # Arquivo PAM varia por distribuição
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
        pam_file="/etc/pam.d/common-session"
    else
        pam_file="/etc/pam.d/system-auth"
    fi
    
    # Verificar se já está configurado
    if grep -q "pam_mkhomedir.so" "$pam_file"; then
        print_info "PAM já configurado para criar home directories"
        log_info "PAM já configurado"
        return 0
    fi
    
    # Adicionar configuração
    backup_file "$pam_file"
    echo "session optional pam_mkhomedir.so skel=/etc/skel umask=0077" >> "$pam_file"
    
    print_success "PAM configurado"
    log_success "PAM configurado para criar home directories"
    
    return 0
}

# Reiniciar serviços
restart_domain_services() {
    print_info "Reiniciando serviços..."
    log_info "Reiniciando serviços de domínio"
    
    # Habilitar oddjobd
    if systemctl list-unit-files | grep -q "oddjobd"; then
        enable_service "oddjobd"
        restart_service "oddjobd"
    fi
    
    # Reiniciar SSSD
    restart_service "sssd"
    
    # Reiniciar SSH
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
        restart_service "ssh"
    else
        restart_service "sshd"
    fi
    
    print_success "Serviços reiniciados"
    log_success "Serviços reiniciados com sucesso"
    
    return 0
}

# Verificar status do domínio
verify_domain_status() {
    print_separator
    print_info "Verificando status do domínio..."
    log_info "Verificando status do ingresso no domínio"
    
    # Verificar realm
    local realm_status=$(realm list 2>/dev/null)
    
    if [ -n "$realm_status" ]; then
        print_success "Sistema está integrado ao domínio"
        echo "$realm_status" | grep -E "domain-name|configured"
        log_success "Verificação de domínio: OK"
    else
        print_warning "Não foi possível verificar status do domínio"
        log_warning "Falha na verificação de status do domínio"
    fi
    
    print_separator
}

# Exibir informações finais
show_final_info() {
    print_header "Registro no Domínio Concluído"
    
    print_success "Sistema registrado no domínio: $DOMAIN"
    print_info "Configurações aplicadas:"
    echo "  ✓ Pacotes necessários instalados"
    echo "  ✓ Sistema ingressado no domínio"
    echo "  ✓ SSSD configurado"
    echo "  ✓ Grupo '$ADMIN_GROUP' com permissões sudo"
    echo "  ✓ PAM configurado para criar home directories"
    echo "  ✓ Serviços reiniciados"
    
    print_separator
    print_warning "Próximos passos:"
    echo "  1. Faça logout e login com um usuário do domínio"
    echo "  2. Verifique se o home directory foi criado"
    echo "  3. Teste as permissões sudo com membros do grupo '$ADMIN_GROUP'"
    
    print_separator
    print_info "Para verificar usuários do domínio:"
    echo "  id usuario@$DOMAIN"
    
    print_info "Para listar informações do domínio:"
    echo "  realm list"
    
    print_info "Log salvo em: $LOG_FILE"
    
    log_success "Registro no domínio concluído com sucesso"
}

#==============================================================================
# Função Principal
#==============================================================================

main() {
    # Inicializar logging
    init_logging
    
    print_header "Registro no Domínio"
    
    # Verificar root
    check_root
    
    # Detectar distribuição
    detect_distro
    print_info "Sistema: $DISTRO_NAME $DISTRO_VERSION"
    
    # Verificar internet se configurado
    if [ "${CHECK_INTERNET:-true}" = "true" ]; then
        if ! check_internet; then
            print_warning "Sem conexão com internet, continuando mesmo assim..."
        fi
    fi
    
    print_separator
    
    # Instalar pacotes necessários
    if ! install_domain_packages; then
        print_error "Falha ao instalar pacotes necessários"
        exit 1
    fi
    
    print_separator
    
    # Coletar informações do domínio
    if ! collect_domain_info; then
        print_error "Informações do domínio incompletas"
        exit 1
    fi
    
    # Confirmar antes de continuar
    if ! prompt_confirm "Deseja continuar com o registro no domínio $DOMAIN?"; then
        print_warning "Operação cancelada pelo usuário"
        log_info "Operação cancelada pelo usuário"
        exit 0
    fi
    
    print_separator
    
    # Ingressar no domínio
    if ! join_domain; then
        print_error "Falha ao ingressar no domínio"
        exit 1
    fi
    
    # Configurar SSSD
    if ! configure_sssd; then
        print_warning "Falha ao configurar SSSD, continuando..."
    fi
    
    # Configurar sudoers
    if ! configure_sudoers; then
        print_warning "Falha ao configurar sudo, você precisará configurar manualmente"
    fi
    
    # Configurar PAM
    if ! configure_pam; then
        print_warning "Falha ao configurar PAM, home directories podem não ser criados automaticamente"
    fi
    
    # Reiniciar serviços
    if ! restart_domain_services; then
        print_warning "Falha ao reiniciar alguns serviços"
    fi
    
    # Verificar status
    verify_domain_status
    
    # Exibir informações finais
    show_final_info
    
    return 0
}

# Executar apenas se for o script principal
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

