#!/bin/bash

#==============================================================================
# SCRIPT SEGURO - UMA TENTATIVA APENAS
# Não bloqueia conta no AD
#==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       INGRESSO SEGURO NO DOMÍNIO - UMA TENTATIVA        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Execute como root${NC}"
    exit 1
fi

DOMAIN="center.local"

echo -e "${YELLOW}⚠ IMPORTANTE:${NC}"
echo "  Este script faz APENAS UMA tentativa de autenticação"
echo "  Isso evita bloqueio automático da conta no AD"
echo ""

read -p "Usuário AD: " USERNAME
read -sp "Senha: " PASSWORD
echo ""
read -p "Grupo SSH/Sudo: " ADMIN_GROUP

echo ""
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW} Preparação${NC}"
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo ""

# Instalar samba (para net ads)
if ! command -v net > /dev/null 2>&1; then
    echo "→ Instalando Samba..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y samba smbclient winbind 2>&1 | grep -E "^(Setting up|Processing)"
fi

# Limpar registros anteriores
echo "→ Limpando registros anteriores..."
realm leave 2>/dev/null || true
rm -f /etc/krb5.keytab 2>/dev/null || true
systemctl stop sssd 2>/dev/null || true
rm -rf /var/lib/sss/db/* /var/lib/sss/mc/*

echo ""
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW} Ingresso no Domínio (UMA tentativa)${NC}"
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo ""

# Configurar Samba primeiro
cat > /etc/samba/smb.conf << EOFSAMBA
[global]
   workgroup = ${DOMAIN%%.*}
   security = ads
   realm = ${DOMAIN^^}
   encrypt passwords = yes
   
   # Keytab
   kerberos method = secrets and keytab
   
   # Configurações de ID mapping
   idmap config * : backend = tdb
   idmap config * : range = 3000-7999
   idmap config ${DOMAIN%%.*} : backend = rid
   idmap config ${DOMAIN%%.*} : range = 10000-999999
   
   template shell = /bin/bash
   template homedir = /home/%U
   winbind use default domain = true
   winbind offline logon = false
EOFSAMBA

echo "→ Configuração Samba criada"

# UMA ÚNICA TENTATIVA com net ads join
echo "→ Executando: net ads join (ÚNICA TENTATIVA)"
echo ""

# Usar expect para passar senha de forma segura (UMA VEZ)
if command -v expect > /dev/null 2>&1; then
    EXPECT_SCRIPT=$(mktemp)
    cat > "$EXPECT_SCRIPT" << 'EXPECTEOF'
set timeout 120
set username [lindex $argv 0]
set password [lindex $argv 1]
log_user 1

spawn net ads join -U $username
expect {
    "*password*:" {
        send "$password\r"
        exp_continue
    }
    "Password for *:" {
        send "$password\r"
        exp_continue
    }
    "Joined*to*" {
        puts "\n✓ SUCESSO: Ingressado no domínio"
        exit 0
    }
    "Failed*" {
        puts "\n✗ FALHA ao ingressar"
        exit 1
    }
    timeout {
        puts "\n✗ TIMEOUT"
        exit 1
    }
    eof
}
EXPECTEOF

    if expect "$EXPECT_SCRIPT" "$USERNAME" "$PASSWORD"; then
        JOINED=true
    else
        JOINED=false
    fi
    rm -f "$EXPECT_SCRIPT"
else
    # Sem expect, tentar com echo
    if echo "$PASSWORD" | net ads join -U "$USERNAME" 2>&1 | tee /tmp/net_ads.log | grep -q "Joined"; then
        JOINED=true
    else
        JOINED=false
    fi
fi

if [ "$JOINED" = false ]; then
    echo ""
    echo -e "${RED}✗ FALHA ao ingressar no domínio${NC}"
    echo ""
    echo -e "${YELLOW}Possíveis causas:${NC}"
    echo "  1. Senha incorreta (verifique caracteres especiais)"
    echo "  2. Usuário não tem permissão"
    echo "  3. Problemas de rede/DNS"
    echo ""
    echo "Log salvo em: /tmp/net_ads.log"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Ingressado no domínio com sucesso!${NC}"

echo ""
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW} Verificando Keytab${NC}"
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo ""

if [ -f /etc/krb5.keytab ] && [ -s /etc/krb5.keytab ]; then
    echo -e "${GREEN}✓ Keytab criado automaticamente${NC}"
    echo ""
    klist -k /etc/krb5.keytab
else
    echo -e "${RED}✗ Keytab não foi criado${NC}"
    echo "Isso não deveria acontecer com net ads join..."
    exit 1
fi

echo ""
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW} Configurando SSSD${NC}"
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo ""

mkdir -p /etc/sssd
cat > /etc/sssd/sssd.conf << EOFSSSD
[sssd]
domains = $DOMAIN
config_file_version = 2
services = nss, pam

[domain/$DOMAIN]
ad_domain = $DOMAIN
krb5_realm = ${DOMAIN^^}
realmd_tags = manages-system joined-with-samba
cache_credentials = True
id_provider = ad
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
use_fully_qualified_names = False
fallback_homedir = /home/%u
access_provider = simple
simple_allow_groups = $ADMIN_GROUP
EOFSSSD

chmod 600 /etc/sssd/sssd.conf
echo -e "${GREEN}✓ SSSD configurado${NC}"

# Sudoers
mkdir -p /etc/sudoers.d
echo "%$ADMIN_GROUP ALL=(ALL) ALL" > /etc/sudoers.d/domain_admins
chmod 440 /etc/sudoers.d/domain_admins
echo -e "${GREEN}✓ Sudoers configurado${NC}"

# PAM
if ! grep -q "pam_mkhomedir.so" /etc/pam.d/common-session; then
    echo "session optional pam_mkhomedir.so skel=/etc/skel umask=0077" >> /etc/pam.d/common-session
    echo -e "${GREEN}✓ PAM configurado${NC}"
else
    echo -e "${GREEN}✓ PAM já configurado${NC}"
fi

echo ""
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW} Iniciando Serviços${NC}"
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo ""

systemctl enable sssd winbind
systemctl restart sssd winbind

sleep 3

if systemctl is-active --quiet sssd; then
    echo -e "${GREEN}✓ SSSD está rodando${NC}"
else
    echo -e "${RED}✗ SSSD não iniciou${NC}"
    systemctl status sssd --no-pager
    exit 1
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              CONCLUÍDO COM SUCESSO!                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Informações:"
net ads info 2>/dev/null || true
echo ""

echo "Teste agora:"
echo "  wbinfo -u  # Listar usuários do domínio"
echo "  id usuario.dominio"
echo ""
