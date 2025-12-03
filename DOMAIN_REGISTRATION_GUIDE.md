# Domain Registration Script - User Guide

## 🎯 Overview

The `register_domain.sh` script has been updated to address SSSD access control issues that could prevent valid domain users from logging in via SSH.

## 🔧 What Was Fixed

### Previous Issue
The script was automatically setting:
- `access_provider = simple`
- `simple_allow_groups = "<SPECIFIC_GROUP>"`

This caused:
- ✅ Users could be looked up (`id username` worked)
- ❌ SSH login failed with "Access denied by PAM account configuration"
- 🔍 Only users in the exact specified group could log in

### New Solution
The script now offers **two modes** during setup:

#### Mode 1: PERMISSIVE (Recommended for Dev/Test)
- **Access Control**: `access_provider = ad`
- **Who can login**: All domain users
- **Security**: Uses Active Directory's own access policies
- **Best for**: Development, testing, or environments where all domain users should have access

#### Mode 2: RESTRICTED (Recommended for Production)
- **Access Control**: `access_provider = simple` with `simple_allow_groups`
- **Who can login**: Only users in the specified group
- **Security**: Maximum control - explicit group membership required
- **Best for**: Production environments with strict security requirements

## 📝 Usage

### Running the Script

```bash
sudo ./register_domain.sh
```

### Interactive Prompts

1. **Domain**: Enter your domain (e.g., `center.local`)
2. **Admin Username**: Enter an admin account (e.g., `fortigate`)
3. **Password**: Enter the admin password
4. **Group for Sudo**: Enter the group that should have sudo access
5. **Access Control Mode**: Choose between:
   - `1` - Permissive (all domain users can SSH)
   - `2` - Restricted (only specified group can SSH)

### Example Session

```
================================
  Registro no Domínio
================================

Digite o domínio (ex: center.local): center.local
Digite o nome do usuário administrador (ex: fortigate): fortigate
Digite a senha: ********
Digite o grupo para SSH e Sudo (ex: SUDOERS_COMMSHOP_PRD): SUDOERS_COMMSHOP_PRD

Escolha o método de controle de acesso:
1) Permitir TODOS os usuários do domínio (recomendado para ambientes de desenvolvimento/teste)
2) Restringir acesso apenas ao grupo especificado (mais seguro para produção)

Escolha [1-2] (padrão: 1): 1
Modo PERMISSIVO: todos os usuários do domínio poderão fazer login
```

## ✅ Verification

After running the script, verify the setup:

```bash
# Check domain registration
realm list

# Check if user can be resolved
id username
getent passwd username

# Test SSH login locally
ssh username@localhost

# View SSSD configuration
sudo cat /etc/sssd/sssd.conf | grep -A5 "access_provider"

# View SSSD logs
sudo journalctl -u sssd -n 50
```

## 🔍 Troubleshooting

### Issue: User can't SSH but `id` works

**Symptoms:**
```
$ id marcelo.carvalho
uid=12345(marcelo.carvalho) gid=10001(users) groups=...

$ ssh marcelo.carvalho@localhost
Access denied for user marcelo.carvalho by PAM account configuration
```

**Solution 1: Check Current Configuration**
```bash
sudo grep -E "(access_provider|simple_allow_groups)" /etc/sssd/sssd.conf
```

**Solution 2: Switch to Permissive Mode**
```bash
# Edit SSSD config
sudo nano /etc/sssd/sssd.conf

# Change:
access_provider = simple
simple_allow_groups = "GROUP_NAME"

# To:
access_provider = ad
#simple_allow_groups = "GROUP_NAME"

# Restart SSSD
sudo systemctl stop sssd
sudo rm -rf /var/lib/sss/db/* /var/lib/sss/mc/*
sudo systemctl start sssd
```

**Solution 3: Add User's Group to Allowed Groups**
```bash
# Check user's groups
id username

# Edit SSSD config and add the group(s)
sudo nano /etc/sssd/sssd.conf

# Add multiple groups separated by commas:
simple_allow_groups = "GROUP1, GROUP2, GROUP3"

# Restart SSSD
sudo systemctl stop sssd
sudo rm -rf /var/lib/sss/db/* /var/lib/sss/mc/*
sudo systemctl start sssd
```

### Issue: SSSD not starting

```bash
# Check SSSD status
sudo systemctl status sssd

# View detailed logs
sudo journalctl -u sssd -xe

# Validate configuration
sudo sssctl config-check

# Common fixes:
sudo chmod 600 /etc/sssd/sssd.conf
sudo chown root:root /etc/sssd/sssd.conf
```

### Issue: Home directory not created

```bash
# Check PAM configuration
grep pam_mkhomedir /etc/pam.d/common-session

# Should contain:
session optional pam_mkhomedir.so skel=/etc/skel umask=0077

# If missing, add it:
echo "session optional pam_mkhomedir.so skel=/etc/skel umask=0077" | sudo tee -a /etc/pam.d/common-session
```

## 🔐 Security Considerations

### Permissive Mode (`access_provider = ad`)
- **Pros:**
  - All domain users can log in
  - Easier to manage
  - No group membership issues
- **Cons:**
  - Less restrictive
  - Relies on AD's own access controls
- **Use when:** You trust all domain users and want simple management

### Restricted Mode (`access_provider = simple`)
- **Pros:**
  - Maximum control over who can SSH
  - Explicit group membership required
  - Better for compliance requirements
- **Cons:**
  - Requires careful group management
  - Can lock out valid users if groups aren't configured correctly
- **Use when:** You need strict control over SSH access

## 📚 Additional Resources

- [Red Hat - Managing User Access](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_authentication_and_authorization_in_rhel/managing-user-access_configuring-authentication-and-authorization-in-rhel)
- [SSSD Configuration](https://sssd.io/docs/users/configuration.html)
- [Active Directory Integration](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/integrating_rhel_systems_directly_with_windows_active_directory/index)

## 🛠️ Manual Configuration

If you need to manually adjust the configuration later:

```bash
# Edit SSSD config
sudo nano /etc/sssd/sssd.conf

# Make changes to access_provider and simple_allow_groups

# Clear cache and restart
sudo systemctl stop sssd
sudo rm -rf /var/lib/sss/db/* /var/lib/sss/mc/*
sudo systemctl start sssd
sudo systemctl status sssd
```

## 📞 Support

If you encounter issues:
1. Check the logs: `sudo journalctl -u sssd -n 100`
2. Verify DNS: `nslookup domain.local`
3. Test Kerberos: `kinit username@DOMAIN.LOCAL`
4. Check network: Ensure ports 88 (Kerberos), 389 (LDAP), 445 (SMB) are open
5. Review auth logs: `sudo tail -f /var/log/auth.log`

---

**Last Updated:** December 3, 2025
**Script Version:** 2.0 (with access control options)

