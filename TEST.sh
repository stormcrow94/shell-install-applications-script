#!/bin/bash

#==============================================================================
# Script de Teste Rápido
# Verifica se todos os componentes estão instalados corretamente
#==============================================================================

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                   TESTE DE INTEGRIDADE                            ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

PASSED=0
FAILED=0

# Função para testar arquivo
test_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo "✅ $description"
        ((PASSED++))
        return 0
    else
        echo "❌ $description - FALTANDO"
        ((FAILED++))
        return 1
    fi
}

# Função para testar diretório
test_dir() {
    local dir=$1
    local description=$2
    
    if [ -d "$dir" ]; then
        echo "✅ $description"
        ((PASSED++))
        return 0
    else
        echo "❌ $description - FALTANDO"
        ((FAILED++))
        return 1
    fi
}

# Função para testar executável
test_executable() {
    local file=$1
    local description=$2
    
    if [ -x "$file" ]; then
        echo "✅ $description é executável"
        ((PASSED++))
        return 0
    else
        echo "❌ $description - NÃO EXECUTÁVEL"
        ((FAILED++))
        return 1
    fi
}

# Função para testar sintaxe
test_syntax() {
    local file=$1
    local description=$2
    
    if bash -n "$file" 2>/dev/null; then
        echo "✅ $description - sintaxe OK"
        ((PASSED++))
        return 0
    else
        echo "❌ $description - ERRO DE SINTAXE"
        ((FAILED++))
        return 1
    fi
}

echo "═══════════════════════════════════════════════════════════════════"
echo "TESTANDO ESTRUTURA DE DIRETÓRIOS"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

test_dir "lib" "Diretório lib/"
test_dir "config" "Diretório config/"
test_dir "logs" "Diretório logs/"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "TESTANDO ARQUIVOS PRINCIPAIS"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

test_file "lib/common.sh" "Biblioteca de funções"
test_file "config/settings.conf" "Arquivo de configuração"
test_file "installer.sh" "Menu principal"
test_file "install_zabbix.sh" "Script de instalação Zabbix"
test_file "register_domain.sh" "Script de registro no domínio"
test_file "hostname.sh" "Script de configuração hostname"
test_file "KASPERSKY.sh" "Script de instalação Kaspersky"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "TESTANDO PERMISSÕES DE EXECUÇÃO"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

test_executable "lib/common.sh" "lib/common.sh"
test_executable "installer.sh" "installer.sh"
test_executable "install_zabbix.sh" "install_zabbix.sh"
test_executable "register_domain.sh" "register_domain.sh"
test_executable "hostname.sh" "hostname.sh"
test_executable "KASPERSKY.sh" "KASPERSKY.sh"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "TESTANDO SINTAXE DOS SCRIPTS"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

test_syntax "lib/common.sh" "lib/common.sh"
test_syntax "installer.sh" "installer.sh"
test_syntax "install_zabbix.sh" "install_zabbix.sh"
test_syntax "register_domain.sh" "register_domain.sh"
test_syntax "hostname.sh" "hostname.sh"
test_syntax "KASPERSKY.sh" "KASPERSKY.sh"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "TESTANDO DOCUMENTAÇÃO"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

test_file "README.md" "README.md"
test_file "QUICKSTART.md" "QUICKSTART.md"
test_file "MIGRATION.md" "MIGRATION.md"
test_file "EXAMPLES.md" "EXAMPLES.md"
test_file "CHANGELOG.md" "CHANGELOG.md"
test_file "SUMMARY.md" "SUMMARY.md"
test_file ".gitignore" ".gitignore"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "RESULTADO"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "✅ Testes passados: $PASSED"
echo "❌ Testes falhados: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "🎉 TODOS OS TESTES PASSARAM!"
    echo ""
    echo "Seu repositório está pronto para uso. Execute:"
    echo "  sudo ./installer.sh"
    echo ""
    exit 0
else
    echo "⚠️  ALGUNS TESTES FALHARAM"
    echo ""
    echo "Por favor, verifique os itens marcados com ❌"
    echo ""
    exit 1
fi

