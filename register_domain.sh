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

# Preferência do cliente: SSSD por padrão
: "${PREFER_SSSD:=true}"

# Forçar reingresso limpo quando detectado estado inconsistente
: "${FORCE_REJOIN_ON_INCONSISTENCY:=true}"

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

# Gerar fallback padrão e único para NetBIOS
generate_fallback_netbios_name() {
    local suffix=""
    
    if [ -r /etc/machine-id ]; then
        suffix=$(tr '[:lower:]' '[:upper:]' < /etc/machine-id | tr -cd 'A-Z0-9' | cut -c1-7)
    fi
    
    if [ -z "$suffix" ]; then
        local ts=$(date +%s 2>/dev/null || echo $$)
        suffix=$(printf "%05d" $((ts % 100000)))
    fi
    
    local fallback="LINUX${suffix}"
    fallback=$(echo "$fallback" | tr -cd 'A-Z0-9')
    fallback=$(echo "$fallback" | cut -c1-15)
    
    if [ -z "$fallback" ]; then
        fallback="LINUXHOST"
    fi
    
    echo "$fallback"
}

# Gerar nome de computador compatível com NetBIOS (max 15 caracteres)
generate_computer_name() {
    local base_name
    
    if [ -n "$DOMAIN_COMPUTER_NAME" ]; then
        base_name="$DOMAIN_COMPUTER_NAME"
        print_info "Usando nome do computador definido em configuração: $base_name"
        log_info "Nome de computador sobrescrito via configuração: $base_name"
    else
        base_name=$(hostname -s 2>/dev/null || hostname)
    fi
    
    local sanitized
    sanitized=$(echo "$base_name" | tr '[:lower:]' '[:upper:]')
    
    local sanitized_chars
    sanitized_chars=$(echo "$sanitized" | tr -cd 'A-Z0-9-')
    if [ "$sanitized_chars" != "$sanitized" ]; then
        print_warning "Nome '$base_name' contém caracteres não suportados. Será usado '$sanitized_chars' após limpeza."
        log_warning "Nome '$base_name' teve caracteres inválidos removidos. Resultado: $sanitized_chars"
    fi
    sanitized="$sanitized_chars"
    
    local sanitized_trimmed
    sanitized_trimmed=$(echo "$sanitized" | sed 's/^-*//; s/-*$//')
    if [ "$sanitized_trimmed" != "$sanitized" ]; then
        print_warning "Nome '$base_name' possui hífens inválidos no início/fim. Será usado '$sanitized_trimmed'."
        log_warning "Nome '$base_name' teve hífens nas bordas removidos. Resultado: $sanitized_trimmed"
    fi
    sanitized="$sanitized_trimmed"
    
    if [ -z "$sanitized" ]; then
        sanitized=$(generate_fallback_netbios_name)
        print_warning "Hostname atual contém caracteres incompatíveis. Usando padrão '$sanitized'."
        log_warning "Hostname inválido detectado, usando fallback $sanitized"
    fi
    
    if [ "${#sanitized}" -gt 15 ]; then
        local truncated="${sanitized:0:15}"
        truncated=$(echo "$truncated" | sed 's/^-*//; s/-*$//')
        
        if [ -z "$truncated" ]; then
            truncated=$(echo "$sanitized" | tr -d '-' | cut -c1-15)
        fi
        
        if [ -z "$truncated" ]; then
            truncated=$(generate_fallback_netbios_name)
            print_warning "Não foi possível gerar nome válido após truncar. Usando '$truncated'."
        fi
        
        print_warning "Hostname '$base_name' excede 15 caracteres. Será usado '$truncated' no domínio."
        log_warning "Hostname excede 15 caracteres. Truncado para $truncated"
        sanitized="$truncated"
        
        if [ -z "$DOMAIN_COMPUTER_NAME" ]; then
            print_info "Dica: execute ./hostname.sh para definir um nome curto permanente."
        fi
    fi
    
    echo "$sanitized"
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

# Garantir krb5.conf mínimo válido para o domínio (substitui exemplos “MIT/Stanford”)
ensure_krb5_conf() {
    local krb="/etc/krb5.conf"
    local realm_upper
    realm_upper=$(echo "$DOMAIN" | tr '[:lower:]' '[:upper:]')

    if [ ! -f "$krb" ]; then
        print_info "Criando /etc/krb5.conf mínimo para o domínio..."
    else
        # Se contiver exemplos bem conhecidos, substitui
        if grep -qiE "ATHENA\.MIT|stanford\.edu|UTORONTO\.CA|CS\.CMU\.EDU|DEMENTIA\.ORG" "$krb"; then
            print_warning "Detectado krb5.conf de exemplo – será substituído por configuração do seu domínio"
        else
            # Já existe e não parece exemplo – mantém
            return 0
        fi
    fi

    backup_file "$krb" || true
    cat > "$krb" <<EOF
[libdefaults]
  default_realm = ${realm_upper}
  dns_lookup_kdc = true
  dns_lookup_realm = true
  rdns = false
  ticket_lifetime = 24h
  forwardable = true

[domain_realm]
  .${DOMAIN} = ${realm_upper}
  ${DOMAIN} = ${realm_upper}
EOF

    print_success "krb5.conf ajustado para o domínio ${DOMAIN}"
    return 0
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
    
    # Garantir krb5.conf válido antes de qualquer tentativa
    ensure_krb5_conf || true

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
    
    # SKIP Kerberos test - causa múltiplas tentativas e pode bloquear conta no AD
    print_info "Pulando teste Kerberos (evita bloqueio de conta no AD)"
    log_info "Teste Kerberos desabilitado para evitar múltiplas tentativas"
    
    print_separator
    
    # Verificar se já está no domínio e limpar se necessário
    print_info "Verificando registros anteriores..."
    if realm list 2>/dev/null | grep -q "configured:"; then
        print_warning "Sistema já está registrado em um domínio"
        print_info "Removendo registro anterior para fazer nova instalação..."
        
        # Parar serviços primeiro
        systemctl stop sssd >> "$LOG_FILE" 2>&1 || true
        systemctl stop winbind >> "$LOG_FILE" 2>&1 || true
        
        # Sair do domínio
        realm leave >> "$LOG_FILE" 2>&1 || true
        
        # Limpar cache
        rm -rf /var/lib/sss/db/* >> "$LOG_FILE" 2>&1 || true
        rm -rf /var/lib/sss/mc/* >> "$LOG_FILE" 2>&1 || true
        
        print_success "Registro anterior removido"
        log_info "Registro anterior do domínio removido"
        
        # Aguardar propagação
        sleep 2
    fi
    
    # Limpar keytab antigo
    if [ -f /etc/krb5.keytab ]; then
        print_info "Removendo keytab antigo..."
        rm -f /etc/krb5.keytab >> "$LOG_FILE" 2>&1 || true
        log_info "Keytab antigo removido"
    fi
    
    print_separator
    
    # Instalar Samba se necessário (para net ads join)
    if ! command -v net > /dev/null 2>&1; then
        print_info "Instalando Samba para método net ads..."
        install_packages samba smbclient winbind
    fi
    
    # Gerar nome compatível com NetBIOS (15 caracteres)
    local HOSTNAME_SHORT
    HOSTNAME_SHORT=$(generate_computer_name)
    print_info "Nome NetBIOS utilizado: $HOSTNAME_SHORT"
    log_info "Nome NetBIOS definido: $HOSTNAME_SHORT"
    
    # Configurar Samba
    print_info "Configurando Samba..."
    cat > /etc/samba/smb.conf << EOFSMB
[global]
   netbios name = $HOSTNAME_SHORT
   workgroup = ${DOMAIN%%.*}
   security = ads
   realm = ${DOMAIN^^}
   encrypt passwords = yes
   kerberos method = secrets and keytab
   
   idmap config * : backend = tdb
   idmap config * : range = 3000-7999
   idmap config ${DOMAIN%%.*} : backend = rid
   idmap config ${DOMAIN%%.*} : range = 10000-999999
   
   template shell = /bin/bash
   template homedir = /home/%U
   winbind use default domain = true
   winbind offline logon = false
EOFSMB
    
    print_success "Samba configurado"
    log_success "Configuração Samba criada"
    
    # IMPORTANTE: NÃO fazemos pré-validação com kinit para evitar bloqueio de conta no AD
    # Vamos direto para o join com UMA tentativa única
    
    print_separator
    print_info "Iniciando ingresso no domínio (tentativa única)..."
    log_info "NOTA: Não fazemos pré-teste para evitar bloqueio de conta no AD"
    
    # Criar arquivo temporário para senha
    local temp_pass_file=$(mktemp)
    chmod 600 "$temp_pass_file"
    printf '%s\n' "$PASSWORD" > "$temp_pass_file"
    
    # Usar formato simples do username (net ads join geralmente aceita username simples)
    local user_format="$USERNAME"

    # Caminho preferencial: SSSD/adcli via realmd
    if [ "${PREFER_SSSD}" = "true" ]; then
        print_info "Preferindo SSSD/adcli (realmd) para ingresso..."
        log_info "Executando: realm join --client-software=sssd --membership-software=adcli --computer-name=$HOSTNAME_SHORT --user=$user_format $DOMAIN"
        local realm_output_pref=$(mktemp)
        if realm join --client-software=sssd --membership-software=adcli --computer-name="$HOSTNAME_SHORT" --user="$user_format" "$DOMAIN" --verbose < "$temp_pass_file" > "$realm_output_pref" 2>&1; then
            cat "$realm_output_pref" >> "$LOG_FILE"
            rm -f "$temp_pass_file" "$realm_output_pref"
            print_success "✓ Computador registrado no domínio com SSSD"
            log_success "Ingresso no domínio realizado (realm join sssd/adcli)"
            return 0
        else
            cat "$realm_output_pref" >> "$LOG_FILE"
            if grep -qi "Already joined to this domain" "$realm_output_pref"; then
                print_warning "realm join (sssd) reportou: Already joined to this domain"
                log_info "Host já estava no domínio (sssd), tratando como sucesso"
                rm -f "$temp_pass_file" "$realm_output_pref"
                return 0
            fi
            print_warning "realm join (sssd/adcli) falhou, tentando método alternativo com samba/winbind..."
            log_warning "realm join sssd/adcli falhou; fallback para net ads join"
            rm -f "$realm_output_pref"
        fi
    fi

    # Fallback: Tentar ingresso com net ads join (winbind)
    print_info "Ingressando no domínio com 'net ads join' (fallback)..."
    log_info "Executando: net ads join -U $user_format -S $DOMAIN"
    
    if command -v expect > /dev/null 2>&1; then
        # Criar arquivo temporário para senha (mais seguro que passar como argumento)
        local password_file=$(mktemp)
        chmod 600 "$password_file"
        printf '%s' "$PASSWORD" > "$password_file"
        
        local expect_script=$(mktemp)
        cat > "$expect_script" << 'EXPECTEOF'
set timeout 180
set username [lindex $argv 0]
set password_file [lindex $argv 1]
set domain [lindex $argv 2]

# Ler senha do arquivo (evita problemas com caracteres especiais)
set fp [open $password_file r]
set password [read $fp]
close $fp

# Habilitar log detalhado
log_user 1
exp_internal 0

puts "════════════════════════════════════════════"
puts " TENTATIVA DE INGRESSO NO DOMÍNIO"
puts "════════════════════════════════════════════"
puts "Usuário: $username"
puts "Domínio: $domain"
puts ""

spawn net ads join -U $username -S $domain -d 3
expect {
    "*password*:" { 
        puts " → Enviando senha..."
        send -- "$password"
        send "\r"
        exp_continue 
    }
    "*Password*:" { 
        puts " → Enviando senha..."
        send -- "$password"
        send "\r"
        exp_continue 
    }
    "Password for *:" { 
        puts " → Enviando senha..."
        send -- "$password"
        send "\r"
        exp_continue 
    }
    "Joined*to realm*" { 
        puts "\n════════════════════════════════════════════"
        puts " ✓ SUCESSO: Ingressado no realm"
        puts "════════════════════════════════════════════"
        exit 0 
    }
    "Joined*to*domain*" { 
        puts "\n════════════════════════════════════════════"
        puts " ✓ SUCESSO: Ingressado no domínio"
        puts "════════════════════════════════════════════"
        exit 0 
    }
    "Using short domain name*" {
        puts " → Processando ingresso..."
        exp_continue
    }
    "*failed*" { 
        puts "\n════════════════════════════════════════════"
        puts " ✗ FALHA no ingresso"
        puts "════════════════════════════════════════════"
        exit 1 
    }
    "*Failed*" { 
        puts "\n════════════════════════════════════════════"
        puts " ✗ FALHA no ingresso"
        puts "════════════════════════════════════════════"
        exit 1 
    }
    "*denied*" {
        puts "\n════════════════════════════════════════════"
        puts " ✗ ACESSO NEGADO"
        puts "════════════════════════════════════════════"
        exit 1
    }
    "*revoked*" {
        puts "\n════════════════════════════════════════════"
        puts " ✗ CREDENCIAIS REVOGADAS (conta bloqueada)"
        puts "════════════════════════════════════════════"
        exit 2
    }
    timeout { 
        puts "\n════════════════════════════════════════════"
        puts " ✗ TIMEOUT (sem resposta do servidor)"
        puts "════════════════════════════════════════════"
        exit 3 
    }
    eof
}

# Capturar código de saída do processo spawned
set wait_result [wait]

# Expect's wait returns: {pid spawn_id os_error status}
# - If os_error == 0: normal exit, status is exit code
# - If os_error == -1: killed by signal, status is signal number
if {[llength $wait_result] == 4} {
    set os_error [lindex $wait_result 2]
    set status [lindex $wait_result 3]
    
    if {$os_error == 0} {
        # Normal exit - use the exit code
        set exit_status $status
    } elseif {$os_error == -1} {
        # Killed by signal
        puts "\n⚠️  Processo terminado por sinal: $status"
        set exit_status 1
    } else {
        # OS error occurred
        puts "\n⚠️  Erro do sistema: $os_error"
        set exit_status 1
    }
} else {
    # Unexpected wait result format
    puts "\n⚠️  Formato inesperado do wait: $wait_result"
    set exit_status 1
}

puts "\nCódigo de saída: $exit_status"
exit $exit_status
EXPECTEOF
        
        # Capturar saída completa
        local join_output=$(mktemp)
        local exit_code=0
        
        expect "$expect_script" "$user_format" "$password_file" "$DOMAIN" > "$join_output" 2>&1 || exit_code=$?
        
        # Limpar arquivo de senha imediatamente
        rm -f "$password_file"
        
        # Sempre salvar no log
        cat "$join_output" >> "$LOG_FILE"
        
        # Exibir saída no terminal
        cat "$join_output"
        
        if [ $exit_code -eq 0 ]; then
            rm -f "$temp_pass_file" "$expect_script" "$join_output"
            print_success "✓ Computador registrado no domínio com sucesso"
            log_success "Ingresso no domínio realizado com sucesso (net ads join)"
            return 0
        elif [ $exit_code -eq 2 ]; then
            rm -f "$temp_pass_file" "$expect_script" "$join_output"
            print_error "✗ CONTA BLOQUEADA no Active Directory"
            print_separator
            print_warning "SOLUÇÃO:"
            echo "  1. Acesse o Active Directory"
            echo "  2. Desbloqueie a conta '$USERNAME'"
            echo "  3. OU use o usuário 'Administrator'"
            echo ""
            print_info "A conta foi bloqueada por múltiplas tentativas de autenticação"
            log_error "Conta bloqueada no AD (exit code 2)"
            return 1
        elif [ $exit_code -eq 3 ]; then
            rm -f "$temp_pass_file" "$expect_script" "$join_output"
            print_error "✗ TIMEOUT - Servidor não respondeu"
            print_separator
            print_warning "Verifique:"
            echo "  1. Conectividade de rede com o controlador de domínio"
            echo "  2. Firewall não está bloqueando as portas"
            echo "  3. DNS está resolvendo corretamente"
            log_error "Timeout no join (exit code 3)"
            return 1
        else
            print_warning "net ads join falhou (código: $exit_code), tentando realm join..."
            log_warning "net ads join falhou com código $exit_code"
            rm -f "$expect_script" "$join_output"
        fi
    else
        print_warning "Expect não está instalado - usando modo stdin"
        log_warning "Expect indisponível - net ads join via stdin"
        
        local join_output=$(mktemp)
        if printf '%s\n' "$PASSWORD" | net ads join -U "$user_format" --stdinpass -S "$DOMAIN" -d 3 > "$join_output" 2>&1; then
            cat "$join_output" >> "$LOG_FILE"
            cat "$join_output"
            rm -f "$temp_pass_file" "$join_output"
            print_success "✓ Computador registrado no domínio com sucesso"
            log_success "Ingresso no domínio realizado com sucesso (net ads join via stdin)"
            return 0
        else
            cat "$join_output" >> "$LOG_FILE"
            cat "$join_output"
            print_warning "net ads join (stdin) falhou, tentando realm join..."
            log_warning "net ads join via stdin falhou"
            rm -f "$join_output"
        fi
    fi
    
    # Método alternativo: realm join (sem forçar sssd) 
    print_info "Tentando com 'realm join'..."
    log_info "Executando: realm join --computer-name=$HOSTNAME_SHORT --user=$user_format $DOMAIN"
    
    local realm_output=$(mktemp)
    if realm join --computer-name="$HOSTNAME_SHORT" --user="$user_format" "$DOMAIN" --verbose < "$temp_pass_file" > "$realm_output" 2>&1; then
        cat "$realm_output" >> "$LOG_FILE"
        rm -f "$temp_pass_file" "$realm_output"
        print_success "✓ Computador registrado no domínio com sucesso"
        log_success "Ingresso no domínio realizado com sucesso (realm join)"
        return 0
    else
        cat "$realm_output" >> "$LOG_FILE"
        # Tratar caso já ingressado como SUCESSO
        if grep -qi "Already joined to this domain" "$realm_output"; then
            print_warning "realm join reportou: Already joined to this domain"
            log_info "Host já estava no domínio, tratando como sucesso"
            rm -f "$temp_pass_file" "$realm_output"
            return 0
        fi
        print_error "realm join também falhou"
        log_error "realm join falhou, saída:"
        cat "$realm_output" >> "$LOG_FILE"
        rm -f "$realm_output"
    fi
    
    rm -f "$temp_pass_file"
    
    # Se todos falharam
    print_error "✗ Falha ao ingressar no domínio"
    log_error "TODOS OS MÉTODOS FALHARAM (net ads join e realm join)"

    # Tentativa automática de recuperação se estado inconsistente for detectado
    if [ "${FORCE_REJOIN_ON_INCONSISTENCY}" = "true" ]; then
        print_separator
        print_info "Verificando inconsistências (realm diz join, mas sem keytab)..."
        local realm_status="$(realm list 2>/dev/null || true)"
        if echo "$realm_status" | grep -qi "configured:" && { [ ! -f /etc/krb5.keytab ] || [ ! -s /etc/krb5.keytab ]; }; then
            print_warning "Inconsistência detectada: realm indica join, mas o keytab está ausente"
            log_warning "Inconsistência de ingresso: configured sem /etc/krb5.keytab"

            print_info "Executando limpeza automática e nova tentativa de join via SSSD..."
            # Limpeza completa
            systemctl stop sssd winbind >> "$LOG_FILE" 2>&1 || true
            realm leave -v "$DOMAIN" >> "$LOG_FILE" 2>&1 || true
            net ads leave -U "$user_format" >> "$LOG_FILE" 2>&1 || true
            rm -f /etc/krb5.keytab >> "$LOG_FILE" 2>&1 || true
            rm -rf /var/lib/sss/db/* /var/lib/sss/mc/* >> "$LOG_FILE" 2>&1 || true

            # Reescrever krb5.conf mínimo
            ensure_krb5_conf || true

            # Nova tentativa com SSSD/adcli
            local retry_out=$(mktemp)
            if realm join --client-software=sssd --membership-software=adcli \
                --computer-name="$HOSTNAME_SHORT" --user="$user_format" "$DOMAIN" --verbose < <(printf '%s\n' "$PASSWORD") > "$retry_out" 2>&1; then
                cat "$retry_out" >> "$LOG_FILE"
                rm -f "$retry_out"
                print_success "✓ Ingresso corrigido após limpeza automática (SSSD/adcli)"
                log_success "Auto-repair de ingresso bem-sucedido"
                return 0
            else
                cat "$retry_out" >> "$LOG_FILE"
                rm -f "$retry_out"
                print_warning "Recuperação automática falhou; intervenção manual pode ser necessária"
            fi
        fi
    fi
    
    print_separator
    print_warning "════════════════════════════════════════════"
    print_warning " DIAGNÓSTICO COMPLETO"
    print_warning "════════════════════════════════════════════"
    echo ""
    
    # Verificar se pelo menos o keytab foi criado
    if [ -f /etc/krb5.keytab ] && [ -s /etc/krb5.keytab ]; then
        print_warning "⚠ Keytab existe, mas join reportou falha"
        if klist -k /etc/krb5.keytab >> "$LOG_FILE" 2>&1; then
            print_success "✓ Keytab contém principals - sistema pode estar registrado"
            log_warning "Keytab existe apesar do erro de join"
            echo ""
            print_info "Execute para verificar:"
            echo "  realm list"
            echo "  wbinfo -u"
            return 0
        fi
    fi
    
    echo "Status dos métodos tentados:"
    echo "  1. net ads join: ✗ FALHOU"
    echo "  2. realm join: ✗ FALHOU"
    echo ""
    
    # Analisar o log para dar diagnóstico mais preciso
    print_warning "Análise do erro:"
    if grep -qi "revoked\|locked" "$LOG_FILE"; then
        echo "  🔒 CONTA BLOQUEADA - A conta '$USERNAME' está bloqueada no AD"
        echo ""
        print_info "SOLUÇÃO IMEDIATA:"
        echo "  1. Desbloqueie a conta '$USERNAME' no Active Directory"
        echo "  2. OU use o usuário 'Administrator'"
        echo "  3. Aguarde alguns minutos e tente novamente"
    elif grep -qi "denied\|permission" "$LOG_FILE"; then
        echo "  🚫 SEM PERMISSÃO - O usuário '$USERNAME' não pode adicionar computadores"
        echo ""
        print_info "SOLUÇÃO:"
        echo "  1. Use um usuário com privilégios 'Domain Admin'"
        echo "  2. OU delegue permissão ao usuário '$USERNAME'"
    elif grep -qi "password.*incorrect\|authentication.*fail" "$LOG_FILE"; then
        echo "  🔑 SENHA INCORRETA ou caracteres especiais não tratados"
        echo ""
        print_info "SOLUÇÃO:"
        echo "  1. Verifique se a senha está correta"
        echo "  2. Se a senha tem caracteres especiais (!@#\$%&*), tente mudá-la temporariamente"
        echo "  3. Verifique se a senha não expirou no AD"
    elif grep -qi "already.*joined\|already.*exists" "$LOG_FILE"; then
        echo "  ⚠️  COMPUTADOR JÁ EXISTE no domínio"
        echo ""
        print_info "SOLUÇÃO:"
        echo "  1. Remova o computador '$(hostname)' manualmente do AD"
        echo "  2. Execute: realm leave"
        echo "  3. Tente novamente"
    else
        echo "  ❓ ERRO DESCONHECIDO"
        echo ""
        print_warning "Últimas 15 linhas do log:"
        tail -n 15 "$LOG_FILE" | while read -r line; do
            echo "    $line"
        done
    fi
    
    echo ""
    print_separator
    print_info "Log completo disponível em: $LOG_FILE"
    echo ""
    print_info "Comandos úteis para diagnóstico:"
    echo "  realm discover $DOMAIN"
    echo "  net ads info"
    echo "  net ads testjoin"
    echo "  wbinfo -t"
    
    return 1
}

# Configurar SSSD
configure_sssd() {
    local sssd_conf="/etc/sssd/sssd.conf"
    
    print_info "Configurando SSSD..."
    log_info "Configurando arquivo $sssd_conf"
    
    # Verificar se o arquivo existe
    if [ ! -f "$sssd_conf" ]; then
        print_warning "Arquivo $sssd_conf não encontrado"
        print_info "Criando configuração SSSD do zero..."
        log_warning "Arquivo sssd.conf não existe, criando novo"
        
        # Criar diretório se não existir
        mkdir -p /etc/sssd
        
        # Criar configuração completa
        local realm=$(echo "$DOMAIN" | tr '[:lower:]' '[:upper:]')
        cat > "$sssd_conf" << EOFSSSD
[sssd]
domains = $DOMAIN
config_file_version = 2
services = nss, pam

[domain/$DOMAIN]
ad_domain = $DOMAIN
krb5_realm = $realm
realmd_tags = manages-system joined-with-adcli
cache_credentials = True
id_provider = ad
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
use_fully_qualified_names = False
fallback_homedir = /home/%u
access_provider = simple
simple_allow_groups = "$ADMIN_GROUP"
EOFSSSD
        
        chmod 600 "$sssd_conf"
        print_success "Arquivo $sssd_conf criado"
        log_success "Configuração SSSD criada do zero"
        return 0
    fi
    
    # Fazer backup
    backup_file "$sssd_conf"
    
    # Verificar se o domínio está habilitado na seção [sssd]
    if ! grep -q "^domains.*=.*$DOMAIN" "$sssd_conf"; then
        print_warning "Domínio não está habilitado em [sssd]"
        log_warning "Adicionando domínio à lista de domínios habilitados"
        
        # Verificar se linha domains existe
        if grep -q "^domains" "$sssd_conf"; then
            # Adicionar domínio à lista existente
            sed -i "s/^domains = .*/domains = $DOMAIN/" "$sssd_conf"
        else
            # Adicionar linha domains após [sssd]
            sed -i "/^\[sssd\]/a domains = $DOMAIN" "$sssd_conf"
        fi
    fi
    
    # Verificar se seção [domain/$DOMAIN] existe
    if ! grep -q "^\[domain/$DOMAIN\]" "$sssd_conf" && ! grep -q "^\[domain\/$DOMAIN\]" "$sssd_conf"; then
        print_error "Seção [domain/$DOMAIN] não encontrada no arquivo"
        log_error "Seção do domínio não existe no sssd.conf"
        
        # Criar seção do domínio
        local realm=$(echo "$DOMAIN" | tr '[:lower:]' '[:upper:]')
        cat >> "$sssd_conf" << EOFSSSD

[domain/$DOMAIN]
ad_domain = $DOMAIN
krb5_realm = $realm
realmd_tags = manages-system joined-with-adcli
cache_credentials = True
id_provider = ad
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
use_fully_qualified_names = False
fallback_homedir = /home/%u
access_provider = simple
simple_allow_groups = "$ADMIN_GROUP"
EOFSSSD
        print_success "Seção do domínio criada"
    else
        # Modificar configurações existentes
        if grep -q "use_fully_qualified_names" "$sssd_conf"; then
            sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/' "$sssd_conf"
            sed -i 's/use_fully_qualified_names = true/use_fully_qualified_names = False/' "$sssd_conf"
        else
            # Adicionar após a linha [domain/...]
            sed -i "/\[domain\/$DOMAIN\]/a use_fully_qualified_names = False" "$sssd_conf"
        fi
        
        # Configurar fallback_homedir
        if grep -q "fallback_homedir" "$sssd_conf"; then
            sed -i 's|fallback_homedir = .*|fallback_homedir = /home/%u|' "$sssd_conf"
        else
            sed -i "/\[domain\/$DOMAIN\]/a fallback_homedir = /home/%u" "$sssd_conf"
        fi
        
        # Modificar access_provider para simple
        if grep -q "access_provider" "$sssd_conf"; then
            sed -i 's/access_provider = ad/access_provider = simple/' "$sssd_conf"
            sed -i 's/access_provider = AD/access_provider = simple/' "$sssd_conf"
        else
            sed -i "/\[domain\/$DOMAIN\]/a access_provider = simple" "$sssd_conf"
        fi
        
        # Adicionar grupo ao acesso (entre aspas para suportar nomes com espaços/hífens)
        if ! grep -q "simple_allow_groups" "$sssd_conf"; then
            sed -i "/access_provider = simple/a simple_allow_groups = \"$ADMIN_GROUP\"" "$sssd_conf"
        else
            sed -i "s|^simple_allow_groups = .*|simple_allow_groups = \"$ADMIN_GROUP\"|" "$sssd_conf"
        fi
    fi
    
    # Ajustar permissões
    chmod 600 "$sssd_conf"
    
    print_success "SSSD configurado"
    log_success "Configuração do SSSD atualizada"
    
    # Mostrar configuração para debug
    print_info "Verificando configuração..."
    if grep -q "^domains.*=.*$DOMAIN" "$sssd_conf" && grep -q "^\[domain/$DOMAIN\]" "$sssd_conf"; then
        print_success "Domínio $DOMAIN está habilitado e configurado"
        log_success "Verificação de configuração: OK"
    else
        print_error "Problema na configuração do domínio"
        log_error "Verificação de configuração falhou"
        return 1
    fi
    
    return 0
}

# Configurar sudoers
configure_sudoers() {
    local sudoers_dir="/etc/sudoers.d"
    local sudoers_file="$sudoers_dir/domain_admins"
    
    print_info "Configurando permissões sudo para o grupo $ADMIN_GROUP..."
    log_info "Configurando sudoers para grupo: $ADMIN_GROUP"
    # Escapar espaços para sintaxe do sudoers (Domain\\ Admins)
    local ADMIN_GROUP_SUDO="${ADMIN_GROUP// /\\ }"
    
    # Criar diretório se não existir
    mkdir -p "$sudoers_dir"
    
    # Criar arquivo sudoers
    echo "# Permissões sudo para grupo do domínio" > "$sudoers_file"
    echo "# Gerado automaticamente em $(date)" >> "$sudoers_file"
    echo "%$ADMIN_GROUP_SUDO ALL=(ALL) ALL" >> "$sudoers_file"
    
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

# Configurar nsswitch para SSSD
configure_nsswitch_sss() {
    local nss="/etc/nsswitch.conf"
    if [ ! -f "$nss" ]; then
        print_warning "Arquivo $nss não encontrado; pulando ajuste do NSS"
        return 0
    fi

    print_info "Ajustando $nss para usar SSSD..."
    backup_file "$nss"

    # Garantir 'sss' em passwd, group e shadow, preservando ordem razoável
    if grep -q "^passwd:" "$nss"; then
        sed -i 's/^passwd:.*/passwd:         files systemd sss/' "$nss"
    else
        echo "passwd:         files systemd sss" >> "$nss"
    fi

    if grep -q "^group:" "$nss"; then
        sed -i 's/^group:.*/group:          files systemd sss/' "$nss"
    else
        echo "group:          files systemd sss" >> "$nss"
    fi

    if grep -q "^shadow:" "$nss"; then
        sed -i 's/^shadow:.*/shadow:         files sss/' "$nss"
    else
        echo "shadow:         files sss" >> "$nss"
    fi

    print_success "nsswitch.conf ajustado para SSSD"
    return 0
}

# Configurar política do realmd (permit) para refletir no 'realm list'
configure_realm_permit() {
    print_info "Aplicando política de login no realmd (realm permit) para grupo: $ADMIN_GROUP"
    if realm permit -g "$ADMIN_GROUP" >> "$LOG_FILE" 2>&1; then
        print_success "Grupo permitido no realmd: $ADMIN_GROUP"
        return 0
    else
        print_warning "Falha ao aplicar 'realm permit -g $ADMIN_GROUP' (continuando com SSSD)"
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
    
    # Parar SSSD antes de limpar cache
    print_info "Parando SSSD..."
    systemctl stop sssd >> "$LOG_FILE" 2>&1

    # Se preferimos SSSD, garantir que winbind não interfira
    if [ "${PREFER_SSSD}" = "true" ]; then
        if systemctl list-unit-files | grep -q "winbind"; then
            print_info "Desabilitando winbind (preferindo SSSD)..."
            systemctl disable --now winbind >> "$LOG_FILE" 2>&1 || true
        fi
    fi
    
    # Limpar cache do SSSD (importante para evitar problemas)
    print_info "Limpando cache do SSSD..."
    rm -rf /var/lib/sss/db/* >> "$LOG_FILE" 2>&1
    rm -rf /var/lib/sss/mc/* >> "$LOG_FILE" 2>&1
    log_info "Cache do SSSD limpo"
    
    # Habilitar e iniciar SSSD
    print_info "Iniciando SSSD..."
    systemctl enable sssd >> "$LOG_FILE" 2>&1
    
    if systemctl start sssd 2>&1 | tee -a "$LOG_FILE"; then
        print_success "SSSD iniciado com sucesso"
        log_success "SSSD iniciado"
    else
        print_error "FALHA ao iniciar SSSD"
        log_error "Falha ao iniciar SSSD"
        
        # Mostrar erro REAL do SSSD
        print_warning "Erro detalhado do SSSD:"
        
        # Tentar pegar o erro real do log do SSSD
        if [ -f /var/log/sssd/sssd.log ]; then
            echo ""
            echo "=== Últimas linhas de /var/log/sssd/sssd.log ==="
            tail -n 20 /var/log/sssd/sssd.log | grep -i "error\|fail\|could not\|unable" || tail -n 10 /var/log/sssd/sssd.log
        fi
        
        # Tentar executar SSSD em modo debug para ver o erro
        print_separator
        print_info "Tentando executar SSSD em modo debug..."
        timeout 5 /usr/sbin/sssd -i -d 3 2>&1 | head -n 30 | while read -r line; do
            echo "  $line"
        done
        
        print_separator
        print_warning "Possíveis problemas:"
        echo "  1. Arquivo /etc/sssd/sssd.conf tem problema de sintaxe"
        echo "  2. Permissões incorretas (deve ser 600)"
        echo "  3. Domínio não está configurado corretamente no realmd"
        echo "  4. Falta de comunicação com o controlador de domínio"
        
        # Verificar permissões do arquivo
        local perms=$(stat -c "%a" /etc/sssd/sssd.conf 2>/dev/null)
        if [ "$perms" != "600" ]; then
            print_warning "PROBLEMA: Permissões do sssd.conf: $perms (deveria ser 600)"
            chmod 600 /etc/sssd/sssd.conf
            print_info "Permissões corrigidas, tentando iniciar novamente..."
            if systemctl start sssd 2>&1 | tee -a "$LOG_FILE"; then
                print_success "SSSD iniciado após correção de permissões!"
                return 0
            fi
        fi
        
        return 1
    fi
    
    # Verificar se SSSD está realmente rodando
    sleep 2
    if systemctl is-active --quiet sssd; then
        print_success "SSSD está rodando corretamente"
        log_success "SSSD verificado: ativo"
    else
        print_error "SSSD não está rodando!"
        log_error "SSSD não está ativo após iniciar"
        return 1
    fi
    
    # Habilitar winbind se existir
    if systemctl list-unit-files | grep -q "winbind"; then
        print_info "Habilitando winbind..."
        systemctl enable winbind >> "$LOG_FILE" 2>&1 || true
        systemctl restart winbind >> "$LOG_FILE" 2>&1 || true
    fi
    
    # Habilitar oddjobd
    if systemctl list-unit-files | grep -q "oddjobd"; then
        print_info "Configurando oddjobd..."
        enable_service "oddjobd"
        restart_service "oddjobd"
    fi
    
    # Reiniciar SSH
    print_info "Reiniciando SSH..."
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
        restart_service "ssh"
    else
        restart_service "sshd"
    fi
    
    print_success "Todos os serviços reiniciados"
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
    
    if [ -z "$realm_status" ]; then
        print_error "FALHA: realm list não retorna nenhum domínio!"
        log_error "realm list vazio - ingresso pode não ter sido persistido"
        
        print_warning "Tentando re-configurar o domínio..."
        
        # Tentar descobrir o domínio novamente
        if realm discover "$DOMAIN" >> "$LOG_FILE" 2>&1; then
            print_info "Domínio $DOMAIN ainda é descobrível"
            
            # Verificar se o computador está no domínio via adcli
            if adcli testjoin >> "$LOG_FILE" 2>&1; then
                print_success "Computador ainda está no domínio (verificado com adcli)"
                log_success "adcli testjoin: OK"
                
                # O problema é só o realm list, SSSD deveria funcionar
                print_warning "O ingresso está OK, mas realm list não mostra"
                print_info "Isso pode ser normal em algumas configurações"
            else
                print_error "Computador NÃO está no domínio!"
                log_error "adcli testjoin falhou"
                return 1
            fi
        else
            print_error "Não consegue descobrir o domínio"
            return 1
        fi
    else
        print_success "Sistema está integrado ao domínio"
        echo ""
        echo "$realm_status" | grep -E "domain-name|configured|server-software|client-software"
        log_success "Verificação de domínio: OK"
        
        # Verificar se está configurado
        if echo "$realm_status" | grep -q "configured: kerberos-member"; then
            print_success "Configuração: kerberos-member (OK)"
        elif echo "$realm_status" | grep -q "configured: no"; then
            print_warning "Status 'configured: no' - pode precisar reiniciar"
        fi
    fi
    
    print_separator
    
    # Testar SSSD diretamente
    print_info "Testando SSSD..."
    if systemctl is-active --quiet sssd; then
        print_success "SSSD está ativo"
        
        # Tentar buscar informação do domínio via getent
        print_info "Testando resolução de nomes..."
        if getent passwd | grep -q "@$DOMAIN\|^[a-z]*\.[a-z]*:"; then
            print_success "SSSD está resolvendo usuários do domínio"
        else
            print_warning "SSSD ativo mas ainda não resolveu usuários (pode levar alguns segundos)"
        fi
    else
        print_error "SSSD NÃO está ativo!"
        return 1
    fi
    
    print_separator
    return 0
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
    echo "  id usuario (sem @domínio)"
    echo "  getent passwd usuario"
    
    print_info "Para listar informações do domínio:"
    echo "  realm list"
    echo "  sssctl domain-list"
    
    print_info "Para verificar status do SSSD:"
    echo "  sudo systemctl status sssd"
    echo "  sudo sssctl domain-status $DOMAIN"
    
    print_separator
    print_info "Configuração do SSSD:"
    if [ -f "/etc/sssd/sssd.conf" ]; then
        echo "  Arquivo: /etc/sssd/sssd.conf"
        echo "  Domínio configurado: $DOMAIN"
        echo "  Grupo com acesso: $ADMIN_GROUP"
    fi
    
    print_separator
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
    
    # Verificar se keytab foi criado (CRÍTICO para SSSD funcionar)
    print_separator
    print_info "Verificando keytab do Kerberos..."
    
    if [ ! -f /etc/krb5.keytab ] || [ ! -s /etc/krb5.keytab ]; then
        print_error "Arquivo /etc/krb5.keytab não foi criado ou está vazio!"
        print_error "SSSD não funcionará sem o keytab"
        print_separator
        print_warning "Correção manual:"
        echo "  Execute: sudo ./fix_keytab.sh"
        echo "  OU: sudo net ads join -U $USERNAME"
        log_error "Keytab não foi criado"
        exit 1
    else
        print_success "Keytab existe: /etc/krb5.keytab"
        
        # Verificar conteúdo do keytab
        if klist -k /etc/krb5.keytab >> "$LOG_FILE" 2>&1; then
            local keytab_count=$(klist -k /etc/krb5.keytab 2>/dev/null | grep -c "@")
            print_success "Keytab contém $keytab_count principal(s)"
            log_success "Keytab verificado: $keytab_count principals"
        else
            print_warning "Keytab existe mas parece vazio ou corrompido"
            log_warning "Keytab pode estar corrompido"
        fi
    fi
    
    # Configurar SSSD (CRÍTICO - não continuar se falhar)
    print_separator
    if ! configure_sssd; then
        print_error "FALHA CRÍTICA ao configurar SSSD"
        print_error "O sistema foi registrado no domínio, mas o SSSD não está funcionando"
        print_separator
        print_warning "Para corrigir manualmente:"
        echo "  1. sudo systemctl stop sssd"
        echo "  2. sudo nano /etc/sssd/sssd.conf"
        echo "  3. Adicione a seção [domain/$DOMAIN] corretamente"
        echo "  4. sudo chmod 600 /etc/sssd/sssd.conf"
        echo "  5. sudo rm -rf /var/lib/sss/db/* /var/lib/sss/mc/*"
        echo "  6. sudo systemctl start sssd"
        exit 1
    fi
    
    # Ajustar nsswitch para SSSD quando preferido
    if [ "${PREFER_SSSD}" = "true" ]; then
        configure_nsswitch_sss || true
    fi
    
    print_separator
    
    # Configurar sudoers
    if ! configure_sudoers; then
        print_warning "Falha ao configurar sudo, você precisará configurar manualmente"
    fi
    
    # Aplicar política 'realm permit' para o grupo aparecer no 'realm list'
    configure_realm_permit || true
    
    # Configurar PAM
    if ! configure_pam; then
        print_warning "Falha ao configurar PAM, home directories podem não ser criados automaticamente"
    fi
    
    # Reiniciar serviços (CRÍTICO)
    if ! restart_domain_services; then
        print_error "FALHA CRÍTICA ao reiniciar serviços"
        print_error "O SSSD não está funcionando corretamente"
        print_separator
        print_warning "Para diagnosticar:"
        echo "  sudo journalctl -xeu sssd.service"
        echo "  sudo cat /etc/sssd/sssd.conf"
        echo "  sudo sssctl domain-list"
        exit 1
    fi
    
    print_separator
    
    # Verificar status
    if ! verify_domain_status; then
        print_warning "Verificação de status falhou, mas configuração pode estar OK"
        print_info "Teste manualmente: id usuario.dominio"
    fi
    
    # Exibir informações finais
    show_final_info
    
    return 0
}

# Executar apenas se for o script principal
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

