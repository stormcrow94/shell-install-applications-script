#!/bin/bash

#==============================================================================
# Biblioteca de Funções Comuns
# Funções compartilhadas entre todos os scripts do instalador
#==============================================================================

# Cores para output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[1;37m'
readonly COLOR_RESET='\033[0m'

# Símbolos
readonly SYMBOL_SUCCESS="✓"
readonly SYMBOL_ERROR="✗"
readonly SYMBOL_WARNING="⚠"
readonly SYMBOL_INFO="ℹ"

#==============================================================================
# Funções de Output
#==============================================================================

# Função para imprimir mensagens de sucesso
print_success() {
    echo -e "${COLOR_GREEN}${SYMBOL_SUCCESS} $1${COLOR_RESET}"
}

# Função para imprimir mensagens de erro
print_error() {
    echo -e "${COLOR_RED}${SYMBOL_ERROR} $1${COLOR_RESET}" >&2
}

# Função para imprimir mensagens de aviso
print_warning() {
    echo -e "${COLOR_YELLOW}${SYMBOL_WARNING} $1${COLOR_RESET}"
}

# Função para imprimir mensagens informativas
print_info() {
    echo -e "${COLOR_CYAN}${SYMBOL_INFO} $1${COLOR_RESET}"
}

# Função para imprimir cabeçalhos
print_header() {
    echo -e "\n${COLOR_MAGENTA}================================${COLOR_RESET}"
    echo -e "${COLOR_MAGENTA}  $1${COLOR_RESET}"
    echo -e "${COLOR_MAGENTA}================================${COLOR_RESET}\n"
}

# Função para imprimir separadores
print_separator() {
    echo -e "${COLOR_BLUE}────────────────────────────────${COLOR_RESET}"
}

#==============================================================================
# Funções de Logging
#==============================================================================

# Diretório de logs
# Se SCRIPT_DIR está definido, usa ele, senão tenta detectar
if [ -n "$SCRIPT_DIR" ]; then
    LOG_DIR="$SCRIPT_DIR/logs"
else
    LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/logs"
fi
LOG_FILE="${LOG_DIR}/installer_$(date +%Y%m%d_%H%M%S).log"

# Inicializar logging
init_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    log_info "Início da execução: $(date)"
}

# Função para logar mensagens
log_message() {
    local level="$1"
    shift
    local message="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# Funções de log por nível
log_info() {
    log_message "INFO" "$@"
}

log_success() {
    log_message "SUCCESS" "$@"
}

log_warning() {
    log_message "WARNING" "$@"
}

log_error() {
    log_message "ERROR" "$@"
}

#==============================================================================
# Funções de Validação
#==============================================================================

# Verificar se o script está sendo executado como root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Este script deve ser executado como root ou com sudo"
        log_error "Tentativa de execução sem privilégios de root"
        exit 1
    fi
    log_info "Verificação de root: OK"
}

# Verificar conexão com a internet
check_internet() {
    print_info "Verificando conexão com a internet..."
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_success "Conexão com a internet: OK"
        log_success "Conexão com internet verificada"
        return 0
    else
        print_error "Sem conexão com a internet"
        log_error "Falha na verificação de conexão com internet"
        return 1
    fi
}

# Validar formato de IP
validate_ip() {
    local ip=$1
    local valid_ip_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    if [[ $ip =~ $valid_ip_regex ]]; then
        # Verificar se cada octeto está entre 0 e 255
        local IFS='.'
        local -a octets=($ip)
        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Validar se uma string não está vazia
validate_not_empty() {
    local value="$1"
    local field_name="$2"
    
    if [ -z "$value" ]; then
        print_error "$field_name não pode estar vazio"
        return 1
    fi
    return 0
}

#==============================================================================
# Funções de Detecção de Sistema
#==============================================================================

# Detectar a distribuição Linux
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_VERSION=$VERSION_ID
        DISTRO_NAME=$NAME
    else
        print_error "Não foi possível detectar a distribuição Linux"
        log_error "Falha ao detectar distribuição (arquivo /etc/os-release não encontrado)"
        exit 1
    fi
    
    log_info "Distribuição detectada: $DISTRO_NAME (versão $DISTRO_VERSION)"
}

