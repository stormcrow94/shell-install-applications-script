#!/bin/bash

# Variables
ZABBIX_SERVER=10.130.3.201
ZABBIX_SERVER_PROXY=10.130.3.201
ZABBIX_API_URL="https://zabbix.vantix.com.br/api_jsonrpc.php"
TEMPLATE_NAME="Linux by Zabbix agent active"
GROUP_ID="2"  # Change this to the appropriate group ID if needed
PROXY_NAME="com-spozbx-proxy"  # Change this to the appropriate proxy name

# Prompt for Zabbix API credentials
read -p "Enter Zabbix API user: " ZABBIX_API_USER
read -sp "Enter Zabbix API password: " ZABBIX_API_PASS
echo

# Install Zabbix repository
rpm -Uvh https://repo.zabbix.com/zabbix/6.4/rhel/7/x86_64/zabbix-release-6.4-1.el7.noarch.rpm

# Install Zabbix agent
yum install zabbix-agent -y

# Get the hostname and IP address of the computer
HOSTNAME=$(hostname)
IP_ADDRESS=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | grep '10.130.3.42')

# Configure zabbix_agentd.conf
sed -i "s/^Server=.*/Server=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^ServerActive=.*/ServerActive=$ZABBIX_SERVER_PROXY/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^Hostname=.*/Hostname=$IP_ADDRESS/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/# StartAgents=.*/StartAgents=3/" /etc/zabbix/zabbix_agentd.conf

# Start and enable Zabbix agent
systemctl restart zabbix-agent
systemctl enable zabbix-agent

# Install jq for JSON processing
yum install jq -y

# Authenticate with the Zabbix API
AUTH_PAYLOAD=$(cat <<EOF
{
    "jsonrpc": "2.0",
    "method": "user.login",
    "params": {
        "username": "$ZABBIX_API_USER",
        "password": "$ZABBIX_API_PASS"
    },
    "id": 1,
    "auth": null
}
EOF
)

echo "Auth Payload: $AUTH_PAYLOAD"

AUTH_RESPONSE=$(curl -k -s -X POST -H 'Content-Type: application/json' \
-d "$AUTH_PAYLOAD" $ZABBIX_API_URL)

echo "Auth Response: $AUTH_RESPONSE"

AUTH_TOKEN=$(echo $AUTH_RESPONSE | jq -r '.result')
if [ -z "$AUTH_TOKEN" ]; then
    ERROR_MESSAGE=$(echo $AUTH_RESPONSE | jq -r '.error.message')
    echo "Error during authentication: $ERROR_MESSAGE"
    exit 1
fi
echo "Auth Token: $AUTH_TOKEN"

# Get the template ID
TEMPLATE_PAYLOAD=$(cat <<EOF
{
    "jsonrpc": "2.0",
    "method": "template.get",
    "params": {
        "output": "templateid",
        "filter": {
            "host": ["$TEMPLATE_NAME"]
        }
    },
    "id": 1,
    "auth": "$AUTH_TOKEN"
}
EOF
)

echo "Template Payload: $TEMPLATE_PAYLOAD"

TEMPLATE_RESPONSE=$(curl -k -s -X POST -H 'Content-Type: application/json' \
-d "$TEMPLATE_PAYLOAD" $ZABBIX_API_URL)

echo "Template Response: $TEMPLATE_RESPONSE"

TEMPLATE_ID=$(echo $TEMPLATE_RESPONSE | jq -r '.result[0].templateid')
if [ -z "$TEMPLATE_ID" ]; then
    ERROR_MESSAGE=$(echo $TEMPLATE_RESPONSE | jq -r '.error.message')
    echo "Error during template lookup: $ERROR_MESSAGE"
    exit 1
fi
echo "Template ID: $TEMPLATE_ID"

# Get the proxy ID
PROXY_PAYLOAD=$(cat <<EOF
{
    "jsonrpc": "2.0",
    "method": "proxy.get",
    "params": {
        "output": "extend",
        "filter": {
            "host": ["$PROXY_NAME"]
        }
    },
    "id": 1,
    "auth": "$AUTH_TOKEN"
}
EOF
)

echo "Proxy Payload: $PROXY_PAYLOAD"

PROXY_RESPONSE=$(curl -k -s -X POST -H 'Content-Type: application/json' \
-d "$PROXY_PAYLOAD" $ZABBIX_API_URL)

