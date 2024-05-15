#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

# Function to check if a package is installed
is_package_installed() {
    rpm -q "$1" > /dev/null 2>&1
}

# Function to prompt for user input
get_user_input() {
    read -p "$1: " input
    echo "$input"
}

# Function to modify or create a configuration file
modify_config_file() {
    local file_path="$1"
    local pattern="$2"
    local replacement="$3"

    # Backup the original file
    cp "$file_path" "$file_path.bak"

    # Check if the pattern exists in the file
    if grep -q "$pattern" "$file_path"; then
        # Replace the existing line
        sed -i "/$pattern/c\\$replacement" "$file_path"
    else
        # Add the line if it doesn't exist
        echo "$replacement" >> "$file_path"
    fi
}

# List of packages to be installed
packages=("sssd" "realmd" "oddjob" "oddjob-mkhomedir" "adcli" "samba-common" "samba-common-tools" "krb5-workstation" "openldap-clients")

# Check and install packages if not installed
for package in "${packages[@]}"; do
    if ! is_package_installed "$package"; then
        echo "Installing $package..."
        yum install "$package" -y
        if [ $? -ne 0 ]; then
            echo "Failed to install $package. Exiting."
            exit 1
        fi
    else
        echo "$package is already installed."
    fi
done

# Prompt for domain, username, and password
domain=$(get_user_input "Enter the domain")
username=$(get_user_input "Enter the username")
password=$(get_user_input "Enter the password")

# Register the computer to the domain
echo "Joining $domain..."
realm join --user="$username" "$domain"

# Check the join status
if [ $? -eq 0 ]; then
    echo "Computer successfully registered to the domain."

    # Prompt for the group for SSH and Sudo access
    group=$(get_user_input "Enter the group for SSH and Sudo access")

    # Modify /etc/sssd/sssd.conf
    sssd_conf="/etc/sssd/sssd.conf"
    modify_config_file "$sssd_conf" "use_fully_qualified_names" "use_fully_qualified_names = False"
    modify_config_file "$sssd_conf" "fallback_homedir" "fallback_homedir = /home/%u"
    
    # Replace access_provider lines
    sed -i '/^access_provider =/ s/ad/simple/' "$sssd_conf"
    sed -i '/^access_provider =/ s/AD/simple/' "$sssd_conf"

    # Modify /etc/sudoers.d/sudoers
    sudoers_file="/etc/sudoers.d/sudoers"
    sudoers_line="%$group ALL=(ALL) ALL"
    modify_config_file "$sudoers_file" "%$group" "$sudoers_line"

    echo "Configuration files updated."

    # Restart services
    systemctl restart sssd
    systemctl restart sshd

    echo "sssd and sshd services restarted."
else
    echo "Failed to register the computer to the domain. Please check the configuration."
fi
