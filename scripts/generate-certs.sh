#!/bin/bash

# Script to generate self-signed certificates for MinIO
# This script creates certificates that work with MinIO's TLS requirements

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="$PROJECT_DIR/certs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}MinIO Self-Signed Certificate Generator${NC}"
echo "========================================"

# Create certs directory if it doesn't exist
mkdir -p "$CERTS_DIR"

# Get the local IP address (for Raspberry Pi deployment)
LOCAL_IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)

echo -e "${YELLOW}Detected local IP: $LOCAL_IP${NC}"
echo -e "${YELLOW}Detected hostname: $HOSTNAME${NC}"

# Prompt for additional domains/IPs
echo ""
echo "Enter additional domains or IP addresses (comma-separated, or press Enter to skip):"
echo "Example: minio.local,192.168.1.100,my-minio.com"
read -r ADDITIONAL_DOMAINS

# Build Subject Alternative Names (SAN)
SAN="IP:127.0.0.1,IP:$LOCAL_IP,DNS:localhost,DNS:$HOSTNAME"

if [ -n "$ADDITIONAL_DOMAINS" ]; then
    IFS=',' read -ra DOMAINS <<< "$ADDITIONAL_DOMAINS"
    for domain in "${DOMAINS[@]}"; do
        domain=$(echo "$domain" | xargs) # trim whitespace
        if [[ $domain =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            SAN="$SAN,IP:$domain"
        else
            SAN="$SAN,DNS:$domain"
        fi
    done
fi

echo -e "${YELLOW}Subject Alternative Names: $SAN${NC}"

# Generate private key
echo ""
echo "Generating private key..."
openssl genrsa -out "$CERTS_DIR/private.key" 2048

# Create certificate signing request configuration
cat > "$CERTS_DIR/csr.conf" << EOF
[req]
default_bits = 2048
prompt = no
distinguished_name = dn
req_extensions = v3_req

[dn]
C=US
ST=State
L=City
O=Organization
OU=OrganizationalUnit
CN=$HOSTNAME

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = $SAN
EOF

# Generate certificate signing request
echo "Generating certificate signing request..."
openssl req -new -key "$CERTS_DIR/private.key" -out "$CERTS_DIR/cert.csr" -config "$CERTS_DIR/csr.conf"

# Generate self-signed certificate
echo "Generating self-signed certificate..."
openssl x509 -req -in "$CERTS_DIR/cert.csr" -signkey "$CERTS_DIR/private.key" -out "$CERTS_DIR/public.crt" -days 365 -extensions v3_req -extfile "$CERTS_DIR/csr.conf"

# Clean up temporary files
rm "$CERTS_DIR/cert.csr" "$CERTS_DIR/csr.conf"

# Set proper permissions
chmod 600 "$CERTS_DIR/private.key"
chmod 644 "$CERTS_DIR/public.crt"

echo ""
echo -e "${GREEN}✓ Certificates generated successfully!${NC}"
echo ""
echo "Generated files:"
echo "  - Private key: $CERTS_DIR/private.key"
echo "  - Public certificate: $CERTS_DIR/public.crt"
echo ""
echo -e "${YELLOW}Note: These certificates are valid for 365 days.${NC}"
echo -e "${YELLOW}You may need to accept the security warning in your browser when first accessing MinIO.${NC}"
echo ""
echo "Certificate details:"
openssl x509 -in "$CERTS_DIR/public.crt" -text -noout | grep -A 1 "Subject Alternative Name" 