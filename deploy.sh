#!/bin/bash

# MinIO Deployment Script for Raspberry Pi
# This script sets up MinIO with self-signed TLS certificates

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Banner
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║                        MinIO Deployment Script                               ║"
echo "║                    Secure S3-Compatible Object Storage                       ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_requirements() {
    print_section "Checking System Requirements"
    
    # Check if running on Linux (Raspberry Pi)
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_warning "This script is designed for Linux (Raspberry Pi). Continuing anyway..."
    fi
    
    # Check for required commands
    local required_commands=("docker" "openssl" "curl")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        else
            print_success "$cmd is installed"
        fi
    done
    
    # Check for docker compose (v2) availability and set COMPOSE_CMD
    if docker compose version > /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
        print_success "docker compose is available"
    elif docker-compose version > /dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
        print_success "docker-compose is available"
    else
        missing_commands+=("docker compose")
    fi
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        print_error "Missing required commands: ${missing_commands[*]}"
        echo ""
        echo "Please install the missing commands:"
        echo "  sudo apt update"
        echo "  sudo apt install -y docker.io openssl curl"
        echo "  sudo systemctl enable docker"
        echo "  sudo systemctl start docker"
        echo "  sudo usermod -aG docker \$USER"
        echo ""
        echo "After installation, log out and log back in, then run this script again."
        exit 1
    fi
    
    # Check if user is in docker group
    if ! groups | grep -q docker; then
        print_warning "User is not in the docker group. You may need to run docker commands with sudo."
        echo "To fix this, run: sudo usermod -aG docker \$USER"
        echo "Then log out and log back in."
    fi
}

# Function to setup environment
setup_environment() {
    print_section "Setting Up Environment"
    
    # Check if .env file exists
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        if [ -f "$SCRIPT_DIR/env.template" ]; then
            print_warning ".env file not found. Creating from template..."
            cp "$SCRIPT_DIR/env.template" "$SCRIPT_DIR/.env"
            print_success "Created .env file from template"
            echo ""
            echo -e "${YELLOW}IMPORTANT: Please edit the .env file and update the following:${NC}"
            echo "  - MINIO_ROOT_PASSWORD: Change to a secure password"
            echo "  - LOCAL_MOUNT: Set to your desired data storage path"
            echo ""
            echo "Press Enter to continue after editing .env file..."
            read -r
        else
            print_error "Neither .env nor env.template found!"
            exit 1
        fi
    else
        print_success ".env file found"
    fi
    
    # Source environment variables
    source "$SCRIPT_DIR/.env"
    
    # Validate required environment variables
    if [ -z "$MINIO_ROOT_USER" ] || [ -z "$MINIO_ROOT_PASSWORD" ] || [ -z "$LOCAL_MOUNT" ]; then
        print_error "Missing required environment variables in .env file"
        echo "Required variables: MINIO_ROOT_USER, MINIO_ROOT_PASSWORD, LOCAL_MOUNT"
        exit 1
    fi
    
    # Check if credentials are still placeholders
    if [ "$MINIO_ROOT_USER" = "CHANGE_THIS_USERNAME" ] || [ "$MINIO_ROOT_PASSWORD" = "CHANGE_THIS_PASSWORD_BEFORE_DEPLOYMENT" ]; then
        print_error "Placeholder credentials detected in .env file!"
        echo ""
        echo "Please update the following in your .env file:"
        echo "  - MINIO_ROOT_USER: Set to your desired admin username"
        echo "  - MINIO_ROOT_PASSWORD: Set to a secure password"
        echo ""
        echo "For security reasons, deployment cannot proceed with placeholder values."
        exit 1
    fi
    
    print_success "Environment configuration validated"
}

# Function to create data directory
create_data_directory() {
    print_section "Creating Data Directory"
    
    if [ ! -d "$LOCAL_MOUNT" ]; then
        echo "Creating data directory: $LOCAL_MOUNT"
        mkdir -p "$LOCAL_MOUNT"
        print_success "Data directory created"
    else
        print_success "Data directory already exists"
    fi
    
    # Set proper permissions (750 for better security)
    chmod 750 "$LOCAL_MOUNT"
    print_success "Data directory permissions set (750)"
}

# Function to generate certificates
generate_certificates() {
    print_section "Generating TLS Certificates"
    
    if [ -f "$SCRIPT_DIR/certs/private.key" ] && [ -f "$SCRIPT_DIR/certs/public.crt" ]; then
        echo "Certificates already exist. Do you want to regenerate them? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_success "Using existing certificates"
            return
        fi
    fi
    
    if [ -f "$SCRIPT_DIR/scripts/generate-certs.sh" ]; then
        echo "Running certificate generation script..."
        "$SCRIPT_DIR/scripts/generate-certs.sh"
        print_success "Certificates generated"
    else
        print_error "Certificate generation script not found!"
        exit 1
    fi
}

