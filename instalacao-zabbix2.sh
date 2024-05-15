#!/bin/bash

# Variables
ZABBIX_PROXY_SERVER="10.130.3.201"

# Install Zabbix repository
rpm -Uvh https://repo.zabbix.com/zabbix/6.4/rhel/7/x86_64/zabbix-release-6.4-1.el7.noarch.rpm

# Install Zabbix agent
yum install zabbix-agent -y

# Get the hostname and IP address of the computer
HOSTNAME=$(hostname)
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Configure zabbix_agentd.conf
sed -i "s/^Server=.*/Server=$ZABBIX_PROXY_SERVER/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^ServerActive=.*/ServerActive=$ZABBIX_PROXY_SERVER/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^Hostname=.*/Hostname=$HOSTNAME/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/# StartAgents=.*/StartAgents=3/" /etc/zabbix/zabbix_agentd.conf

# Start and enable Zabbix agent
systemctl restart zabbix-agent
systemctl enable zabbix-agent

echo "Zabbix agent installed and configured. Hostname: $HOSTNAME, IP Address: $IP_ADDRESS."
