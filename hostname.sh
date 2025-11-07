#!/bin/bash

#==============================================================================
# Script de Configuração de Hostname
# Altera o nome do host do sistema
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

#==============================================================================
# Função Principal
#==============================================================================

main() {
    # Inicializar logging
    init_logging
    
    print_header "Configuração de Hostname"
    
    # Verificar root
    check_root
    
    # Obter hostname atual
    local current_hostname=$(get_hostname)
    print_info "Hostname atual: $current_hostname"
    
    print_separator
    
    # Solicitar novo hostname
    local new_hostname=$(prompt_user "Digite o novo hostname")
    
    # Validar entrada
    if ! validate_not_empty "$new_hostname" "Hostname"; then
        print_error "Hostname não pode estar vazio"
        log_error "Tentativa de configurar hostname vazio"
        exit 1
    fi
    
    # Validar formato do hostname
    if ! [[ "$new_hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        print_error "Hostname inválido. Use apenas letras, números e hífens"
        print_info "O hostname deve começar e terminar com letra ou número"
        log_error "Formato de hostname inválido: $new_hostname"
        exit 1
    fi
    
    # Confirmar alteração
    print_warning "Alterar hostname de '$current_hostname' para '$new_hostname'"
    if ! prompt_confirm "Confirma a alteração?"; then
        print_info "Operação cancelada"
        log_info "Alteração de hostname cancelada pelo usuário"
        exit 0
    fi
    
    print_separator
    
    # Alterar hostname
    print_info "Alterando hostname..."
    log_info "Alterando hostname de '$current_hostname' para '$new_hostname'"
    
    hostnamectl set-hostname "$new_hostname" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Hostname alterado com sucesso!"
        log_success "Hostname alterado para: $new_hostname"
        
        # Atualizar /etc/hosts se necessário
        if grep -q "127.0.1.1" /etc/hosts; then
            print_info "Atualizando /etc/hosts..."
            backup_file "/etc/hosts"
            sed -i "s/127.0.1.1.*/127.0.1.1 $new_hostname/" /etc/hosts
            print_success "Arquivo /etc/hosts atualizado"
            log_success "/etc/hosts atualizado"
        fi
        
        print_separator
        print_info "Novo hostname: $(get_hostname)"
        print_warning "Reinicie a sessão ou o sistema para que a alteração tenha efeito completo"
        print_info "Log salvo em: $LOG_FILE"
        
    else
        print_error "Falha ao alterar hostname"
        log_error "Falha ao executar hostnamectl"
        exit 1
    fi
}

# Executar apenas se for o script principal
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
