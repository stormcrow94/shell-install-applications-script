# ⚡ Guia Rápido de Início

Guia de 5 minutos para começar a usar os scripts.

## 🚀 Instalação Rápida

```bash
# 1. Clonar repositório
git clone https://github.com/seu-usuario/shell-install-applications-script.git
cd shell-install-applications-script

# 2. Tornar executável
chmod +x installer.sh

# 3. Executar menu
sudo ./installer.sh
```

## 📋 Uso Mais Comum

### Cenário 1: Novo Servidor (Setup Completo)

```bash
sudo ./installer.sh
# Selecione: 5) Executar Tudo (Modo Completo)
# Siga as instruções na tela
```

### Cenário 2: Apenas Instalar Zabbix

```bash
sudo ./install_zabbix.sh
```

### Cenário 3: Apenas Registrar no Domínio

```bash
sudo ./register_domain.sh
```

## ⚙️ Configuração Básica

Antes de usar, personalize as configurações:

```bash
# Editar configurações
nano config/settings.conf

# Altere pelo menos:
ZABBIX_PROXY_SERVER="SEU_IP_ZABBIX"
```

> Para instalar o Sophos, mantenha o arquivo `SophosSetup.sh` no diretório raiz e, se necessário, passe argumentos diretamente ao script (ex.: `sudo ./SophosSetup.sh --group="Servidor/Linux"`).

## 📖 Menu Principal

Ao executar `sudo ./installer.sh`, você verá:

```
╔═══════════════════════════════════════╗
║         MENU PRINCIPAL                ║
╚═══════════════════════════════════════╝

1) Instalar Zabbix Agent
2) Configurar Hostname
3) Instalar Wazuh Agent
4) Instalar Sophos
5) Registrar no Domínio
6) Executar Tudo (Modo Completo)
7) Configurações
8) Ver Logs
0) Sair
```

## 🔍 Verificação

Após instalar, verifique:

```bash
# Zabbix
systemctl status zabbix-agent

# Domínio
realm list
id usuario@dominio.com

# Logs
ls -lh logs/
```

## 🆘 Problemas Comuns

### "Permission denied"
```bash
chmod +x *.sh
sudo ./installer.sh
```

### "Biblioteca não encontrada"
```bash
# Verifique estrutura
ls -la lib/common.sh
```

### Scripts antigos não funcionam
```bash
# Use os novos scripts unificados
./install_zabbix.sh      # Em vez de install_zabbix_ubuntu.sh
./register_domain.sh     # Em vez de registrar_no_dominio.sh
```

## 📚 Mais Informações

- 📖 **Documentação completa:** [README.md](README.md)
- 🧭 **Documentação técnica:** [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md)
- 📚 **Exemplos práticos:** [EXAMPLES.md](EXAMPLES.md)
- 📘 **Wiki do projeto:** [WIKI.md](WIKI.md)

## 💡 Dicas

1. **Sempre execute como root** - `sudo ./script.sh`
2. **Verifique os logs** - `logs/installer_*.log`
3. **Personalize as configs** - `config/settings.conf`
4. **Use o menu** - Mais fácil e seguro
5. **Leia README** - Documentação detalhada

## 🎯 Comandos Essenciais

```bash
# Menu interativo
sudo ./installer.sh

# Instalar Zabbix
sudo ./install_zabbix.sh

# Configurar hostname
sudo ./hostname.sh

# Registrar no domínio
sudo ./register_domain.sh

# Ver logs
ls -lh logs/

# Editar configurações
nano config/settings.conf
```

## ✅ Checklist Pós-Instalação

- [ ] Zabbix agent está rodando
- [ ] Hostname configurado corretamente
- [ ] Sistema registrado no domínio (se aplicável)
- [ ] Logs verificados sem erros
- [ ] Teste de login com usuário do domínio

---

**Pronto!** Agora você está pronto para usar os scripts. 🎉

**Precisa de ajuda?** Consulte o [README.md](README.md) ou abra uma issue no GitHub.

