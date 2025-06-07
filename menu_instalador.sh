#!/bin/bash

# Diretório do script atual
SCRIPT_DIR=$(dirname "$0")

SCRIPTS=(
    "install_zabbix_rocky.sh"
    "install_zabbix_ubuntu.sh"
    "instalacao-zabbix2.sh"
    "instalador_linux.sh"
    "hostname.sh"
    "KASPERSKY.sh"
    "registrar_no_dominio.sh"
    "registrar_no_dominio_ubuntu.sh"
)

mostrar_menu() {
    echo "SHELL - INSTALADOR"
    i=1
    for script in "${SCRIPTS[@]}"; do
        nome="${script%.sh}"
        echo "$i) $nome"
        i=$((i+1))
    done
    echo "$i) Sair"
}

executar_opcao() {
    escolha=$1
    index=$((escolha-1))
    if [ "$escolha" -eq $(( ${#SCRIPTS[@]} + 1 )) ]; then
        exit 0
    elif [ "$index" -ge 0 ] && [ "$index" -lt "${#SCRIPTS[@]}" ]; then
        script="${SCRIPTS[$index]}"
        chmod +x "$SCRIPT_DIR/$script"
        bash "$SCRIPT_DIR/$script"
    else
        echo "Opção inválida."
    fi
}

while true; do
    mostrar_menu
    read -rp "Digite sua escolha: " escolha
    executar_opcao "$escolha"
    echo
done
