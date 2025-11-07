# 🐧 Guia Específico para Debian

Este guia mostra como usar os scripts em sistemas Debian 11 e 12.

## ✅ Compatibilidade

| Versão | Status | Zabbix | Testado |
|--------|--------|--------|---------|
| Debian 11 (Bullseye) | ✅ Suportado | 6.0 | ✅ |
| Debian 12 (Bookworm) | ✅ Suportado | 6.0 | ✅ |

## 🚀 Instalação Rápida

### 1. Via Menu Interativo

```bash
# Clonar repositório
git clone https://github.com/seu-usuario/shell-install-applications-script.git
cd shell-install-applications-script

# Executar menu
sudo ./installer.sh

# Escolher opção 1: Instalar Zabbix Agent
```

### 2. Via Script Direto

```bash
# Executar instalação do Zabbix
sudo ./install_zabbix.sh
```

## 🔍 O Que o Script Faz no Debian

### Detecção Automática

```bash
# O script detecta automaticamente:
- Sistema: Debian
- Versão: 11 ou 12
- Repositório apropriado: Zabbix 6.0 para Debian
```

### Processo de Instalação

1. **Baixa o repositório oficial do Zabbix**
   ```bash
   wget https://repo.zabbix.com/zabbix/6.0/debian/pool/main/z/zabbix-release/zabbix-release_latest_6.0+debian12_all.deb
   ```

2. **Instala o repositório**
   ```bash
   dpkg -i zabbix-release_latest_6.0+debian12_all.deb
   apt update
   ```

3. **Instala o Zabbix Agent**
   ```bash
   apt install zabbix-agent -y
   ```

4. **Configura automaticamente**
   - Hostname do sistema
   - IP da máquina
   - Servidor Zabbix (configurável)
   - Porta 10050 (padrão)

5. **Inicia e habilita o serviço**
   ```bash
   systemctl restart zabbix-agent
   systemctl enable zabbix-agent
   ```

## ⚙️ Configurações Específicas

### Alterar Versão do Zabbix

Edite `config/settings.conf`:

```bash
# Para usar Zabbix 7.0 no Debian (se disponível)
ZABBIX_VERSION_DEBIAN="7.0"

# Para usar Zabbix 6.0 (padrão)
ZABBIX_VERSION_DEBIAN="6.0"
```

### Alterar Servidor Zabbix

```bash
# Método 1: Editar config/settings.conf
ZABBIX_PROXY_SERVER="seu.servidor.zabbix"

# Método 2: Passar como argumento
sudo ./install_zabbix.sh 192.168.1.100
```

## 📦 Pacotes Instalados

O script instala automaticamente:

- `zabbix-release` - Repositório oficial do Zabbix
- `zabbix-agent` - Agente de monitoramento Zabbix
- `wget` - Se não estiver instalado (dependência)

## 🔥 Firewall

### UFW (Firewall padrão do Debian/Ubuntu)

Se o UFW estiver ativo, o script automaticamente:

```bash
# Libera porta do Zabbix Agent
ufw allow 10050/tcp
```

Para verificar:

```bash
# Ver status do UFW
sudo ufw status

# Ver regras
sudo ufw status numbered
```

## ✅ Verificação Pós-Instalação

### 1. Verificar Serviço

```bash
# Status do serviço
sudo systemctl status zabbix-agent

# Ver se está ativo
sudo systemctl is-active zabbix-agent

# Ver se está habilitado
sudo systemctl is-enabled zabbix-agent
```

### 2. Verificar Conectividade

```bash
# Testar se a porta está aberta
sudo netstat -tlnp | grep 10050

# Ou com ss
sudo ss -tlnp | grep 10050

# Resultado esperado:
# tcp    0    0 0.0.0.0:10050    0.0.0.0:*    LISTEN    12345/zabbix_agentd
```

### 3. Verificar Configuração

```bash
# Ver configuração
sudo cat /etc/zabbix/zabbix_agentd.conf | grep -v "^#" | grep -v "^$"

# Verificar hostname configurado
grep "^Hostname=" /etc/zabbix/zabbix_agentd.conf

# Verificar servidor Zabbix
grep "^Server=" /etc/zabbix/zabbix_agentd.conf
```

