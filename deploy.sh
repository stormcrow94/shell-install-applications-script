#!/bin/bash

# Variables
REPO_URL="https://github.com/stormcrow94/shell-install-applications-script.git"
LOCAL_DIR="shell-install-applications-script"
MAIN_SCRIPT="instalador_linux.sh"

# Clone the repository
if [ -d "$LOCAL_DIR" ]; then
    echo "Directory $LOCAL_DIR already exists. Pulling latest changes..."
    cd $LOCAL_DIR
    git pull
else
    echo "Cloning repository..."
    git clone $REPO_URL $LOCAL_DIR
    cd $LOCAL_DIR
fi

# Make sure the main script is executable
chmod +x $MAIN_SCRIPT

# Run the main script
./$MAIN_SCRIPT

