#!/bin/bash

# Variables
ZABBIX_PROXY_SERVER="10.130.3.201"

# Install Zabbix repository
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_7.0-2+ubuntu24.04_all.deb
sudo apt-get update

# Install Zabbix agent
sudo apt-get install zabbix-agent -y

# Get the hostname and IP address of the computer
HOSTNAME=$(hostname)
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Create a new zabbix_agentd.conf configuration file
sudo tee /etc/zabbix/zabbix_agentd.conf > /dev/null <<EOL
# This is a configuration file for Zabbix agent daemon (Unix)
# To get more information about Zabbix, visit http://www.zabbix.com

############ GENERAL PARAMETERS #################

### Option: PidFile
# Name of PID file.
PidFile=/var/run/zabbix/zabbix_agentd.pid

### Option: LogFile
# Log file name for LogType 'file' parameter.
LogFile=/var/log/zabbix/zabbix_agentd.log

### Option: LogFileSize
# Maximum size of log file in MB.
LogFileSize=10

### Option: DebugLevel
# Specifies debug level:
# 0 - basic information about starting and stopping of Zabbix processes
# 1 - critical information
# 2 - error information
# 3 - warnings
# 4 - for debugging (produces lots of information)
# 5 - extended debugging (produces even more information)
DebugLevel=3

### Option: Server
# List of comma delimited IP addresses of Zabbix servers and Zabbix proxies.
Server=$ZABBIX_PROXY_SERVER

### Option: ListenPort
# Agent will listen on this port for connections from the server.
ListenPort=10050

### Option: ListenIP
# List of comma delimited IP addresses that the agent should listen on.
ListenIP=0.0.0.0

### Option: StartAgents
# Number of pre-forked instances of zabbix_agentd that process passive checks.
StartAgents=3

### Option: ServerActive
# List of comma delimited IP:port pairs of Zabbix servers and Zabbix proxies for active checks.
ServerActive=$ZABBIX_PROXY_SERVER:10051

### Option: Hostname
# Unique, case sensitive hostname.
Hostname=$HOSTNAME

### Option: Include
# You may include individual files or all files in a directory in the configuration file.
Include=/etc/zabbix/zabbix_agentd.d/*.conf

############ END OF CONFIGURATION #################
EOL

# Start and enable Zabbix agent
sudo systemctl restart zabbix-agent
sudo systemctl enable zabbix-agent

echo "Zabbix agent installed and configured. Hostname: $HOSTNAME, IP Address: $IP_ADDRESS."
