#!/bin/bash

# Script de diagnóstico rápido do SSSD

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       DIAGNÓSTICO SSSD - Detecção de Problema           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Execute como root: sudo ./diagnose_sssd.sh${NC}"
    exit 1
fi

echo -e "${YELLOW}1. Verificando arquivo de configuração...${NC}"
echo ""

if [ -f /etc/sssd/sssd.conf ]; then
    echo -e "${GREEN}✓ Arquivo existe${NC}"
    
    # Verificar permissões
    perms=$(stat -c "%a" /etc/sssd/sssd.conf)
    echo "  Permissões: $perms"
    if [ "$perms" = "600" ]; then
        echo -e "  ${GREEN}✓ Permissões OK${NC}"
    else
        echo -e "  ${RED}✗ Permissões incorretas! Deve ser 600${NC}"
        echo "  Corrigindo..."
        chmod 600 /etc/sssd/sssd.conf
        echo -e "  ${GREEN}✓ Corrigido${NC}"
    fi
    
    # Mostrar conteúdo
    echo ""
    echo "  Conteúdo do arquivo:"
    echo "  ---"
    cat /etc/sssd/sssd.conf | sed 's/^/  /'
    echo "  ---"
else
    echo -e "${RED}✗ Arquivo não existe!${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}2. Parando SSSD...${NC}"
systemctl stop sssd
echo -e "${GREEN}✓ Parado${NC}"

echo ""
echo -e "${YELLOW}3. Limpando logs antigos...${NC}"
rm -f /var/log/sssd/*.log 2>/dev/null
echo -e "${GREEN}✓ Logs limpos${NC}"

echo ""
echo -e "${YELLOW}4. Executando SSSD em modo interativo/debug...${NC}"
echo ""
echo -e "${BLUE}=== OUTPUT DO SSSD ===${NC}"
echo ""

# Executar SSSD em modo interativo por 5 segundos para ver o erro
timeout 5 /usr/sbin/sssd -i -d 3 2>&1 || true

echo ""
echo -e "${BLUE}=== FIM DO OUTPUT ===${NC}"
echo ""

echo -e "${YELLOW}5. Verificando logs do SSSD...${NC}"
if [ -f /var/log/sssd/sssd.log ]; then
    echo ""
    echo -e "${BLUE}=== Log do SSSD ===${NC}"
    cat /var/log/sssd/sssd.log
    echo ""
else
    echo -e "${YELLOW}⚠ Nenhum log foi criado${NC}"
fi

echo ""
echo -e "${YELLOW}6. Verificando domínio no realm...${NC}"
realm list
echo ""

echo ""
echo -e "${YELLOW}7. Testando configuração com sssctl...${NC}"
sssctl config-check 2>&1 || echo -e "${RED}✗ Erro na configuração${NC}"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  DIAGNÓSTICO COMPLETO                                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Analise o output acima para identificar o erro"
echo ""
