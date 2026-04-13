#!/bin/bash

#==============================================================================
# Menu Principal do Instalador
# Interface interativa para executar scripts de instalação e configuração
# Sistema Linux - Zabbix, Domínio, Kaspersky e mais
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
# Funções do Menu
#==============================================================================

# Exibir banner principal
show_banner() {
    clear
    echo -e "${COLOR_CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║    ███████╗██╗  ██╗███████╗██╗     ██╗                       ║
║    ██╔════╝██║  ██║██╔════╝██║     ██║                       ║
║    ███████╗███████║█████╗  ██║     ██║                       ║
║    ╚════██║██╔══██║██╔══╝  ██║     ██║                       ║
║    ███████║██║  ██║███████╗███████╗███████╗                  ║
║    ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝                  ║
║                                                               ║
║         INSTALADOR E CONFIGURADOR DE APLICAÇÕES              ║
║                     Sistema Linux                            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${COLOR_RESET}"
}

# Exibir informações do sistema
show_system_info() {
    detect_distro
    local hostname=$(get_hostname)
    local ip=$(get_ip_address)
    
    echo -e "${COLOR_WHITE}Sistema:${COLOR_RESET} $DISTRO_NAME $DISTRO_VERSION"
    echo -e "${COLOR_WHITE}Hostname:${COLOR_RESET} $hostname"
    echo -e "${COLOR_WHITE}IP:${COLOR_RESET} $ip"
    echo ""
}

# Exibir menu principal
show_main_menu() {
    echo -e "${COLOR_MAGENTA}╔═══════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_MAGENTA}║${COLOR_RESET}              ${COLOR_WHITE}MENU PRINCIPAL${COLOR_RESET}                    ${COLOR_MAGENTA}║${COLOR_RESET}"
    echo -e "${COLOR_MAGENTA}╚═══════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    echo -e "  ${COLOR_GREEN}1${COLOR_RESET}) ${COLOR_CYAN}Instalar Zabbix Agent${COLOR_RESET}"
    echo -e "     Instala e configura o agente Zabbix"
    echo ""
    echo -e "  ${COLOR_GREEN}2${COLOR_RESET}) ${COLOR_CYAN}Configurar Hostname${COLOR_RESET}"
    echo -e "     Altera o nome do host do sistema"
    echo ""
    echo -e "  ${COLOR_GREEN}3${COLOR_RESET}) ${COLOR_CYAN}Instalar Wazuh Agent${COLOR_RESET}"
    echo -e "     Instala e configura o agente Wazuh"
    echo ""
    echo -e "  ${COLOR_GREEN}4${COLOR_RESET}) ${COLOR_CYAN}Instalar Sophos${COLOR_RESET}"
    echo -e "     Executa o instalador oficial da Sophos"
    echo ""
    echo -e "  ${COLOR_GREEN}5${COLOR_RESET}) ${COLOR_CYAN}Registrar no Domínio${COLOR_RESET}"
    echo -e "     Integra o sistema ao domínio via SSSD/Realmd"
    echo ""
    echo -e "  ${COLOR_GREEN}6${COLOR_RESET}) ${COLOR_CYAN}Executar Tudo (Modo Completo)${COLOR_RESET}"
    echo -e "     Executa todas as instalações sequencialmente"
    echo ""
    echo -e "  ${COLOR_YELLOW}7${COLOR_RESET}) ${COLOR_CYAN}Configurações${COLOR_RESET}"
    echo -e "     Editar configurações do instalador"
    echo ""
    echo -e "  ${COLOR_YELLOW}8${COLOR_RESET}) ${COLOR_CYAN}Ver Logs${COLOR_RESET}"
    echo -e "     Visualizar logs de instalação"
    echo ""
    echo -e "  ${COLOR_RED}0${COLOR_RESET}) ${COLOR_RED}Sair${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BLUE}───────────────────────────────────────────────────${COLOR_RESET}"
}

# Executar instalação do Zabbix
run_zabbix_install() {
    print_header "Instalação do Zabbix Agent"
    
    if [ -f "$SCRIPT_DIR/install_zabbix.sh" ]; then
        bash "$SCRIPT_DIR/install_zabbix.sh"
    else
        print_error "Script install_zabbix.sh não encontrado"
        return 1
    fi
    
    pause_for_user
}