# Function to deploy MinIO
deploy_minio() {
    print_section "Deploying MinIO"
    
    # Stop existing containers if running
    if $COMPOSE_CMD -f "$SCRIPT_DIR/docker-compose.yml" ps | grep -q "minio"; then
        echo "Stopping existing MinIO containers..."
        $COMPOSE_CMD -f "$SCRIPT_DIR/docker-compose.yml" down
    fi
    
    # Start MinIO with docker compose
    echo "Starting MinIO containers..."
    $COMPOSE_CMD -f "$SCRIPT_DIR/docker-compose.yml" up -d
    
    print_success "MinIO containers started"
}

# Function to wait for MinIO to be ready
wait_for_minio() {
    print_section "Waiting for MinIO to be Ready"
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -k -f -s "https://localhost:9000/minio/health/live" > /dev/null 2>&1; then
            print_success "MinIO is ready!"
            return 0
        fi
        
        echo "Attempt $attempt/$max_attempts: Waiting for MinIO to start..."
        sleep 5
        ((attempt++))
    done
    
    print_error "MinIO failed to start within expected time"
    echo "Check the logs with: $COMPOSE_CMD -f $SCRIPT_DIR/docker-compose.yml logs"
    return 1
}

# Function to display deployment information
display_info() {
    print_section "Deployment Information"
    
    local local_ip
    local_ip=$(hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}MinIO has been successfully deployed with TLS!${NC}"
    echo ""
    echo "Access Information:"
    echo "  • Web Console: https://$local_ip:9001"
    echo "  • S3 API Endpoint: https://$local_ip:9000"
    echo "  • Username: $MINIO_ROOT_USER"
    echo "  • Password: $MINIO_ROOT_PASSWORD"
    echo ""
    echo "Local Access:"
    echo "  • Web Console: https://localhost:9001"
    echo "  • S3 API Endpoint: https://localhost:9000"
    echo ""
    echo "Data Storage:"
    echo "  • Host Path: $LOCAL_MOUNT"
    echo "  • Container Path: /data"
    echo ""
    echo "Certificate Information:"
    echo "  • Private Key: $SCRIPT_DIR/certs/private.key"
    echo "  • Public Certificate: $SCRIPT_DIR/certs/public.crt"
    echo ""
    echo -e "${YELLOW}Note: You may need to accept the security warning in your browser${NC}"
    echo -e "${YELLOW}since we're using self-signed certificates.${NC}"
    echo ""
    echo "Management Commands:"
    echo "  • View logs: $COMPOSE_CMD -f $SCRIPT_DIR/docker-compose.yml logs"
    echo "  • Stop service: $COMPOSE_CMD -f $SCRIPT_DIR/docker-compose.yml down"
    echo "  • Restart service: $COMPOSE_CMD -f $SCRIPT_DIR/docker-compose.yml restart"
    echo "  • Update service: $COMPOSE_CMD -f $SCRIPT_DIR/docker-compose.yml pull && $COMPOSE_CMD -f $SCRIPT_DIR/docker-compose.yml up -d"
}

# Function to show help
show_help() {
    echo "MinIO Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --skip-checks  Skip system requirement checks"
    echo "  --certs-only   Only generate certificates"
    echo "  --deploy-only  Only deploy (skip cert generation)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Full deployment"
    echo "  $0 --certs-only       # Generate certificates only"
    echo "  $0 --deploy-only      # Deploy with existing certificates"
}

# Main deployment function
main() {
    local skip_checks=false
    local certs_only=false
    local deploy_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --skip-checks)
                skip_checks=true
                shift
                ;;
            --certs-only)
                certs_only=true
                shift
                ;;
            --deploy-only)
                deploy_only=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Execute deployment steps
    if [ "$skip_checks" = false ]; then
        check_requirements
    fi
    
    if [ "$certs_only" = true ]; then
        generate_certificates
        print_success "Certificate generation completed"
        exit 0
    fi
    
    setup_environment
    create_data_directory
    
    if [ "$deploy_only" = false ]; then
        generate_certificates
    fi
    
    deploy_minio
    
    if wait_for_minio; then
        display_info
        print_success "Deployment completed successfully!"
    else
        print_error "Deployment completed but MinIO may not be fully ready"
        echo "Please check the logs and try accessing the web console"
    fi
}

# Run main function with all arguments
main "$@" 