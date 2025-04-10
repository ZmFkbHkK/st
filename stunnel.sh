#!/bin/bash

# ==============================================
# AUTO INSTALL STUNNEL4 SCRIPT FOR DEBIAN/UBUNTU
# ==============================================

# Check root access
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Detect OS
OS=$(lsb_release -is)
VER=$(lsb_release -rs)
echo "Detected OS: $OS $VER"

# Install dependencies
echo "Installing required packages..."
apt-get update
apt-get install -y stunnel4 openssl

# Create stunnel directory
mkdir -p /etc/stunnel
chmod 755 /etc/stunnel

# Generate SSL Certificate
echo "Generating SSL certificate..."
country="MY"
state="Sabah"
locality="Kota_Kinabalu"
organization="@XDTunnell"
organizationalunit="@XDTunnell"
commonname="XDTunnell"
email="admin@xdproject.com"

# Generate private key and certificate
openssl genrsa -out /etc/stunnel/key.pem 2048
openssl req -new -x509 -key /etc/stunnel/key.pem -out /etc/stunnel/cert.pem -days 1095 \
    -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"

# Combine key and cert
cat /etc/stunnel/key.pem /etc/stunnel/cert.pem > /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem

# Create stunnel configuration
echo "Creating stunnel configuration..."
cat > /etc/stunnel/stunnel.conf <<-END
cert = /etc/stunnel/stunnel.pem
key = /etc/stunnel/key.pem
client = no
pid = /var/run/stunnel4/stunnel4.pid
setuid = stunnel4
setgid = stunnel4

socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

sslVersion = all
options = NO_SSLv2
options = NO_SSLv3
ciphers = HIGH:!aNULL:!MD5:!RC4

; Logging
debug = 5
output = /var/log/stunnel4/stunnel.log

; OpenVPN Service
[openvpn]
accept = 442
connect = 127.0.0.1:1194
END

# Create log directory
mkdir -p /var/log/stunnel4
touch /var/log/stunnel4/stunnel.log
chown -R stunnel4:stunnel4 /var/log/stunnel4

# Enable stunnel service
echo "Configuring stunnel service..."
sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4

# Start service
systemctl restart stunnel4
systemctl enable stunnel4

# Check status
echo "Checking stunnel status..."
systemctl status stunnel4 --no-pager

# Firewall configuration
if command -v ufw &> /dev/null; then
    echo "Configuring UFW firewall..."
    ufw allow 222
    ufw allow 777
    ufw allow 442
    ufw allow 2096
    ufw reload
elif command -v iptables &> /dev/null; then
    echo "Configuring iptables firewall..."
    iptables -A INPUT -p tcp --dport 222 -j ACCEPT
    iptables -A INPUT -p tcp --dport 777 -j ACCEPT
    iptables -A INPUT -p tcp --dport 442 -j ACCEPT
    iptables -A INPUT -p tcp --dport 2096 -j ACCEPT
    iptables-save > /etc/iptables.up.rules
fi

# Installation complete
echo ""
echo "=============================================="
echo "Stunnel4 installation completed successfully!"
echo "Configuration: /etc/stunnel/stunnel.conf"
echo "SSL Certificate: /etc/stunnel/stunnel.pem"
echo "Private Key: /etc/stunnel/key.pem"
echo "Log File: /var/log/stunnel4/stunnel.log"
echo ""
echo "Ports configured:"
echo "- OpenVPN SSL: 442"
echo "=============================================="
echo ""