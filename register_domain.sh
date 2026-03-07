#!/bin/bash

#==============================================================================
# Script de Registro no Domínio
# Integra o sistema ao domínio via SSSD/Realmd
# Versão simples e funcional
#==============================================================================

set -e

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo "Este script precisa ser executado como root"
    exit 1
fi

echo "================================"
echo "  Registro no Domínio"
echo "================================"
echo ""

# Pacotes necessários
packages=(
    "realmd"
    "sssd"
    "sssd-tools"
    "libnss-sss"
    "libpam-sss"
    "adcli"
    "samba-common-bin"
    "oddjob"
    "oddjob-mkhomedir"
    "packagekit"
)

# Instalar pacotes
echo "Instalando pacotes necessários..."
apt-get update -qq
for package in "${packages[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package"; then
        echo "Instalando $package..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"
    else
        echo "$package já está instalado."
    fi
done

echo ""

# Configurar krb5.conf mínimo
echo "Configurando Kerberos..."
read -p "Digite o domínio (ex: corp.example.com): " domain

realm_upper=$(echo "$domain" | tr '[:lower:]' '[:upper:]')

cat > /etc/krb5.conf <<EOF
[libdefaults]
  default_realm = ${realm_upper}
  dns_lookup_kdc = true
  dns_lookup_realm = true
  rdns = false
  ticket_lifetime = 24h
  forwardable = true
  default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 rc4-hmac
  default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 rc4-hmac
  permitted_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 rc4-hmac

[domain_realm]
  .${domain} = ${realm_upper}
  ${domain} = ${realm_upper}
EOF

echo "Kerberos configurado."
echo ""

# Coletar informações
read -p "Digite o nome do usuário administrador (ex: administrator): " username
read -sp "Digite a senha: " password
echo ""
echo ""
echo "NOTA: O grupo especificado abaixo terá permissões de SUDO."
echo "      O acesso SSH pode ser configurado posteriormente."
echo ""
read -p "Digite o grupo para SSH e Sudo (ex: linux-admins): " group

echo ""
echo "Descobrindo o domínio..."
realm discover "$domain"