### 4. Verificar Logs

```bash
# Log do Zabbix Agent
sudo tail -f /var/log/zabbix/zabbix_agentd.log

# Log da instalação do script
ls -lh logs/
tail -100 logs/installer_*.log
```

## 🐛 Troubleshooting

### Problema: Serviço não inicia

```bash
# Ver erro detalhado
sudo journalctl -u zabbix-agent -n 50

# Verificar arquivo de configuração
sudo zabbix_agentd -t agent.ping

# Reiniciar serviço
sudo systemctl restart zabbix-agent
```

### Problema: Não conecta ao servidor

```bash
# Verificar se consegue alcançar o servidor
ping seu.servidor.zabbix

# Testar porta
telnet seu.servidor.zabbix 10051

# Verificar firewall local
sudo ufw status
```

### Problema: Repositório não encontrado

```bash
# Atualizar repositórios
sudo apt update

# Limpar cache
sudo apt clean
sudo apt update

# Verificar se repositório foi adicionado
ls -la /etc/apt/sources.list.d/zabbix*
```

## 📝 Comandos Úteis

```bash
# Ver versão instalada do Zabbix
zabbix_agentd --version

# Ver informações do sistema
lsb_release -a
cat /etc/debian_version

# Reinstalar (se necessário)
sudo apt remove --purge zabbix-agent
sudo apt autoremove
sudo ./install_zabbix.sh

# Atualizar agente
sudo apt update
sudo apt upgrade zabbix-agent
sudo systemctl restart zabbix-agent
```

## 🔒 Segurança

### Restringir IPs que podem conectar

Edite `/etc/zabbix/zabbix_agentd.conf`:

```bash
# Permitir apenas servidor específico
Server=192.168.1.100

# Permitir múltiplos servidores
Server=192.168.1.100,192.168.1.101

# Para servidores ativos
ServerActive=192.168.1.100:10051
```

### Firewall Adicional

```bash
# Permitir apenas do servidor Zabbix
sudo ufw allow from 192.168.1.100 to any port 10050

# Ver regras
sudo ufw status numbered
```

## 🎯 Exemplos de Uso

### Instalação em Múltiplos Servidores Debian

```bash
#!/bin/bash
# install_zabbix_multiple_debian.sh

SERVERS=(
    "debian-server1.example.com"
    "debian-server2.example.com"
    "debian-server3.example.com"
)

ZABBIX_SERVER="10.130.3.201"

for server in "${SERVERS[@]}"; do
    echo "Configurando $server..."
    ssh root@$server "
        cd /tmp
        git clone https://github.com/seu-usuario/shell-install-applications-script.git
        cd shell-install-applications-script
        ./install_zabbix.sh $ZABBIX_SERVER
    "
done
```

### Instalação Automatizada com Ansible

```yaml
---
- name: Instalar Zabbix Agent em servidores Debian
  hosts: debian_servers
  become: yes
  
  vars:
    zabbix_server: "10.130.3.201"
  
  tasks:
    - name: Clonar repositório de scripts
      git:
        repo: 'https://github.com/seu-usuario/shell-install-applications-script.git'
        dest: /opt/install-scripts
        update: yes
    
    - name: Executar instalação do Zabbix
      command: ./install_zabbix.sh {{ zabbix_server }}
      args:
        chdir: /opt/install-scripts
```

## 📚 Referências

- [Documentação Oficial do Zabbix para Debian](https://www.zabbix.com/download?zabbix=6.0&os_distribution=debian&os_version=12&components=agent)
- [Debian Wiki - Zabbix](https://wiki.debian.org/Zabbix)
- [Zabbix Agent Configuration](https://www.zabbix.com/documentation/current/en/manual/appendix/config/zabbix_agentd)

## 🆘 Suporte

Se encontrar problemas específicos do Debian:

1. Verifique os logs: `logs/installer_*.log`
2. Verifique o log do Zabbix: `/var/log/zabbix/zabbix_agentd.log`
3. Consulte o README principal
4. Abra uma issue no GitHub

---

**Testado em:** Debian 11 (Bullseye) e Debian 12 (Bookworm)

**Última atualização:** 07/11/2025

