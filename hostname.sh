#!/bin/bash

# Check if the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" 
    exit 1
fi

# Prompt the user to input the new hostname
read -p "Enter the new hostname: " new_hostname

# Change the hostname
hostnamectl set-hostname "$new_hostname"

# Display the new hostname
echo "Hostname has been changed to: $new_hostname"
