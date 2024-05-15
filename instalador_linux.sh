#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR=$(dirname "$0")

# Function to display the menu
mostrar_menu() {
    echo "Selecione uma opção:"
    echo "1. Instalar Zabbix"
    echo "2. Configurar Nome do Host"
    echo "3. Instalar Kaspersky"
    echo "4. Registrar no Domínio"
    echo "5. Sair"
}

# Function to handle user choice
executar_opcao() {
    case $1 in
        1)
            echo "Executando script de instalação do Zabbix..."
            bash "$SCRIPT_DIR/instalacao-zabbix2.sh"
            ;;
        2)
            echo "Executando script de configuração do nome do host..."
            bash "$SCRIPT_DIR/hostname.sh"
            ;;
        3)
            echo "Executando script de instalação do Kaspersky..."
            bash "$SCRIPT_DIR/KASPERSKY.sh"
            ;;
        4)
            echo "Executando script de registro no domínio..."
            bash "$SCRIPT_DIR/registrar_no_dominio.sh"
            ;;
        5)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo "Opção inválida. Por favor, selecione uma opção válida."
            ;;
    esac
}

# Main loop
while true; do
    mostrar_menu
    read -p "Digite sua escolha: " escolha
    executar_opcao $escolha
done
