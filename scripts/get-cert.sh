#!/bin/bash

# MinIO Certificate Helper Script
# This script helps you retrieve the certificate for client configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print info messages
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

echo -e "${GREEN}MinIO Certificate Helper${NC}"
echo "======================="

# Check if certificate exists
if [ ! -f "$PROJECT_DIR/certs/public.crt" ]; then
    print_error "Certificate not found at $PROJECT_DIR/certs/public.crt"
    echo "Please run ./deploy.sh first to generate certificates"
    exit 1
fi

# Get local IP
LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")

echo ""
echo "Available options:"
echo "  1. Display certificate content"
echo "  2. Copy certificate to Downloads folder"
echo "  3. Show certificate details"
echo "  4. Generate client configuration examples"
echo "  5. Add certificate to macOS keychain"
echo ""

read -p "Choose an option (1-5): " choice

case $choice in
    1)
        echo ""
        print_info "Certificate content:"
        echo "===================="
        cat "$PROJECT_DIR/certs/public.crt"
        ;;
    2)
        if [ -d "$HOME/Downloads" ]; then
            cp "$PROJECT_DIR/certs/public.crt" "$HOME/Downloads/minio-cert.crt"
            print_success "Certificate copied to $HOME/Downloads/minio-cert.crt"
        else
            print_error "Downloads folder not found"
        fi
        ;;
    3)
        echo ""
        print_info "Certificate details:"
        echo "==================="
        openssl x509 -in "$PROJECT_DIR/certs/public.crt" -text -noout | grep -A 10 -E "(Subject:|Issuer:|Validity|DNS:|IP Address:)"
        ;;
    4)
        echo ""
        print_info "Client configuration examples:"
        echo "============================="
        echo ""
        echo "MinIO Client (mc):"
        echo "  mc alias set myminio https://$LOCAL_IP:9000 your-username your-password --insecure"
        echo ""
        echo "AWS CLI:"
        echo "  aws --endpoint-url=https://$LOCAL_IP:9000 --no-verify-ssl s3 ls"
        echo ""
        echo "curl:"
        echo "  curl -k https://$LOCAL_IP:9000/minio/health/live"
        echo ""
        echo "Python boto3:"
        echo "  s3_client = boto3.client('s3', endpoint_url='https://$LOCAL_IP:9000', verify=False)"
        echo ""
        echo "Python minio:"
        echo "  client = Minio('$LOCAL_IP:9000', secure=True, cert_check=False)"
        ;;
    5)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo ""
            print_info "Adding certificate to macOS keychain..."
            
            # Copy to temp location first
            cp "$PROJECT_DIR/certs/public.crt" "/tmp/minio-cert.crt"
            
            # Add to keychain
            if sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "/tmp/minio-cert.crt"; then
                print_success "Certificate added to macOS keychain"
                echo "You can now use MinIO clients without the --insecure flag"
                
                # Clean up temp file
                rm "/tmp/minio-cert.crt"
            else
                print_error "Failed to add certificate to keychain"
            fi
        else
            print_error "This option is only available on macOS"
        fi
        ;;
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

echo ""
print_info "Certificate path: $PROJECT_DIR/certs/public.crt"
print_info "MinIO endpoint: https://$LOCAL_IP:9000" 