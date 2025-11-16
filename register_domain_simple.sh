#!/bin/bash

#==============================================================================
# Script Simples de Registro no Domínio
# Baseado no script original que funcionava
#==============================================================================

set -e

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo "Este script precisa ser executado como root"
    exit 1
fi

echo "================================"
echo "  Registro no Domínio (Simples)"
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
read -p "Digite o domínio (ex: center.local): " domain

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
read -p "Digite o nome do usuário administrador (ex: fortigate): " username
read -sp "Digite a senha: " password
echo ""
read -p "Digite o grupo para SSH e Sudo (ex: SUDOERS_COMMSHOP_PRD): " group

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
    
    # Access provider
    sed -i 's/access_provider = ad/access_provider = simple/' "$sssd_conf"
    sed -i 's/access_provider = AD/access_provider = simple/' "$sssd_conf"
    
    if ! grep -q "access_provider" "$sssd_conf"; then
        sed -i "/\[domain\/${domain}\]/a access_provider = simple" "$sssd_conf"
    fi
    
    # Grupo permitido
    if grep -q "simple_allow_groups" "$sssd_conf"; then
        sed -i "s|^simple_allow_groups = .*|simple_allow_groups = \"${group}\"|" "$sssd_conf"
    else
        sed -i "/access_provider = simple/a simple_allow_groups = \"${group}\"" "$sssd_conf"
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
    echo ""
    echo "Para verificar:"
    echo "  realm list"
    echo "  id <usuario>"
    echo "  getent passwd <usuario>"
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