echo "Proxy Response: $PROXY_RESPONSE"

PROXY_ID=$(echo $PROXY_RESPONSE | jq -r '.result[0].proxyid')
if [ -z "$PROXY_ID" ]; then
    ERROR_MESSAGE=$(echo $PROXY_RESPONSE | jq -r '.error.message')
    echo "Error during proxy lookup: $ERROR_MESSAGE"
    exit 1
fi
echo "Proxy ID: $PROXY_ID"

# Check if the host already exists by hostname
HOST_EXISTS_PAYLOAD=$(cat <<EOF
{
    "jsonrpc": "2.0",
    "method": "host.get",
    "params": {
        "output": "hostid",
        "filter": {
            "host": ["$HOSTNAME"]
        }
    },
    "id": 1,
    "auth": "$AUTH_TOKEN"
}
EOF
)

echo "Host Exists Payload: $HOST_EXISTS_PAYLOAD"

HOST_EXISTS_RESPONSE=$(curl -k -s -X POST -H 'Content-Type: application/json' \
-d "$HOST_EXISTS_PAYLOAD" $ZABBIX_API_URL)

echo "Host Exists Response: $HOST_EXISTS_RESPONSE"

HOST_ID=$(echo $HOST_EXISTS_RESPONSE | jq -r '.result[0].hostid')

# If host exists, update it; otherwise, create it
if [ -n "$HOST_ID" ]; then
    UPDATE_HOST_PAYLOAD=$(cat <<EOF
{
    "jsonrpc": "2.0",
    "method": "host.update",
    "params": {
        "hostid": "$HOST_ID",
        "interfaces": [
            {
                "type": 1,
                "main": 1,
                "useip": 1,
                "ip": "$IP_ADDRESS",
                "dns": "",
                "port": "10050"
            }
        ],
        "groups": [
            {
                "groupid": "$GROUP_ID"
            }
        ],
        "templates": [
            {
                "templateid": "$TEMPLATE_ID"
            }
        ],
        "proxy_hostid": "$PROXY_ID"
    },
    "id": 1,
    "auth": "$AUTH_TOKEN"
}
EOF
)

    echo "Update Host Payload: $UPDATE_HOST_PAYLOAD"

    UPDATE_HOST_RESPONSE=$(curl -k -s -X POST -H 'Content-Type: application/json' \
    -d "$UPDATE_HOST_PAYLOAD" $ZABBIX_API_URL)

    echo "Update Host Response: $UPDATE_HOST_RESPONSE"
    if echo $UPDATE_HOST_RESPONSE | jq -e '.error' > /dev/null; then
        ERROR_MESSAGE=$(echo $UPDATE_HOST_RESPONSE | jq -r '.error.message')
        echo "Error during host update: $ERROR_MESSAGE"
        exit 1
    fi

    echo "Zabbix agent installed, configured, and host updated in Zabbix."
else
    CREATE_HOST_PAYLOAD=$(cat <<EOF
{
    "jsonrpc": "2.0",
    "method": "host.create",
    "params": {
        "host": "$HOSTNAME",
        "interfaces": [
            {
                "type": 1,
                "main": 1,
                "useip": 1,
                "ip": "$IP_ADDRESS",
                "dns": "",
                "port": "10050"
            }
        ],
        "groups": [
            {
                "groupid": "$GROUP_ID"
            }
        ],
        "templates": [
            {
                "templateid": "$TEMPLATE_ID"
            }
        ],
        "proxy_hostid": "$PROXY_ID"
    },
    "id": 1,
    "auth": "$AUTH_TOKEN"
}
EOF
)

    echo "Create Host Payload: $CREATE_HOST_PAYLOAD"

    CREATE_HOST_RESPONSE=$(curl -k -s -X POST -H 'Content-Type: application/json' \
    -d "$CREATE_HOST_PAYLOAD" $ZABBIX_API_URL)

    echo "Create Host Response: $CREATE_HOST_RESPONSE"
    if echo $CREATE_HOST_RESPONSE | jq -e '.error' > /dev/null; then
        ERROR_MESSAGE=$(echo $CREATE_HOST_RESPONSE | jq -r '.error.message')
        echo "Error during host creation: $ERROR_MESSAGE"
        exit 1
    fi

    echo "Zabbix agent installed, configured, and host created in Zabbix."
fi
