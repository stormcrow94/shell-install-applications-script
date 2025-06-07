# Shell Install Applications Script

Coleção de scripts em Shell para automatizar a instalação e configuração de serviços em sistemas Linux. O repositório inclui scripts para instalação do agente Zabbix, configuração de hostname, instalação do Kaspersky e integração ao domínio via SSSD/Realmd.

## Pré-requisitos

- Bash
- Permissões de root (vários scripts executam comandos de instalação e serviços)
- Conexão de rede para baixar pacotes e dependências

## Visão geral dos scripts

| Script                          | Descrição |
|--------------------------------|-----------|
| `instalador_linux.sh`          | Menu interativo que permite escolher a execução de outros scripts (instalar Zabbix, configurar hostname, instalar Kaspersky ou registrar no domínio). |
| `instalacao-zabbix2.sh`        | Instala o agente Zabbix em distribuições baseadas em RHEL/CentOS 7 usando `yum`. |
| `install_zabbix_rocky.sh`      | Instala o agente Zabbix em Rocky Linux (RHEL 9) utilizando `dnf`. |
| `install_zabbix_ubuntu.sh`     | Instala o agente Zabbix em distribuições Ubuntu. |
| `KASPERSKY.sh`                 | Monta um compartilhamento SMB e executa scripts de instalação do Kaspersky. |
| `hostname.sh`                  | Altera o hostname da máquina. |
| `registrar_no_dominio.sh`      | Realiza o ingresso no domínio (SSSD/Realmd) em sistemas RHEL/CentOS/Rocky. |
| `registrar_no_dominio_ubuntu.sh` | Versão do script de registro em domínio para Ubuntu. |

## Como usar

1. Clone este repositório em sua máquina.
2. Dê permissão de execução aos scripts desejados:

   ```bash
   chmod +x nome_do_script.sh
   ```

3. Execute o script apropriado para sua distribuição Linux com privilégios de superusuário.  
   Por exemplo, para utilizar o menu principal:

   ```bash
   sudo ./instalador_linux.sh
   ```

   Siga as instruções que aparecerem na tela para escolher a tarefa que deseja executar.

4. Alguns scripts solicitarão informações adicionais (por exemplo, domínio, usuário e senha).  
   Insira os dados conforme solicitado.

## Observações

- O endereço do servidor proxy do Zabbix (`ZABBIX_PROXY_SERVER`) está definido dentro de cada script e pode ser ajustado conforme sua infraestrutura.
- Certifique-se de que todos os pacotes necessários estejam disponíveis nos repositórios configurados ou em espelhos acessíveis.
- É recomendado ler cada script antes de executá-lo para entender as mudanças que serão feitas no sistema.