# Executar configuração de hostname
run_hostname_config() {
    print_header "Configuração de Hostname"
    
    if [ -f "$SCRIPT_DIR/hostname.sh" ]; then
        bash "$SCRIPT_DIR/hostname.sh"
    else
        print_error "Script hostname.sh não encontrado"
        return 1
    fi
    
    pause_for_user
}

# Executar instalação do Wazuh
run_wazuh_install() {
    print_header "Instalação do Wazuh Agent"
    
    if [ -f "$SCRIPT_DIR/install_wazuh.sh" ]; then
        bash "$SCRIPT_DIR/install_wazuh.sh"
    else
        print_error "Script install_wazuh.sh não encontrado"
        return 1
    fi
    
    pause_for_user
}

# Executar instalação do Sophos
run_sophos_install() {
    print_header "Instalação do Sophos"
    
    if [ -f "$SCRIPT_DIR/SophosSetup.sh" ]; then
        bash "$SCRIPT_DIR/SophosSetup.sh"
    else
        print_error "Script SophosSetup.sh não encontrado"
        return 1
    fi
    
    pause_for_user
}

# Executar registro no domínio
run_domain_register() {
    print_header "Registro no Domínio"
    
    if [ -f "$SCRIPT_DIR/register_domain.sh" ]; then
        bash "$SCRIPT_DIR/register_domain.sh"
    else
        print_error "Script register_domain.sh não encontrado"
        return 1
    fi
    
    pause_for_user
}

# Executar modo completo
run_full_installation() {
    print_header "Modo de Instalação Completa"
    
    print_warning "Esta opção executará todas as instalações sequencialmente:"
    echo "  1. Configuração de Hostname"
    echo "  2. Instalação do Zabbix Agent"
    echo "  3. Instalação do Wazuh Agent"
    echo "  4. Instalação do Sophos"
    echo "  5. Registro no Domínio"
    echo ""
    
    if ! prompt_confirm "Deseja continuar com a instalação completa?"; then
        print_info "Instalação completa cancelada"
        pause_for_user
        return 0
    fi
    
    local failed=0
    
    # 1. Hostname
    print_separator
    print_info "Passo 1/5: Configuração de Hostname"
    if run_hostname_config; then
        print_success "Hostname configurado"
    else
        print_error "Falha na configuração do hostname"
        failed=$((failed + 1))
    fi
    
    # 2. Zabbix
    print_separator
    print_info "Passo 2/5: Instalação do Zabbix"
    if [ -f "$SCRIPT_DIR/install_zabbix.sh" ]; then
        bash "$SCRIPT_DIR/install_zabbix.sh"
        if [ $? -eq 0 ]; then
            print_success "Zabbix instalado"
        else
            print_error "Falha na instalação do Zabbix"
            failed=$((failed + 1))
        fi
    fi
    
    # 3. Wazuh
    print_separator
    print_info "Passo 3/5: Instalação do Wazuh"
    if [ -f "$SCRIPT_DIR/install_wazuh.sh" ]; then
        bash "$SCRIPT_DIR/install_wazuh.sh"
        if [ $? -eq 0 ]; then
            print_success "Wazuh instalado"
        else
            print_error "Falha na instalação do Wazuh"
            failed=$((failed + 1))
        fi
    fi
    
    # 4. Sophos
    print_separator
    print_info "Passo 4/5: Instalação do Sophos"
    if prompt_confirm "Deseja instalar o Sophos?"; then
        if [ -f "$SCRIPT_DIR/SophosSetup.sh" ]; then
            bash "$SCRIPT_DIR/SophosSetup.sh"
            if [ $? -eq 0 ]; then
                print_success "Sophos instalado"
            else
                print_error "Falha na instalação do Sophos"
                failed=$((failed + 1))
            fi
        fi
    else
        print_info "Instalação do Sophos pulada"
    fi
    
    # 5. Domínio
    print_separator
    print_info "Passo 5/5: Registro no Domínio"
    if prompt_confirm "Deseja registrar no domínio?"; then
        if [ -f "$SCRIPT_DIR/register_domain.sh" ]; then
            bash "$SCRIPT_DIR/register_domain.sh"
            if [ $? -eq 0 ]; then
                print_success "Sistema registrado no domínio"
            else
                print_error "Falha no registro no domínio"
                failed=$((failed + 1))
            fi
        fi
    else
        print_info "Registro no domínio pulado"
    fi
    
    # Resumo
    print_separator
    print_header "Resumo da Instalação Completa"
    
    if [ $failed -eq 0 ]; then
        print_success "Todas as instalações foram concluídas com sucesso!"
    else
        print_warning "$failed operação(ões) falharam"
        print_info "Verifique os logs para mais detalhes"
    fi
    
    pause_for_user
}

