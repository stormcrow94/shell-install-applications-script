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
            echo "sssd realmd oddjob oddjob-mkhomedir adcli samba-common-bin krb5-user ldap-utils expect"
            ;;
        rhel|centos|rocky|almalinux)
            echo "sssd realmd oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation openldap-clients expect"
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

# Verificar pré-requisitos de rede
check_domain_prerequisites() {
    local domain="$1"
    local all_ok=true
    
    print_info "Verificando pré-requisitos..."
    log_info "Verificando pré-requisitos para ingresso no domínio"
    
    # Verificar DNS
    print_info "Verificando configuração de DNS..."
    if host "$domain" > /dev/null 2>&1 || nslookup "$domain" > /dev/null 2>&1; then
        print_success "DNS configurado corretamente para $domain"
        log_success "DNS verificado: OK"
    else
        print_error "Falha ao resolver o domínio $domain via DNS"
        print_warning "Verifique o arquivo /etc/resolv.conf"
        log_error "Falha na resolução DNS do domínio"
        all_ok=false
    fi
    
    # Verificar se NTP/Timesyncd está ativo (importante para Kerberos)
    print_info "Verificando sincronização de tempo..."
    if systemctl is-active --quiet systemd-timesyncd || systemctl is-active --quiet ntpd || systemctl is-active --quiet chronyd; then
        print_success "Serviço de sincronização de tempo está ativo"
        log_success "Sincronização de tempo: OK"
    else
        print_warning "Nenhum serviço de sincronização de tempo detectado"
        print_warning "A dessincronização de tempo pode causar falhas no Kerberos"
        log_warning "Serviço de sincronização de tempo não detectado"
        # Não marcar como erro crítico, apenas aviso
    fi
    
    # Verificar portas necessárias (se tiver nc/netcat)
    if command -v nc > /dev/null 2>&1 || command -v netcat > /dev/null 2>&1; then
        print_info "Verificando conectividade com portas do domínio..."
        local domain_ip=$(host "$domain" 2>/dev/null | grep "has address" | head -1 | awk '{print $NF}')
        
        if [ -n "$domain_ip" ]; then
            # Testar porta Kerberos (88)
            if timeout 2 bash -c "echo > /dev/tcp/$domain_ip/88" 2>/dev/null; then
                print_success "Porta 88 (Kerberos) acessível"
                log_success "Porta 88 acessível"
            else
                print_warning "Porta 88 (Kerberos) pode estar bloqueada"
                log_warning "Porta 88 inacessível"
            fi
            
            # Testar porta LDAP (389)
            if timeout 2 bash -c "echo > /dev/tcp/$domain_ip/389" 2>/dev/null; then
                print_success "Porta 389 (LDAP) acessível"
                log_success "Porta 389 acessível"
            else
                print_warning "Porta 389 (LDAP) pode estar bloqueada"
                log_warning "Porta 389 inacessível"
            fi
        fi
    fi
    
    print_separator
    
    if [ "$all_ok" = true ]; then
        return 0
    else
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
        USERNAME=$(prompt_user "Digite o usuário administrador do domínio (apenas o nome, sem @dominio)")
    fi
    
    validate_not_empty "$USERNAME" "Usuário" || return 1
    
    # Normalizar usuário - remover domínio se foi incluído
    if [[ "$USERNAME" == *"@"* ]]; then
        print_warning "Detectado '@' no nome de usuário. Extraindo apenas o nome..."
        # Extrair apenas a parte antes do @
        USERNAME="${USERNAME%%@*}"
        print_info "Usando nome de usuário: $USERNAME"
        log_info "Nome de usuário normalizado: $USERNAME"
    fi
    
    log_info "Usuário informado: $USERNAME"
    
    # Senha
    PASSWORD=$(prompt_password "Digite a senha do usuário $USERNAME")
    validate_not_empty "$PASSWORD" "Senha" || return 1
    
    # Log do comprimento da senha (sem revelar a senha)
    local pass_length=${#PASSWORD}
    log_info "Senha capturada (comprimento: $pass_length caracteres)"
    
    # Verificar se senha tem caracteres especiais
    if [[ "$PASSWORD" =~ [^a-zA-Z0-9] ]]; then
        print_info "Senha contém caracteres especiais (tratamento especial será aplicado)"
        log_info "Senha contém caracteres especiais"
    fi
    
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

# Testar credenciais com Kerberos
test_kerberos_auth() {
    local domain="$1"
    local username="$2"
    local password="$3"
    
    print_info "Testando autenticação Kerberos..."
    log_info "Testando credenciais com kinit"
    
    # Converter domínio para uppercase para Kerberos
    local realm=$(echo "$domain" | tr '[:lower:]' '[:upper:]')
    
    # Tentar diferentes formatos de usuário
    local formats=(
        "${username}@${realm}"
        "${username}"
        "${username}@${domain}"
    )
    
    for user_format in "${formats[@]}"; do
        print_info "Testando formato: $user_format"
        log_info "Tentando kinit com formato: $user_format"
        
        # Método 1: Usar arquivo temporário (mais confiável para senhas com caracteres especiais)
        local temp_pass=$(mktemp)
        chmod 600 "$temp_pass"
        # Usar printf com %s para evitar interpretação de caracteres especiais
        printf '%s\n' "$password" > "$temp_pass"
        
        if kinit "$user_format" < "$temp_pass" >> "$LOG_FILE" 2>&1; then
            rm -f "$temp_pass"
            print_success "Autenticação Kerberos bem-sucedida com $user_format"
            log_success "Autenticação Kerberos OK: $user_format"
            
            # Limpar ticket
            kdestroy >> "$LOG_FILE" 2>&1
            
            # Retornar o formato que funcionou
            echo "$user_format"
            return 0
        fi
        
        # Método 2: Usar expect (melhor para caracteres especiais)
        if command -v expect > /dev/null 2>&1; then
            # Criar script expect temporário para evitar problemas com caracteres especiais
            local expect_script=$(mktemp)
            cat > "$expect_script" << 'EXPECTEOF'
set timeout 30
set user_format [lindex $argv 0]
set password [lindex $argv 1]
spawn kinit $user_format
expect {
    "Password for *:" { send "$password\r" }
    "Password*:" { send "$password\r" }
    timeout { exit 1 }
}
expect eof
EXPECTEOF
            
            if expect "$expect_script" "$user_format" "$password" >> "$LOG_FILE" 2>&1; then
                rm -f "$temp_pass" "$expect_script"
                print_success "Autenticação Kerberos bem-sucedida com $user_format"
                log_success "Autenticação Kerberos OK: $user_format (método expect)"
                
                # Limpar ticket
                kdestroy >> "$LOG_FILE" 2>&1
                
                # Retornar o formato que funcionou
                echo "$user_format"
                return 0
            fi
            rm -f "$expect_script"
        fi
        
        rm -f "$temp_pass"
    done
    
    # Se nenhum formato funcionou
    print_error "Falha na autenticação Kerberos com todos os formatos testados"
    log_error "Falha na autenticação Kerberos"
    
    # Mostrar erro do kinit
    print_warning "Detalhes do erro de autenticação:"
    tail -n 10 "$LOG_FILE" | grep -i "error\|fail\|incorrect\|password" | while read -r line; do
        echo "  $line"
    done
    
    print_separator
    print_warning "DIAGNÓSTICO:"
    echo "  O erro 'Password incorrect' pode significar:"
    echo "  1. A senha contém caracteres especiais problemáticos"
    echo "  2. O usuário '$username' não existe no domínio"
    echo "  3. O usuário está bloqueado/desabilitado"
    echo "  4. O usuário não tem permissões para autenticar via Kerberos"
    echo ""
    
    # Tentar verificar se o usuário existe via LDAP
    print_info "Verificando se o usuário existe no Active Directory..."
    local dc_components=""
    IFS='.' read -ra ADDR <<< "$domain"
    for i in "${ADDR[@]}"; do
        dc_components="${dc_components}DC=$i,"
    done
    dc_components="${dc_components%,}"
    
    if ldapsearch -x -H ldap://$domain -b "$dc_components" "(sAMAccountName=$username)" sAMAccountName >> "$LOG_FILE" 2>&1; then
        if grep -q "sAMAccountName: $username" "$LOG_FILE"; then
            print_success "Usuário '$username' foi encontrado no Active Directory"
            log_info "Usuário existe no AD"
            echo ""
            print_error "O usuário existe, mas não consegue autenticar!"
            print_warning "Isso geralmente significa:"
            echo "  • O usuário NÃO TEM PERMISSÃO para adicionar computadores ao domínio"
            echo "  • Use um usuário com privilégios de Domain Admin"
        else
            print_error "Usuário '$username' NÃO foi encontrado no Active Directory"
            log_error "Usuário não existe no AD"
        fi
    fi
    
    echo ""
    print_info "SUGESTÕES:"
    echo "  • Use o usuário 'Administrator' que tem todas as permissões"
    echo "  • OU peça ao administrador do domínio para:"
    echo "    - Adicionar o usuário '$username' ao grupo Domain Admins"
    echo "    - Dar permissão explícita para adicionar computadores ao domínio"
    
    return 1
}

# Ingressar no domínio
join_domain() {
    print_info "Ingressando no domínio $DOMAIN..."
    log_info "Iniciando ingresso no domínio: $DOMAIN"
    
    # Verificar se o domínio é acessível primeiro
    print_info "Verificando descoberta do domínio..."
    if realm discover "$DOMAIN" >> "$LOG_FILE" 2>&1; then
        print_success "Domínio descoberto com sucesso"
        log_success "Domínio $DOMAIN descoberto"
    else
        print_error "Não foi possível descobrir o domínio $DOMAIN"
        log_error "Falha na descoberta do domínio"
        print_warning "Verifique:"
        echo "  - Configuração de DNS"
        echo "  - Conectividade de rede com o domínio"
        return 1
    fi
    
    print_separator
    
    # Testar autenticação Kerberos antes de tentar ingressar
    local working_user_format
    working_user_format=$(test_kerberos_auth "$DOMAIN" "$USERNAME" "$PASSWORD")
    
    if [ $? -ne 0 ]; then
        print_error "O teste de autenticação Kerberos falhou"
        print_separator
        
        # Perguntar se quer tentar mesmo assim
        print_warning "OPÇÕES:"
        echo "  1. Abortar e verificar as credenciais"
        echo "  2. Tentar continuar mesmo assim (pode funcionar com alguns ADs)"
        echo ""
        
        if prompt_confirm "Deseja tentar continuar mesmo assim? (NÃO RECOMENDADO)"; then
            print_warning "Continuando sem validação Kerberos..."
            log_warning "Usuário optou por continuar sem validação Kerberos"
        else
            print_info "Operação abortada. Verifique:"
            echo "  • Use o usuário 'Administrator' em vez de '$USERNAME'"
            echo "  • Confirme que o usuário tem privilégios de Domain Admin"
            echo "  • Teste a senha fazendo login em uma máquina Windows"
            log_info "Operação abortada pelo usuário após falha Kerberos"
            return 1
        fi
    fi
    
    print_separator
    
    # Passar senha via stdin de forma mais robusta
    print_info "Tentando ingressar no domínio..."
    log_info "Usando formato de usuário: $USERNAME"
    
    # Criar arquivo temporário para senha (mais seguro e confiável para caracteres especiais)
    local temp_pass_file=$(mktemp)
    chmod 600 "$temp_pass_file"
    # Usar printf com aspas simples para evitar interpretação de caracteres especiais
    printf '%s\n' "$PASSWORD" > "$temp_pass_file"
    
    log_info "Arquivo temporário criado para senha"
    log_info "Tamanho do arquivo: $(wc -c < "$temp_pass_file") bytes"
    
    # Método 1: realm join com arquivo temporário
    print_info "Método 1: realm join com arquivo..."
    log_info "Executando: realm join --user=$USERNAME $DOMAIN --verbose"
    
    if realm join --user="$USERNAME" "$DOMAIN" --verbose < "$temp_pass_file" >> "$LOG_FILE" 2>&1; then
        rm -f "$temp_pass_file"
        print_success "Computador registrado no domínio com sucesso"
        log_success "Ingresso no domínio realizado com sucesso (método 1)"
        return 0
    else
        local exit_code=$?
        log_error "Método 1 falhou com código: $exit_code"
    fi
    
    # Método 2: adcli com stdin (geralmente funciona melhor com caracteres especiais)
    log_warning "Tentando método 2..."
    print_info "Método 2: adcli com arquivo..."
    log_info "Executando: adcli join --domain=$DOMAIN --login-user=$USERNAME --stdin-password"
    
    if adcli join --domain="$DOMAIN" --login-user="$USERNAME" --stdin-password -v < "$temp_pass_file" >> "$LOG_FILE" 2>&1; then
        rm -f "$temp_pass_file"
        print_success "Computador registrado no domínio com sucesso"
        log_success "Ingresso no domínio realizado com sucesso (método 2 - adcli)"
        
        # Configurar realm após adcli
        realm list >> "$LOG_FILE" 2>&1
        return 0
    else
        log_error "Método 2 falhou com código: $?"
    fi
    
    # Método 3: expect com realm join (melhor para caracteres especiais complexos)
    if command -v expect > /dev/null 2>&1; then
        log_warning "Tentando método 3 com expect..."
        print_info "Método 3: realm join com expect..."
        
        # Criar script expect para evitar problemas com caracteres especiais
        local expect_script=$(mktemp)
        cat > "$expect_script" << 'EXPECTEOF'
set timeout 120
set username [lindex $argv 0]
set domain [lindex $argv 1]
set password [lindex $argv 2]

spawn realm join --user=$username $domain --verbose
expect {
    "Password for *:" { send "$password\r" }
    "Password*:" { send "$password\r" }
    timeout { 
        puts "Timeout esperando prompt de senha"
        exit 1 
    }
}
expect {
    eof { exit 0 }
    timeout { exit 1 }
}
EXPECTEOF
        
        if expect "$expect_script" "$USERNAME" "$DOMAIN" "$PASSWORD" >> "$LOG_FILE" 2>&1; then
            rm -f "$temp_pass_file" "$expect_script"
            print_success "Computador registrado no domínio com sucesso"
            log_success "Ingresso no domínio realizado com sucesso (método 3 - expect realm)"
            return 0
        else
            log_error "Método 3 falhou com código: $?"
        fi
        rm -f "$expect_script"
    fi
    
    # Método 4: expect com adcli
    if command -v expect > /dev/null 2>&1; then
        log_warning "Tentando método 4 com expect e adcli..."
        print_info "Método 4: adcli com expect..."
        
        local expect_script_adcli=$(mktemp)
        cat > "$expect_script_adcli" << 'EXPECTEOF'
set timeout 120
set username [lindex $argv 0]
set domain [lindex $argv 1]
set password [lindex $argv 2]

spawn adcli join --domain=$domain --login-user=$username -v
expect {
    "Password for *:" { send "$password\r" }
    "Password*:" { send "$password\r" }
    timeout { 
        puts "Timeout esperando prompt de senha"
        exit 1 
    }
}
expect {
    eof { exit 0 }
    timeout { exit 1 }
}
EXPECTEOF
        
        if expect "$expect_script_adcli" "$USERNAME" "$DOMAIN" "$PASSWORD" >> "$LOG_FILE" 2>&1; then
            rm -f "$temp_pass_file" "$expect_script_adcli"
            print_success "Computador registrado no domínio com sucesso"
            log_success "Ingresso no domínio realizado com sucesso (método 4 - expect adcli)"
            
            # Configurar realm após adcli
            realm list >> "$LOG_FILE" 2>&1
            return 0
        else
            log_error "Método 4 falhou com código: $?"
        fi
        rm -f "$expect_script_adcli"
    fi
    
    rm -f "$temp_pass_file"
    
    # Se todos falharam
    print_error "Falha ao ingressar no domínio"
    log_error "Falha no ingresso no domínio - todos os métodos falharam"
    
    # Exibir últimas linhas do log para diagnóstico
    print_warning "Últimas mensagens de erro:"
    tail -n 15 "$LOG_FILE" | grep -i "error\|fail\|denied\|couldn't" | while read -r line; do
        echo "  $line"
    done
    
    # Exibir possíveis causas
    print_warning "Possíveis causas:"
    echo "  - Usuário não tem permissão para adicionar computadores ao domínio"
    echo "  - Limite de computadores no domínio atingido"
    echo "  - Nome do computador já existe no domínio"
    echo "  - Política de grupo bloqueando o ingresso"
    echo "  - Versão incompatível do protocolo"
    
    print_separator
    print_info "Dica: Tente usar um usuário com privilégios de Domain Admin"
    print_info "Ou peça ao administrador para criar permissões específicas"
    
    return 1
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
    
    # Verificar pré-requisitos de rede e configuração
    if ! check_domain_prerequisites "$DOMAIN"; then
        print_error "Alguns pré-requisitos não foram atendidos"
        if ! prompt_confirm "Deseja continuar mesmo assim?"; then
            print_warning "Operação cancelada"
            log_info "Operação cancelada devido a falha nos pré-requisitos"
            exit 1
        fi
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

