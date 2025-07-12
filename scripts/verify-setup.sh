#!/bin/bash

# MinIO Setup Verification Script
# This script verifies that MinIO is properly deployed and accessible

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

# Banner
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║                        MinIO Setup Verification                              ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running from correct directory
if [ ! -f "$PROJECT_DIR/docker-compose.yml" ]; then
    print_error "docker-compose.yml not found. Please run this script from the project directory."
    exit 1
fi

# Change to project directory
cd "$PROJECT_DIR"

print_section "Checking Configuration Files"

# Check .env file
if [ -f ".env" ]; then
    print_success ".env file exists"
    
    # Source environment variables
    source .env
    
    # Check required variables
    if [ -n "$MINIO_ROOT_USER" ] && [ -n "$MINIO_ROOT_PASSWORD" ] && [ -n "$LOCAL_MOUNT" ]; then
        print_success "Required environment variables are set"
    else
        print_error "Missing required environment variables"
        exit 1
    fi
else
    print_error ".env file not found"
    exit 1
fi

# Check certificates
print_section "Checking TLS Certificates"

if [ -f "certs/private.key" ] && [ -f "certs/public.crt" ]; then
    print_success "TLS certificates exist"
    
    # Check certificate validity
    if openssl x509 -in certs/public.crt -noout -checkend 86400; then
        print_success "Certificate is valid for at least 24 hours"
    else
        print_warning "Certificate expires within 24 hours"
    fi
    
    # Show certificate details
    echo "Certificate details:"
    openssl x509 -in certs/public.crt -noout -subject -dates
else
    print_error "TLS certificates not found"
    exit 1
fi

# Check data directory
print_section "Checking Data Directory"

if [ -d "$LOCAL_MOUNT" ]; then
    print_success "Data directory exists: $LOCAL_MOUNT"
    
    # Check permissions
    if [ -w "$LOCAL_MOUNT" ]; then
        print_success "Data directory is writable"
    else
        print_warning "Data directory may not be writable"
    fi
else
    print_error "Data directory not found: $LOCAL_MOUNT"
    exit 1
fi

# Check Docker containers
print_section "Checking Docker Containers"

if docker compose ps | grep -q "minio"; then
    print_success "MinIO container is running"
    
    # Get container ID for health check
    container_id=$(docker compose ps -q minio)
    
    if [ -n "$container_id" ]; then
        # Check actual health status
        health_status=$(docker inspect --format '{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "unknown")
        
        if [ "$health_status" = "healthy" ]; then
            print_success "Container is healthy"
        elif [ "$health_status" = "starting" ]; then
            print_warning "Container is still starting up"
        elif [ "$health_status" = "unhealthy" ]; then
            print_error "Container is unhealthy"
            echo "Container logs:"
            docker compose logs --tail 20 minio
            exit 1
        else
            # Fallback to basic status check if no health check is configured
            if docker compose ps | grep -q "Up"; then
                print_success "Container is running (no health check configured)"
            else
                print_warning "Container may not be healthy"
            fi
        fi
    else
        print_error "Could not get container ID"
        exit 1
    fi
else
    print_error "MinIO container is not running"
    echo "Try running: docker compose up -d"
    exit 1
fi

# Check MinIO health endpoint
print_section "Checking MinIO Health"

if curl -k -f -s "https://localhost:9000/minio/health/live" > /dev/null 2>&1; then
    print_success "MinIO health endpoint is responding"
else
    print_error "MinIO health endpoint is not responding"
    echo "MinIO may still be starting up. Wait a few moments and try again."
    exit 1
fi

# Check web console accessibility
print_section "Checking Web Console"

if curl -k -f -s "https://localhost:9001" > /dev/null 2>&1; then
    print_success "Web console is accessible"
else
    print_warning "Web console may not be fully ready"
fi

# Display access information
print_section "Access Information"

local_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "N/A")

echo -e "${GREEN}MinIO is successfully deployed and accessible!${NC}"
echo ""
echo "Access URLs:"
echo "  • Web Console (Local): https://localhost:9001"
echo "  • Web Console (Network): https://$local_ip:9001"
echo "  • S3 API (Local): https://localhost:9000"
echo "  • S3 API (Network): https://$local_ip:9000"
echo ""
echo "Credentials:"
echo "  • Username: $MINIO_ROOT_USER"
echo "  • Password: [Hidden for security]"
echo ""
echo -e "${YELLOW}Note: You may need to accept the security warning in your browser${NC}"
echo -e "${YELLOW}due to the self-signed certificate.${NC}"

print_success "Verification completed successfully!" 