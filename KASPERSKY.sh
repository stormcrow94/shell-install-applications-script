#!/bin/bash

# Check if smbclient is installed
if ! command -v smbclient &> /dev/null; then
    echo "smbclient is not installed. Installing..."
    sudo yum install samba-client -y
    if [ $? -ne 0 ]; then
        echo "Failed to install smbclient. Exiting."
        exit 1
    fi
    echo "smbclient installed successfully."
fi

# File server details
file_server="10.130.2.10"
share_name="KASPERSKY-STAND-ALONE-INSTALL"
scripts_dir="/"

# Mount directory
mount_dir="/mnt/file_server"

# Create the mount directory if it does not exist
if [ ! -d "$mount_dir" ]; then
    echo "Creating mount directory: $mount_dir"
    sudo mkdir -p "$mount_dir"
fi

# Prompt for SMB credentials
read -p "Enter SMB username: " smb_username
read -s -p "Enter SMB password: " smb_password
echo

# Mount the file server share with credentials
echo "Mounting the file server share..."
sudo mount -t cifs //$file_server/$share_name $mount_dir -o username=$smb_username,password=$smb_password
if [ $? -ne 0 ]; then
    echo "Failed to mount the file server share. Exiting."
    exit 1
fi

# Run KLNA -15 script
echo "Running KLNA -15 installation script..."
sudo sh "$mount_dir$scripts_dir/KLNA -15 (Agente de rede para linux RPM).sh"
if [ $? -ne 0 ]; then
    echo "Failed to run KLNA -15 installation script."
    sudo umount $mount_dir
    exit 1
fi

# Run KESL - 12.0 script
echo "Running KESL - 12.0 installation script..."
sudo sh "$mount_dir$scripts_dir/KESL - 12.0 (Para todos os dispositivos linux).sh"
if [ $? -ne 0 ]; then
    echo "Failed to run KESL - 12.0 installation script."
fi

# Unmount the file server share
echo "Unmounting the file server share..."
sudo umount $mount_dir

echo "Script execution complete."