# Editar configurações
edit_settings() {
    print_header "Configurações"
    
    local config_file="$SCRIPT_DIR/config/settings.conf"
    
    if [ ! -f "$config_file" ]; then
        print_error "Arquivo de configuração não encontrado: $config_file"
        pause_for_user
        return 1
    fi
    
    print_info "Abrindo arquivo de configuração..."
    print_warning "Edite com cuidado! Configurações incorretas podem causar falhas."
    echo ""
    
    # Detectar editor disponível
    local editor=""
    if command -v nano &>/dev/null; then
        editor="nano"
    elif command -v vim &>/dev/null; then
        editor="vim"
    elif command -v vi &>/dev/null; then
        editor="vi"
    else
        print_error "Nenhum editor de texto encontrado (nano, vim, vi)"
        pause_for_user
        return 1
    fi
    
    print_info "Usando editor: $editor"
    echo "Pressione Enter para continuar..."
    read
    
    $editor "$config_file"
    
    print_success "Configurações salvas"
    pause_for_user
}

# Visualizar logs
view_logs() {
    print_header "Logs de Instalação"
    
    local log_dir="$SCRIPT_DIR/logs"
    
    if [ ! -d "$log_dir" ]; then
        print_error "Diretório de logs não encontrado: $log_dir"
        pause_for_user
        return 1
    fi
    
    # Listar arquivos de log
    local logs=($(ls -t "$log_dir"/*.log 2>/dev/null))
    
    if [ ${#logs[@]} -eq 0 ]; then
        print_info "Nenhum log encontrado"
        pause_for_user
        return 0
    fi
    
    print_info "Logs disponíveis:"
    echo ""
    
    local i=1
    for log in "${logs[@]}"; do
        local filename=$(basename "$log")
        local size=$(du -h "$log" | cut -f1)
        local date=$(stat -c %y "$log" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
        echo "  $i) $filename ($size) - $date"
        i=$((i + 1))
    done
    
    echo ""
    echo "  0) Voltar"
    echo ""
    
    local choice
    read -rp "Selecione um log para visualizar: " choice
    
    if [ "$choice" = "0" ]; then
        return 0
    fi
    
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#logs[@]}" ]; then
        local selected_log="${logs[$((choice - 1))]}"
        print_info "Exibindo: $(basename "$selected_log")"
        echo ""
        
        if command -v less &>/dev/null; then
            less "$selected_log"
        else
            more "$selected_log"
        fi
    else
        print_error "Opção inválida"
    fi
    
    pause_for_user
}

# Pausar para o usuário ler a saída
pause_for_user() {
    echo ""
    echo -e "${COLOR_YELLOW}Pressione Enter para continuar...${COLOR_RESET}"
    read
}

# Processar escolha do menu
process_menu_choice() {
    local choice="$1"
    
    case "$choice" in
        1)
            run_zabbix_install
            ;;
        2)
            run_hostname_config
            ;;
        3)
            run_wazuh_install
            ;;
        4)
            run_sophos_install
            ;;
        5)
            run_domain_register
            ;;
        6)
            run_full_installation
            ;;
        7)
            edit_settings
            ;;
        8)
            view_logs
            ;;
        0)
            print_info "Saindo..."
            exit 0
            ;;
        *)
            print_error "Opção inválida: $choice"
            pause_for_user
            ;;
    esac
}

#==============================================================================
# Função Principal
#==============================================================================

main() {
    # Inicializar logging
    init_logging
    
    # Verificar root
    check_root
    
    # Loop principal do menu
    while true; do
        show_banner
        show_system_info
        show_main_menu
        
        local choice
        read -rp "$(echo -e ${COLOR_GREEN}Digite sua escolha: ${COLOR_RESET})" choice
        
        echo ""
        process_menu_choice "$choice"
    done
}

# Executar
main "$@"

