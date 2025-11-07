#!/bin/bash

#==============================================================================
# Script de Instalação do Kaspersky
# Monta compartilhamento SMB e instala Kaspersky Endpoint Security
# Pode ser executado individualmente ou através do menu principal
#==============================================================================

# Obter o diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carregar biblioteca de funções comuns
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    echo "ERRO: Biblioteca comum não encontrada"
    exit 1
fi

# Carregar configurações
if [ -f "$SCRIPT_DIR/config/settings.conf" ]; then
    source "$SCRIPT_DIR/config/settings.conf"
else
    # Valores padrão
    KASPERSKY_FILE_SERVER="10.130.2.10"
    KASPERSKY_SHARE_NAME="KASPERSKY-STAND-ALONE-INSTALL"
    KASPERSKY_MOUNT_DIR="/mnt/file_server"
    KASPERSKY_KLNA_SCRIPT="KLNA -15 (Agente de rede para linux RPM).sh"
    KASPERSKY_KESL_SCRIPT="KESL - 12.0 (Para todos os dispositivos linux).sh"
fi

#==============================================================================
# Funções
#==============================================================================

# Instalar pacotes necessários
install_smb_packages() {
    print_info "Verificando pacotes necessários..."
    log_info "Verificando e instalando pacotes SMB"
    
    local pkg_manager=$(get_package_manager)
    local package
    
    # Determinar nome do pacote baseado na distribuição
    case "$pkg_manager" in
        apt)
            package="cifs-utils"
            ;;
        dnf|yum)
            package="cifs-utils"
            # Também instalar samba-client para smbclient
            if ! command -v smbclient &>/dev/null; then
                install_package "samba-client"
            fi
            ;;
    esac
    
    # Verificar se cifs-utils está instalado
    if ! command -v mount.cifs &>/dev/null; then
        print_info "Instalando $package..."
        install_package "$package"
    else
        print_success "$package já está instalado"
    fi
    
    return 0
}

# Montar compartilhamento SMB
mount_smb_share() {
    local username="$1"
    local password="$2"
    
    print_info "Montando compartilhamento SMB..."
    log_info "Montando //$KASPERSKY_FILE_SERVER/$KASPERSKY_SHARE_NAME"
    
    # Criar diretório de montagem se não existir
    if [ ! -d "$KASPERSKY_MOUNT_DIR" ]; then
        print_info "Criando diretório de montagem: $KASPERSKY_MOUNT_DIR"
        mkdir -p "$KASPERSKY_MOUNT_DIR"
    fi
    
    # Montar compartilhamento
    mount -t cifs "//$KASPERSKY_FILE_SERVER/$KASPERSKY_SHARE_NAME" \
        "$KASPERSKY_MOUNT_DIR" \
        -o "username=$username,password=$password,vers=3.0" \
        >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Compartilhamento montado com sucesso"
        log_success "Compartilhamento SMB montado em $KASPERSKY_MOUNT_DIR"
        return 0
    else
        print_error "Falha ao montar compartilhamento SMB"
        log_error "Falha ao montar compartilhamento SMB"
        
        print_warning "Possíveis causas:"
        echo "  - Credenciais incorretas"
        echo "  - Servidor não acessível"
        echo "  - Firewall bloqueando portas SMB (445)"
        echo "  - Compartilhamento não existe"
        
        return 1
    fi
}

# Desmontar compartilhamento SMB
unmount_smb_share() {
    print_info "Desmontando compartilhamento..."
    log_info "Desmontando $KASPERSKY_MOUNT_DIR"
    
    umount "$KASPERSKY_MOUNT_DIR" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Compartilhamento desmontado"
        log_success "Compartilhamento SMB desmontado"
    else
        print_warning "Aviso ao desmontar compartilhamento"
        log_warning "Aviso ao desmontar compartilhamento"
    fi
}

# Executar script de instalação
run_installation_script() {
    local script_name="$1"
    local script_path="$KASPERSKY_MOUNT_DIR/$script_name"
    
    print_info "Executando script: $script_name"
    log_info "Executando script de instalação: $script_name"
    
    # Verificar se o script existe
    if [ ! -f "$script_path" ]; then
        print_error "Script não encontrado: $script_path"
        log_error "Script não encontrado: $script_path"
        return 1
    fi
    
    # Executar script
    sh "$script_path" >> "$LOG_FILE" 2>&1
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "Script executado com sucesso"
        log_success "Script $script_name executado com sucesso"
        return 0
    else
        print_error "Falha ao executar script (código: $exit_code)"
        log_error "Falha ao executar $script_name (código: $exit_code)"
        return 1
    fi
}

#==============================================================================
# Função Principal
#==============================================================================

main() {
    # Inicializar logging
    init_logging
    
    print_header "Instalação do Kaspersky Endpoint Security"
    
    # Verificar root
    check_root
    
    # Detectar distribuição
    detect_distro
    print_info "Sistema: $DISTRO_NAME $DISTRO_VERSION"
    
    print_separator
    
    # Instalar pacotes necessários
    if ! install_smb_packages; then
        print_error "Falha ao instalar pacotes necessários"
        exit 1
    fi
    
    print_separator
    
    # Coletar credenciais SMB
    print_header "Credenciais do Compartilhamento SMB"
    print_info "Servidor: $KASPERSKY_FILE_SERVER"
    print_info "Compartilhamento: $KASPERSKY_SHARE_NAME"
    echo ""
    
    local smb_username=$(prompt_user "Digite o usuário SMB")
    validate_not_empty "$smb_username" "Usuário" || exit 1
    
    local smb_password=$(prompt_password "Digite a senha do usuário $smb_username")
    validate_not_empty "$smb_password" "Senha" || exit 1
    
    print_separator
    
    # Montar compartilhamento
    if ! mount_smb_share "$smb_username" "$smb_password"; then
        exit 1
    fi
    
    print_separator
    
    # Executar instalações
    local failed=0
    
    # KLNA (Kaspersky Network Agent)
    print_info "Instalando Kaspersky Network Agent (KLNA)..."
    if run_installation_script "$KASPERSKY_KLNA_SCRIPT"; then
        print_success "KLNA instalado"
    else
        print_error "Falha na instalação do KLNA"
        failed=$((failed + 1))
    fi
    
    print_separator
    
    # KESL (Kaspersky Endpoint Security for Linux)
    print_info "Instalando Kaspersky Endpoint Security (KESL)..."
    if run_installation_script "$KASPERSKY_KESL_SCRIPT"; then
        print_success "KESL instalado"
    else
        print_error "Falha na instalação do KESL"
        failed=$((failed + 1))
    fi
    
    print_separator
    
    # Desmontar compartilhamento
    unmount_smb_share
    
    # Resumo
    print_separator
    if [ $failed -eq 0 ]; then
        print_success "Kaspersky instalado com sucesso!"
        log_success "Instalação do Kaspersky concluída com sucesso"
    else
        print_warning "$failed componente(s) falharam na instalação"
        print_info "Verifique o log para mais detalhes"
        log_warning "Instalação concluída com $failed falha(s)"
    fi
    
    print_info "Log salvo em: $LOG_FILE"
    
    return $failed
}

# Trap para garantir desmontagem em caso de erro
cleanup() {
    if mountpoint -q "$KASPERSKY_MOUNT_DIR" 2>/dev/null; then
        print_warning "Desmontando compartilhamento..."
        umount "$KASPERSKY_MOUNT_DIR" 2>/dev/null
    fi
}

trap cleanup EXIT

# Executar apenas se for o script principal
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