# Obter o gerenciador de pacotes apropriado
get_package_manager() {
    detect_distro
    
    case "$DISTRO" in
        ubuntu|debian)
            echo "apt"
            ;;
        rhel|centos|rocky|almalinux)
            if [ "${DISTRO_VERSION%%.*}" -ge 8 ]; then
                echo "dnf"
            else
                echo "yum"
            fi
            ;;
        fedora)
            echo "dnf"
            ;;
        *)
            print_error "Distribuição não suportada: $DISTRO"
            log_error "Distribuição não suportada: $DISTRO"
            exit 1
            ;;
    esac
}

#==============================================================================
# Funções de Gerenciamento de Pacotes
#==============================================================================

# Verificar se um pacote está instalado
is_package_installed() {
    local package=$1
    local pkg_manager=$(get_package_manager)
    
    case "$pkg_manager" in
        apt)
            dpkg -l "$package" 2>/dev/null | grep -q "^ii"
            ;;
        dnf|yum)
            rpm -q "$package" &>/dev/null
            ;;
    esac
}

# Instalar um pacote
install_package() {
    local package=$1
    local pkg_manager=$(get_package_manager)
    
    if is_package_installed "$package"; then
        print_info "$package já está instalado"
        log_info "Pacote $package já instalado"
        return 0
    fi
    
    print_info "Instalando $package..."
    log_info "Iniciando instalação do pacote: $package"
    
    case "$pkg_manager" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" >> "$LOG_FILE" 2>&1
            ;;
        dnf)
            dnf install -y "$package" >> "$LOG_FILE" 2>&1
            ;;
        yum)
            yum install -y "$package" >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_success "$package instalado com sucesso"
        log_success "Pacote $package instalado com sucesso"
        return 0
    else
        print_error "Falha ao instalar $package"
        log_error "Falha ao instalar pacote: $package"
        return 1
    fi
}

# Instalar múltiplos pacotes
install_packages() {
    local -a packages=("$@")
    local failed=0
    
    for package in "${packages[@]}"; do
        if ! install_package "$package"; then
            failed=$((failed + 1))
        fi
    done
    
    return $failed
}

# Atualizar repositórios
update_repositories() {
    local pkg_manager=$(get_package_manager)
    
    print_info "Atualizando repositórios..."
    log_info "Atualizando repositórios do sistema"
    
    case "$pkg_manager" in
        apt)
            apt-get update >> "$LOG_FILE" 2>&1
            ;;
        dnf)
            dnf check-update >> "$LOG_FILE" 2>&1 || true
            ;;
        yum)
            yum check-update >> "$LOG_FILE" 2>&1 || true
            ;;
    esac
    
    if [ $? -eq 0 ] || [ $? -eq 100 ]; then
        print_success "Repositórios atualizados"
        log_success "Repositórios atualizados com sucesso"
        return 0
    else
        print_warning "Aviso ao atualizar repositórios"
        log_warning "Aviso ao atualizar repositórios"
        return 1
    fi
}

#==============================================================================
# Funções de Entrada do Usuário
#==============================================================================

# Solicitar entrada do usuário
prompt_user() {
    local prompt_text="$1"
    local default_value="$2"
    local user_input
    
    if [ -n "$default_value" ]; then
        read -rp "$(echo -e ${COLOR_CYAN}$prompt_text [${default_value}]: ${COLOR_RESET})" user_input
        user_input=${user_input:-$default_value}
    else
        read -rp "$(echo -e ${COLOR_CYAN}$prompt_text: ${COLOR_RESET})" user_input
    fi
    
    echo "$user_input"
}

# Solicitar senha de forma segura
prompt_password() {
    local prompt_text="$1"
    local password
    
    read -rsp "$(echo -e ${COLOR_CYAN}$prompt_text: ${COLOR_RESET})" password
    echo
    echo "$password"
}

