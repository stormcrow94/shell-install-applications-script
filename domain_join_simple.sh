#!/bin/bash

#==============================================================================
# SCRIPT SIMPLES E DIRETO - INGRESSO NO DOMÍNIO
# Sem frescuras, sem testes desnecessários
#==============================================================================

set -e  # Para na primeira falha

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       INGRESSO NO DOMÍNIO - MÉTODO SIMPLIFICADO         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Execute como root${NC}"
    exit 1
fi

# Coletar informações
DOMAIN="center.local"
echo "Domínio: $DOMAIN"
echo ""

read -p "Usuário: " USERNAME
read -sp "Senha: " PASSWORD
echo ""
read -p "Grupo SSH/Sudo: " ADMIN_GROUP

echo ""
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW} PASSO 1: Ingressar no Domínio${NC}"
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo ""

# Sair do domínio primeiro (se já estiver)
echo "→ Limpando registro anterior..."
realm leave 2>/dev/null || true
rm -f /etc/krb5.keytab 2>/dev/null || true

# Criar arquivo temporário para senha
TEMP_PASS=$(mktemp)
chmod 600 "$TEMP_PASS"
printf '%s\n' "$PASSWORD" > "$TEMP_PASS"

# Tentar com realm join + arquivo
echo "→ Tentando realm join..."
if realm join --user="$USERNAME" "$DOMAIN" --verbose < "$TEMP_PASS" 2>&1 | tee /tmp/realm_join.log; then
    echo -e "${GREEN}✓ Realm join executado${NC}"
else
    echo -e "${YELLOW}⚠ Realm join falhou, tentando adcli...${NC}"
    
    # Tentar com adcli
    if adcli join --domain="$DOMAIN" --login-user="$USERNAME" --stdin-password -v < "$TEMP_PASS" 2>&1 | tee /tmp/adcli_join.log; then
        echo -e "${GREEN}✓ Adcli join executado${NC}"
    else
        echo -e "${RED}✗ Ambos falharam${NC}"
        rm -f "$TEMP_PASS"
        exit 1
    fi
fi

rm -f "$TEMP_PASS"

echo ""
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW} PASSO 2: Verificar/Criar Keytab${NC}"
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo ""

# Verificar keytab
if [ ! -f /etc/krb5.keytab ] || [ ! -s /etc/krb5.keytab ]; then
    echo -e "${RED}✗ Keytab não existe ou está vazio${NC}"
    echo "→ Criando keytab com net ads..."
    
    # Instalar samba se não tiver
    if ! command -v net > /dev/null 2>&1; then
        echo "→ Instalando samba..."
        apt-get install -y samba smbclient winbind 2>&1 | grep -v "^Reading"
    fi
    
    # Criar keytab com net ads
    TEMP_PASS2=$(mktemp)
    chmod 600 "$TEMP_PASS2"
    printf '%s\n' "$PASSWORD" > "$TEMP_PASS2"
    
    echo "$PASSWORD" | net ads join -U "$USERNAME" 2>&1 | tee /tmp/net_ads.log
    
    if [ -f /etc/krb5.keytab ] && [ -s /etc/krb5.keytab ]; then
        echo -e "${GREEN}✓ Keytab criado com net ads${NC}"
    else
        # Última tentativa com kinit + ktutil
        echo "→ Criando keytab manualmente..."
        echo "$PASSWORD" | kinit "$USERNAME@${DOMAIN^^}" 2>&1
        
        # Exportar keytab
        ktutil << KTEOF
addent -password -p host/$(hostname).${DOMAIN}@${DOMAIN^^} -k 1 -e aes256-cts-hmac-sha1-96
$PASSWORD
wkt /etc/krb5.keytab
quit
KTEOF
        
        chmod 600 /etc/krb5.keytab
        
        if [ -f /etc/krb5.keytab ] && [ -s /etc/krb5.keytab ]; then
            echo -e "${GREEN}✓ Keytab criado manualmente${NC}"
        else
            echo -e "${RED}✗ Não foi possível criar keytab${NC}"
            exit 1
        fi
    fi
    
    rm -f "$TEMP_PASS2"
else
    echo -e "${GREEN}✓ Keytab já existe${NC}"
fi

echo ""
echo "Conteúdo do keytab:"
klist -k /etc/krb5.keytab

echo ""
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW} PASSO 3: Configurar SSSD${NC}"
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo ""

# Criar sssd.conf
cat > /etc/sssd/sssd.conf << EOFSSSD
[sssd]
domains = $DOMAIN
config_file_version = 2
services = nss, pam

[domain/$DOMAIN]
ad_domain = $DOMAIN
krb5_realm = ${DOMAIN^^}
realmd_tags = manages-system joined-with-adcli
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

echo ""
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW} PASSO 4: Configurar Sudoers${NC}"
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo ""

mkdir -p /etc/sudoers.d
cat > /etc/sudoers.d/domain_admins << EOFSUDO
%$ADMIN_GROUP ALL=(ALL) ALL
EOFSUDO
chmod 440 /etc/sudoers.d/domain_admins
echo -e "${GREEN}✓ Sudoers configurado${NC}"

echo ""
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW} PASSO 5: Configurar PAM${NC}"
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo ""

if ! grep -q "pam_mkhomedir.so" /etc/pam.d/common-session; then
    echo "session optional pam_mkhomedir.so skel=/etc/skel umask=0077" >> /etc/pam.d/common-session
    echo -e "${GREEN}✓ PAM configurado${NC}"
else
    echo -e "${GREEN}✓ PAM já configurado${NC}"
fi

echo ""
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo -e "${YELLOW} PASSO 6: Iniciar Serviços${NC}"
echo -e "${YELLOW}════════════════════════════════════════════${NC}"
echo ""

# Parar tudo
systemctl stop sssd 2>/dev/null || true

# Limpar cache
rm -rf /var/lib/sss/db/*
rm -rf /var/lib/sss/mc/*
echo -e "${GREEN}✓ Cache limpo${NC}"

# Habilitar e iniciar
systemctl enable sssd
systemctl start sssd

sleep 3

if systemctl is-active --quiet sssd; then
    echo -e "${GREEN}✓ SSSD está rodando${NC}"
else
    echo -e "${RED}✗ SSSD falhou ao iniciar${NC}"
    echo ""
    echo "Executando SSSD em modo debug:"
    timeout 5 /usr/sbin/sssd -i -d 3 2>&1 | head -50
    exit 1
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    CONCLUÍDO COM SUCESSO!                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Informações do domínio:"
realm list

echo ""
echo "Teste agora:"
echo "  id usuario.dominio"
echo "  getent passwd usuario.dominio"
echo ""
