# 🚀 Guia Rápido - Instalação do Wazuh Agent

## ⚡ Teste Rápido

### Opção 1: Instalação Direta

```bash
cd /home/luciano/Documents/shell-install-applications-script
sudo ./install_wazuh.sh
```

### Opção 2: Via Menu Interativo

```bash
cd /home/luciano/Documents/shell-install-applications-script
sudo ./installer.sh
# Digite: 3
```

---

## 🔍 Verificação

Após a instalação, verifique se tudo está funcionando:

```bash
# 1. Status do serviço
systemctl status wazuh-agent

# 2. Verificar se está habilitado
systemctl is-enabled wazuh-agent

# 3. Ver logs do Wazuh
tail -n 50 /var/ossec/logs/ossec.log

# 4. Verificar conectividade com o manager
grep "Connected to the server" /var/ossec/logs/ossec.log
```

---

## ⚙️ Configuração Customizada

Se quiser usar um manager diferente:

```bash
# Editar configuração
nano config/settings.conf

# Procure por:
WAZUH_MANAGER="wazuh.vantix.com.br"

# Altere para o seu manager e salve

# Execute a instalação
sudo ./install_wazuh.sh
```

Ou diretamente via linha de comando:

```bash
sudo ./install_wazuh.sh seu-manager.exemplo.com.br
```

---

## 📋 Comandos Úteis

```bash
# Reiniciar o agente
sudo systemctl restart wazuh-agent

# Parar o agente
sudo systemctl stop wazuh-agent

# Ver informações do agente
sudo /var/ossec/bin/wazuh-control info

# Ver status detalhado
sudo /var/ossec/bin/wazuh-control status

# Ver arquivo de configuração
sudo cat /var/ossec/etc/ossec.conf
```

---

## 🐛 Resolução de Problemas

### Agente não conecta ao manager

```bash
# 1. Verificar se o manager está acessível
ping wazuh.vantix.com.br

# 2. Verificar portas (1514 TCP, 1515 TCP)
telnet wazuh.vantix.com.br 1514

# 3. Verificar logs
tail -f /var/ossec/logs/ossec.log

# 4. Verificar configuração
grep -i "server" /var/ossec/etc/ossec.conf
```

### Serviço não inicia

```bash
# 1. Ver erros detalhados
sudo journalctl -u wazuh-agent -n 50

# 2. Verificar permissões
ls -la /var/ossec/

# 3. Tentar iniciar manualmente
sudo /var/ossec/bin/wazuh-control start
```

---

## 📝 Logs da Instalação

Todos os detalhes da instalação são salvos em:

```bash
# Ver último log
ls -lt logs/ | head -1

# Ver logs completos
tail -f logs/installer_*.log

# Buscar erros
grep -i error logs/*.log

# Buscar instalações do Wazuh
grep -i wazuh logs/*.log
```

---

## 🎯 Próximos Passos

1. ✅ Instalar o Wazuh Agent (você acabou de fazer!)
2. 📊 Verificar no dashboard do Wazuh Manager se o agente apareceu
3. 🔐 Configurar políticas de segurança no manager
4. 📈 Configurar alertas e notificações
5. 🔄 Repetir o processo em outros servidores

---

## 💡 Dica

Para instalar em múltiplos servidores, você pode usar:

```bash
#!/bin/bash
SERVERS="server1 server2 server3"

for server in $SERVERS; do
    echo "Instalando Wazuh em $server..."
    ssh root@$server "cd /opt/scripts && ./install_wazuh.sh"
done
```

---

**Pronto! Seu Wazuh Agent está instalado e funcionando! 🎉**