# Solicitar confirmação (Sim/Não)
prompt_confirm() {
    local prompt_text="$1"
    local default="${2:-n}"
    local response
    
    if [ "$default" = "y" ]; then
        read -rp "$(echo -e ${COLOR_YELLOW}$prompt_text [S/n]: ${COLOR_RESET})" response
        response=${response:-y}
    else
        read -rp "$(echo -e ${COLOR_YELLOW}$prompt_text [s/N]: ${COLOR_RESET})" response
        response=${response:-n}
    fi
    
    case "$response" in
        [yYsS]|[yY][eE][sS]|[sS][iI][mM])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

#==============================================================================
# Funções de Serviços
#==============================================================================

# Reiniciar um serviço
restart_service() {
    local service_name=$1
    
    print_info "Reiniciando serviço $service_name..."
    log_info "Reiniciando serviço: $service_name"
    
    systemctl restart "$service_name" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Serviço $service_name reiniciado"
        log_success "Serviço $service_name reiniciado com sucesso"
        return 0
    else
        print_error "Falha ao reiniciar $service_name"
        log_error "Falha ao reiniciar serviço: $service_name"
        return 1
    fi
}

# Habilitar serviço na inicialização
enable_service() {
    local service_name=$1
    
    print_info "Habilitando serviço $service_name..."
    log_info "Habilitando serviço: $service_name"
    
    systemctl enable "$service_name" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Serviço $service_name habilitado"
        log_success "Serviço $service_name habilitado na inicialização"
        return 0
    else
        print_error "Falha ao habilitar $service_name"
        log_error "Falha ao habilitar serviço: $service_name"
        return 1
    fi
}

# Verificar status de um serviço
check_service_status() {
    local service_name=$1
    
    if systemctl is-active --quiet "$service_name"; then
        print_success "Serviço $service_name está ativo"
        return 0
    else
        print_error "Serviço $service_name não está ativo"
        return 1
    fi
}

#==============================================================================
# Funções de Backup
#==============================================================================

# Fazer backup de um arquivo
backup_file() {
    local file_path=$1
    local backup_path="${file_path}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$file_path" ]; then
        cp "$file_path" "$backup_path"
        if [ $? -eq 0 ]; then
            print_success "Backup criado: $backup_path"
            log_success "Backup criado: $backup_path"
            return 0
        else
            print_error "Falha ao criar backup de $file_path"
            log_error "Falha ao criar backup: $file_path"
            return 1
        fi
    else
        print_warning "Arquivo não existe: $file_path"
        log_warning "Arquivo não encontrado para backup: $file_path"
        return 1
    fi
}

#==============================================================================
# Funções de Rede
#==============================================================================

# Obter o hostname da máquina
get_hostname() {
    hostname
}

# Obter o endereço IP principal
get_ip_address() {
    hostname -I | awk '{print $1}'
}

# Obter o domínio FQDN
get_fqdn() {
    hostname -f 2>/dev/null || hostname
}

#==============================================================================
# Funções de Limpeza
#==============================================================================

# Limpar arquivo temporário
cleanup_temp_file() {
    local temp_file=$1
    if [ -f "$temp_file" ]; then
        rm -f "$temp_file"
        log_info "Arquivo temporário removido: $temp_file"
    fi
}

# Função de limpeza ao sair
cleanup_on_exit() {
    log_info "Fim da execução: $(date)"
}

#==============================================================================
# Inicialização
#==============================================================================

# Trap para garantir limpeza ao sair
trap cleanup_on_exit EXIT

# Exportar funções para uso em subshells
export -f print_success print_error print_warning print_info print_header print_separator
export -f log_info log_success log_warning log_error
export -f check_root check_internet validate_ip validate_not_empty
export -f detect_distro get_package_manager
export -f is_package_installed install_package install_packages update_repositories
export -f prompt_user prompt_password prompt_confirm
export -f restart_service enable_service check_service_status
export -f backup_file get_hostname get_ip_address get_fqdn

