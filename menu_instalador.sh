#!/bin/bash

# Diretório do script atual
SCRIPT_DIR=$(dirname "$0")

mostrar_menu() {
    echo "SHELL - INSTALADOR"
    echo "1) Instalar Zabbix (Rocky)"
    echo "2) Instalar Zabbix Ubuntu"
    echo "3) Sair"
}

executar_opcao() {
    case "$1" in
        1)
            bash "$SCRIPT_DIR/install_zabbix_rocky.sh"
            ;;
        2)
            bash "$SCRIPT_DIR/install_zabbix_ubuntu.sh"
            ;;
        3)
            exit 0
            ;;
        *)
            echo "Opção inválida."
            ;;
    esac
}

while true; do
    mostrar_menu
    read -rp "Digite sua escolha: " escolha
    executar_opcao "$escolha"
    echo
done