echo ""
echo "Ingressando no domínio..."
# Limpar qualquer join anterior
realm leave 2>/dev/null || true
systemctl stop sssd 2>/dev/null || true
rm -rf /var/lib/sss/db/* /var/lib/sss/mc/* 2>/dev/null || true

# Join simples
echo "$password" | realm join --user="$username" "$domain" --verbose

# Verificar se deu certo
if [ $? -eq 0 ] || [ -f /etc/krb5.keytab ]; then
    echo ""
    echo "✓ Computador registrado no domínio com sucesso!"
    echo ""
    
    # Configurar SSSD
    echo "Configurando SSSD..."
    sssd_conf="/etc/sssd/sssd.conf"
    
    # Backup
    cp "$sssd_conf" "${sssd_conf}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    
    # Ajustar configurações
    sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/' "$sssd_conf"
    sed -i 's/use_fully_qualified_names = true/use_fully_qualified_names = False/' "$sssd_conf"
    
    # Adicionar se não existir
    if ! grep -q "use_fully_qualified_names" "$sssd_conf"; then
        sed -i "/\[domain\/${domain}\]/a use_fully_qualified_names = False" "$sssd_conf"
    fi
    
    # Fallback homedir
    if grep -q "fallback_homedir" "$sssd_conf"; then
        sed -i 's|fallback_homedir = .*|fallback_homedir = /home/%u|' "$sssd_conf"
    else
        sed -i "/\[domain\/${domain}\]/a fallback_homedir = /home/%u" "$sssd_conf"
    fi
    
    # Access provider - Configuração mais flexível
    echo ""
    echo "Escolha o método de controle de acesso:"
    echo "1) Permitir TODOS os usuários do domínio (recomendado para ambientes de desenvolvimento/teste)"
    echo "2) Restringir acesso apenas ao grupo especificado (mais seguro para produção)"
    echo ""
    read -p "Escolha [1-2] (padrão: 1): " access_choice
    access_choice=${access_choice:-1}
    
    if [ "$access_choice" = "2" ]; then
        # Modo restrito - apenas grupo específico
        echo "Modo RESTRITO: apenas usuários do grupo '$group' poderão fazer login"
        
        sed -i 's/access_provider = ad/access_provider = simple/' "$sssd_conf"
        sed -i 's/access_provider = AD/access_provider = simple/' "$sssd_conf"
        
        if ! grep -q "access_provider" "$sssd_conf"; then
            sed -i "/\[domain\/${domain}\]/a access_provider = simple" "$sssd_conf"
        fi
        
        # Grupo permitido
        if grep -q "simple_allow_groups" "$sssd_conf"; then
            sed -i "s|^simple_allow_groups = .*|simple_allow_groups = ${group}|" "$sssd_conf"
        else
            sed -i "/access_provider = simple/a simple_allow_groups = ${group}" "$sssd_conf"
        fi
    else
        # Modo permissivo - todos os usuários do domínio
        echo "Modo PERMISSIVO: todos os usuários do domínio poderão fazer login"
        
        # Usar access_provider = ad (usa as políticas do próprio AD)
        sed -i 's/access_provider = simple/access_provider = ad/' "$sssd_conf"
        sed -i 's/access_provider = Simple/access_provider = ad/' "$sssd_conf"
        
        if ! grep -q "access_provider" "$sssd_conf"; then
            sed -i "/\[domain\/${domain}\]/a access_provider = ad" "$sssd_conf"
        fi
        
        # Remover/comentar simple_allow_groups se existir
        sed -i 's/^simple_allow_groups/#simple_allow_groups/' "$sssd_conf"
    fi
    
    chmod 600 "$sssd_conf"
    
    # Configurar sudoers
    echo "Configurando sudoers..."
    sudoers_file="/etc/sudoers.d/domain_admins"
    group_escaped="${group// /\\ }"
    
    echo "# Permissões sudo para grupo do domínio" > "$sudoers_file"
    echo "%${group_escaped} ALL=(ALL) ALL" >> "$sudoers_file"
    chmod 440 "$sudoers_file"
    
    # Validar
    if ! visudo -c -f "$sudoers_file"; then
        echo "Erro no arquivo sudoers, removendo..."
        rm -f "$sudoers_file"
    fi
    
    # PAM para criar home directories
    if ! grep -q "pam_mkhomedir.so" /etc/pam.d/common-session; then
        echo "session optional pam_mkhomedir.so skel=/etc/skel umask=0077" >> /etc/pam.d/common-session
    fi
    
    # Ajustar nsswitch.conf
    sed -i 's/^passwd:.*/passwd:         files systemd sss/' /etc/nsswitch.conf
    sed -i 's/^group:.*/group:          files systemd sss/' /etc/nsswitch.conf
    sed -i 's/^shadow:.*/shadow:         files sss/' /etc/nsswitch.conf
    
    # Reiniciar serviços
    echo "Reiniciando serviços..."
    systemctl stop sssd
    rm -rf /var/lib/sss/db/* /var/lib/sss/mc/*
    systemctl enable sssd
    systemctl start sssd
    systemctl restart ssh
    
    echo ""
    echo "================================"
    echo "  ✓ Configuração Concluída"
    echo "================================"
    echo ""
    echo "Domínio: $domain"
    echo "Grupo com sudo: $group"
    
    if [ "$access_choice" = "2" ]; then
        echo "Modo de acesso: RESTRITO (apenas grupo: $group)"
        echo ""
        echo "⚠️  IMPORTANTE: Apenas usuários do grupo '$group' podem fazer login via SSH!"
        echo "   Se um usuário não conseguir fazer SSH, verifique se ele está no grupo correto."
    else
        echo "Modo de acesso: PERMISSIVO (todos os usuários do domínio)"
        echo ""
        echo "✓ Todos os usuários do domínio podem fazer login via SSH"
    fi
    
    echo ""
    echo "Para verificar:"
    echo "  realm list                    # Ver domínio registrado"
    echo "  id <usuario>                  # Ver usuário e seus grupos"
    echo "  getent passwd <usuario>       # Verificar resolução de nome"
    echo "  ssh <usuario>@localhost       # Testar login SSH local"
    echo ""
    echo "Troubleshooting (se houver problemas de acesso SSH):"
    echo "  sudo journalctl -u sssd -n 50                    # Ver logs do SSSD"
    echo "  sudo tail -f /var/log/auth.log                   # Ver logs de autenticação"
    echo "  sudo cat /etc/sssd/sssd.conf | grep access       # Ver configuração de acesso"
    echo ""
    echo "Se usuários válidos não conseguirem fazer SSH, considere:"
    echo "  1. Verificar se o usuário está no grupo correto (se modo restrito)"
    echo "  2. Reexecutar o script e escolher modo PERMISSIVO"
    echo "  3. Ver documentação em: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_authentication_and_authorization_in_rhel/managing-user-access_configuring-authentication-and-authorization-in-rhel"
    echo ""
else
    echo ""
    echo "✗ Falha ao ingressar no domínio"
    echo ""
    echo "Verifique:"
    echo "  1. Credenciais do usuário"
    echo "  2. DNS está resolvendo o domínio"
    echo "  3. Portas 88, 389, 445 abertas"
    echo ""
    exit 1
fi
