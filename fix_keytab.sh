#!/bin/bash

# Script para criar o keytab que está faltando

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       CORREÇÃO DO KEYTAB - center.local                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Execute como root: sudo ./fix_keytab.sh${NC}"
    exit 1
fi

DOMAIN="center.local"

echo -e "${YELLOW}Este script vai criar o arquivo /etc/krb5.keytab${NC}"
echo ""

# Verificar se já existe
if [ -f /etc/krb5.keytab ]; then
    echo -e "${YELLOW}⚠ Keytab já existe${NC}"
    echo ""
    echo "Conteúdo atual:"
    klist -k /etc/krb5.keytab
    echo ""
    read -p "Deseja recriar? [s/N]: " RECREATE
    if [[ ! "$RECREATE" =~ ^[Ss]$ ]]; then
        echo "Operação cancelada"
        exit 0
    fi
    echo ""
    echo -e "${YELLOW}→ Fazendo backup...${NC}"
    cp /etc/krb5.keytab /etc/krb5.keytab.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✓ Backup criado${NC}"
fi

echo ""
read -p "Digite o usuário administrador do domínio: " USERNAME
read -sp "Digite a senha: " PASSWORD
echo ""
echo ""

echo -e "${YELLOW}→ Tentando criar keytab com adcli...${NC}"

# Método 1: adcli com stdin
TEMP_PASS=$(mktemp)
chmod 600 "$TEMP_PASS"
printf '%s\n' "$PASSWORD" > "$TEMP_PASS"

if adcli join --domain="$DOMAIN" --login-user="$USERNAME" --stdin-password -v < "$TEMP_PASS" 2>&1; then
    rm -f "$TEMP_PASS"
    echo -e "${GREEN}✓ Keytab criado com sucesso!${NC}"
    echo ""
    echo "Verificando keytab:"
    klist -k /etc/krb5.keytab
    echo ""
    
    # Iniciar SSSD
    echo -e "${YELLOW}→ Iniciando SSSD...${NC}"
    systemctl stop sssd
    rm -rf /var/lib/sss/db/* /var/lib/sss/mc/*
    
    if systemctl start sssd; then
        echo -e "${GREEN}✓ SSSD iniciado com sucesso!${NC}"
        echo ""
        systemctl status sssd --no-pager
        
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  SUCESSO! Keytab criado e SSSD iniciado                 ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "Teste agora:"
        echo "  id usuario.dominio"
        echo "  getent passwd usuario.dominio"
    else
        echo -e "${RED}✗ FALHA ao iniciar SSSD${NC}"
        echo ""
        echo "Verifique os logs:"
        echo "  sudo journalctl -xeu sssd.service"
        echo "  sudo /usr/sbin/sssd -i -d 3"
    fi
else
    rm -f "$TEMP_PASS"
    echo -e "${RED}✗ Falha ao criar keytab${NC}"
    echo ""
    echo "Tente criar manualmente:"
    echo "  sudo adcli join center.local --login-user=$USERNAME --verbose --show-details"
    exit 1
fi

rm -f "$TEMP_PASS"
