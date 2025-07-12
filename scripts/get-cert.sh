#!/bin/bash

# MinIO Certificate Extraction Script
# This script extracts the TLS certificate from your MinIO server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
MINIO_HOST=""
MINIO_PORT="9000"
OUTPUT_FILE="minio-cert.pem"
INSTALL_TO_KEYCHAIN=false

# Function to display usage
show_usage() {
    echo -e "${BLUE}MinIO Certificate Extraction Script${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --host HOST        MinIO server hostname or IP address (required)"
    echo "  -p, --port PORT        MinIO server port (default: 9000)"
    echo "  -o, --output FILE      Output certificate file (default: minio-cert.pem)"
    echo "  -k, --keychain         Install certificate to macOS keychain (requires sudo)"
    echo "  --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --host 192.168.1.100"
    echo "  $0 --host minio.local --port 9000 --keychain"
    echo "  $0 -h 192.168.1.100 -o ~/Downloads/minio.crt"
    echo ""
}

# Function to extract certificate
extract_certificate() {
    local host=$1
    local port=$2
    local output=$3
    
    echo -e "${BLUE}Extracting certificate from ${host}:${port}...${NC}"
    
    # Note: We'll let openssl s_client handle the connection test
    # as it provides better error messages for TLS-specific issues
    
    # Extract certificate with better error handling
    echo -e "${BLUE}Attempting to connect and extract certificate...${NC}"
    
    # First, try to connect and get verbose output for debugging
    if ! openssl s_client -connect "${host}:${port}" -servername "${host}" < /dev/null 2>&1 | head -20 | grep -q "CONNECTED"; then
        echo -e "${RED}Error: Cannot establish TLS connection to ${host}:${port}${NC}"
        echo ""
        echo "Troubleshooting steps:"
        echo "1. Verify MinIO is running: curl -k https://${host}:${port}/minio/health/live"
        echo "2. Check if port ${port} is correct (MinIO API port, not console port)"
        echo "3. Verify network connectivity: ping ${host}"
        echo "4. Check firewall settings"
        echo ""
        return 1
    fi
    
    # Extract the certificate
    if openssl s_client -connect "${host}:${port}" -servername "${host}" < /dev/null 2>/dev/null | openssl x509 -outform PEM > "${output}" 2>/dev/null; then
        # Verify the certificate was actually extracted
        if [ -s "${output}" ] && openssl x509 -in "${output}" -noout -text >/dev/null 2>&1; then
            echo -e "${GREEN}Certificate extracted successfully to: ${output}${NC}"
            
            # Display certificate info
            echo ""
            echo -e "${BLUE}Certificate Information:${NC}"
            openssl x509 -in "${output}" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:|DNS:|IP Address:)" | sed 's/^[[:space:]]*/  /'
            
            return 0
        else
            echo -e "${RED}Error: Certificate file is empty or invalid${NC}"
            rm -f "${output}"
            return 1
        fi
    else
        echo -e "${RED}Error: Failed to extract certificate${NC}"
        echo "This could be due to:"
        echo "1. TLS handshake failure"
        echo "2. Invalid certificate on server"
        echo "3. Network connectivity issues"
        return 1
    fi
}

# Function to install certificate to macOS keychain
install_to_keychain() {
    local cert_file=$1
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${YELLOW}Warning: Keychain installation is only supported on macOS${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}Installing certificate to macOS system keychain...${NC}"
    echo "This requires administrator privileges."
    
    if sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "${cert_file}"; then
        echo -e "${GREEN}Certificate installed successfully to system keychain${NC}"
        echo ""
        echo -e "${BLUE}Verification:${NC}"
        # Extract subject from certificate for verification
        local subject=$(openssl x509 -in "${cert_file}" -noout -subject | sed 's/subject=//')
        echo "Certificate: ${subject}"
        return 0
    else
        echo -e "${RED}Error: Failed to install certificate to keychain${NC}"
        return 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            MINIO_HOST="$2"
            shift 2
            ;;
        -p|--port)
            MINIO_PORT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -k|--keychain)
            INSTALL_TO_KEYCHAIN=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Check if host is provided
if [[ -z "$MINIO_HOST" ]]; then
    echo -e "${RED}Error: MinIO host is required${NC}"
    echo ""
    show_usage
    exit 1
fi

# Check if openssl is available
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}Error: openssl is not installed${NC}"
    echo "Please install openssl first:"
    echo "  macOS: brew install openssl"
    echo "  Ubuntu/Debian: sudo apt install openssl"
    exit 1
fi

# Main execution
echo -e "${BLUE}MinIO Certificate Extraction${NC}"
echo "Host: ${MINIO_HOST}"
echo "Port: ${MINIO_PORT}"
echo "Output: ${OUTPUT_FILE}"
echo ""

# Extract certificate
if extract_certificate "$MINIO_HOST" "$MINIO_PORT" "$OUTPUT_FILE"; then
    # Install to keychain if requested
    if [[ "$INSTALL_TO_KEYCHAIN" == true ]]; then
        install_to_keychain "$OUTPUT_FILE"
    fi
    
    echo ""
    echo -e "${GREEN}Certificate extraction completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    
    if [[ "$INSTALL_TO_KEYCHAIN" == true ]] && [[ "$OSTYPE" == "darwin"* ]]; then
        echo "1. Certificate has been installed to your system keychain"
        echo "2. You can now use MinIO clients without --insecure flags"
        echo "3. Restart your applications to use the new certificate"
    else
        echo "1. Certificate saved to: ${OUTPUT_FILE}"
        echo "2. Use this certificate file with your MinIO clients"
        echo "3. Or install to keychain manually:"
        echo "   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ${OUTPUT_FILE}"
    fi
    
    echo ""
    echo -e "${BLUE}Example usage with MinIO client:${NC}"
    echo "mc alias set myminio https://${MINIO_HOST}:${MINIO_PORT} your-username your-password"
    
else
    echo -e "${RED}Certificate extraction failed${NC}"
    exit 1
fi 