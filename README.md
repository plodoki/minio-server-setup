# MinIO Server Setup with TLS

A complete MinIO deployment setup for Raspberry Pi with self-signed TLS certificates and one-command deployment.

## 🚀 Features

- **Secure by Default**: TLS encryption with self-signed certificates
- **One-Command Deployment**: Single script handles everything
- **Raspberry Pi Optimized**: Designed for ARM-based systems
- **Docker-Based**: Easy to manage and update
- **Production Ready**: Proper health checks and monitoring

## 📋 Prerequisites

### System Requirements

- Linux system (Raspberry Pi recommended)
- Docker and Docker Compose
- OpenSSL (for certificate generation)
- curl (for health checks)

### Quick Prerequisites Installation (Raspberry Pi)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y docker.io docker-compose openssl curl

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add user to docker group (requires logout/login)
sudo usermod -aG docker $USER

# Logout and login again, then verify
docker --version
docker-compose --version
```

## 🛠️ Installation & Deployment

### 1. Clone or Download

```bash
# Clone the repository
git clone <repository-url>
cd minio-server-setup

# Or download and extract the files
```

### 2. Configure Environment

```bash
# Copy the environment template
cp env.template .env

# Edit the configuration
nano .env
```

**Important**: Update these values in `.env`:

- `MINIO_ROOT_PASSWORD`: Change to a secure password
- `LOCAL_MOUNT`: Set to your desired data storage path

### 3. Deploy with One Command

```bash
# Full deployment (recommended)
./deploy.sh

# Or with options
./deploy.sh --help
```

That's it! The script will:

1. Check system requirements
2. Generate TLS certificates
3. Create data directories
4. Deploy MinIO with Docker Compose
5. Verify the deployment

## 🔧 Configuration

### Environment Variables

| Variable              | Description       | Default               | Required |
| --------------------- | ----------------- | --------------------- | -------- |
| `MINIO_ROOT_USER`     | Admin username    | `admin`               | Yes      |
| `MINIO_ROOT_PASSWORD` | Admin password    | -                     | Yes      |
| `LOCAL_MOUNT`         | Data storage path | `/home/pi/minio-data` | Yes      |

### Certificate Configuration

The certificate generation script automatically detects:

- Local IP address
- Hostname
- Allows additional domains/IPs

## 🌐 Access Information

After successful deployment:

### Web Console

- **URL**: `https://<raspberry-pi-ip>:9001`
- **Local**: `https://localhost:9001`

### S3 API Endpoint

- **URL**: `https://<raspberry-pi-ip>:9000`
- **Local**: `https://localhost:9000`

### Default Credentials

- **Username**: From `MINIO_ROOT_USER` in `.env`
- **Password**: From `MINIO_ROOT_PASSWORD` in `.env`

## 🔒 Security Notes

### Self-Signed Certificates

This setup uses self-signed certificates for TLS encryption. You may see security warnings in your browser - this is normal and expected.

**To accept the certificate:**

1. Navigate to the MinIO web console
2. Click "Advanced" or "Show Details"
3. Click "Proceed to [hostname]" or "Accept Risk"

### Certificate Validity

- Certificates are valid for 365 days
- Include localhost, local IP, and hostname
- Support additional domains/IPs during generation

## 🖥️ Client Configuration for Self-Signed Certificates

Since this setup uses self-signed certificates, you'll need to configure your clients to trust the certificate or disable certificate verification.

### macOS CLI Clients

#### MinIO Client (mc)

```bash
# Install MinIO client
brew install minio/stable/mc

# Add alias with --insecure flag for self-signed certs
mc alias set myminio https://your-pi-ip:9000 your-username your-password --insecure

# Or add to system keychain (more secure)
# First, download the certificate
curl -k https://your-pi-ip:9000 > /tmp/minio-cert.pem

# Add to system keychain
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/minio-cert.pem

# Then use without --insecure flag
mc alias set myminio https://your-pi-ip:9000 your-username your-password
```

#### AWS CLI

```bash
# Install AWS CLI
brew install awscli

# Configure with --no-verify-ssl flag
aws configure set aws_access_key_id your-username
aws configure set aws_secret_access_key your-password
aws configure set region us-east-1
aws configure set s3.signature_version s3v4

# Use with --no-verify-ssl flag
aws --endpoint-url=https://your-pi-ip:9000 --no-verify-ssl s3 ls

# Or set environment variable
export AWS_CA_BUNDLE=""
aws --endpoint-url=https://your-pi-ip:9000 s3 ls
```

#### curl

```bash
# Use -k flag to ignore certificate errors
curl -k https://your-pi-ip:9000/minio/health/live

# Or specify certificate file
curl --cacert /path/to/certs/public.crt https://your-pi-ip:9000/minio/health/live
```

### Python Clients

#### boto3 (AWS SDK)

```python
import boto3
from botocore.config import Config
import urllib3

# Option 1: Disable SSL warnings and verification
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

s3_client = boto3.client(
    's3',
    endpoint_url='https://your-pi-ip:9000',
    aws_access_key_id='your-username',
    aws_secret_access_key='your-password',
    config=Config(signature_version='s3v4'),
    verify=False  # Disable SSL verification
)

# Option 2: Use custom certificate
s3_client = boto3.client(
    's3',
    endpoint_url='https://your-pi-ip:9000',
    aws_access_key_id='your-username',
    aws_secret_access_key='your-password',
    config=Config(signature_version='s3v4'),
    verify='/path/to/certs/public.crt'  # Path to certificate
)

# Example usage
try:
    response = s3_client.list_buckets()
    print("Buckets:", response['Buckets'])
except Exception as e:
    print(f"Error: {e}")
```

#### minio-py (MinIO Python SDK)

```python
from minio import Minio
import urllib3

# Option 1: Disable SSL warnings and verification
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

client = Minio(
    'your-pi-ip:9000',
    access_key='your-username',
    secret_key='your-password',
    secure=True,
    cert_check=False  # Disable certificate verification
)

# Option 2: Use custom certificate
import ssl
import certifi

# Create SSL context with custom certificate
context = ssl.create_default_context(cafile='/path/to/certs/public.crt')

client = Minio(
    'your-pi-ip:9000',
    access_key='your-username',
    secret_key='your-password',
    secure=True,
    http_client=urllib3.PoolManager(
        cert_reqs='CERT_REQUIRED',
        ca_certs='/path/to/certs/public.crt'
    )
)

# Example usage
try:
    buckets = client.list_buckets()
    for bucket in buckets:
        print(f"Bucket: {bucket.name}")
except Exception as e:
    print(f"Error: {e}")
```

#### requests library

```python
import requests
import urllib3

# Option 1: Disable SSL warnings and verification
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

response = requests.get(
    'https://your-pi-ip:9000/minio/health/live',
    verify=False  # Disable SSL verification
)

# Option 2: Use custom certificate
response = requests.get(
    'https://your-pi-ip:9000/minio/health/live',
    verify='/path/to/certs/public.crt'  # Path to certificate
)

print(f"Status: {response.status_code}")
```

### Adding Certificate to macOS System Keychain

For a more secure approach, add the certificate to your system's trusted certificates:

```bash
# Copy certificate from your MinIO server
scp pi@your-pi-ip:/path/to/minio-server-setup/certs/public.crt ~/Downloads/minio-cert.crt

# Add to system keychain
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/Downloads/minio-cert.crt

# Verify it was added
security find-certificate -a -c "your-hostname" /Library/Keychains/System.keychain
```

### Environment Variables for Development

Create a `.env` file for your development environment:

```bash
# Development environment variables
export MINIO_ENDPOINT=https://your-pi-ip:9000
export MINIO_ACCESS_KEY=your-username
export MINIO_SECRET_KEY=your-password
export MINIO_CERT_PATH=/path/to/certs/public.crt
export PYTHONHTTPSVERIFY=0  # Disable SSL verification for Python (development only)
```

### Docker Clients

When running clients in Docker containers:

```bash
# Mount certificate into container
docker run -it --rm \
  -v /path/to/certs:/certs:ro \
  -e AWS_CA_BUNDLE=/certs/public.crt \
  amazon/aws-cli \
  --endpoint-url=https://your-pi-ip:9000 s3 ls
```

### Production Recommendations

For production environments, consider:

1. **Use a proper CA-signed certificate** instead of self-signed
2. **Set up a reverse proxy** (nginx/traefik) with Let's Encrypt
3. **Use certificate pinning** for additional security
4. **Implement certificate rotation** procedures

**Security Warning**: Disabling SSL verification should only be used in development environments. For production, always use proper certificate validation.

## 🛠️ Management Commands

### View Logs

```bash
docker-compose logs
docker-compose logs -f  # Follow logs
```

### Stop Service

```bash
docker-compose down
```

### Restart Service

```bash
docker-compose restart
```

### Update MinIO

```bash
docker-compose pull
docker-compose up -d
```

### Regenerate Certificates

```bash
./deploy.sh --certs-only
```

### Get Certificate for Clients

```bash
./scripts/get-cert.sh
```

## 📁 File Structure

```
minio-server-setup/
├── deploy.sh              # Main deployment script
├── docker-compose.yml     # Docker Compose configuration
├── env.template           # Environment template
├── .env                   # Your configuration (created from template)
├── scripts/
│   ├── generate-certs.sh  # Certificate generation script
│   ├── verify-setup.sh    # Deployment verification script
│   └── get-cert.sh        # Certificate helper for clients
├── certs/                 # TLS certificates (auto-generated)
│   ├── private.key
│   └── public.crt
└── README.md              # This file
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Permission Denied (Docker)

```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Logout and login again
```

#### 2. Port Already in Use

```bash
# Check what's using the ports
sudo netstat -tulpn | grep :9000
sudo netstat -tulpn | grep :9001

# Stop conflicting services or change ports in docker-compose.yml
```

#### 3. Certificate Issues

```bash
# Regenerate certificates
./deploy.sh --certs-only

# Check certificate details
openssl x509 -in certs/public.crt -text -noout
```

#### 4. MinIO Won't Start

```bash
# Check logs
docker-compose logs minio

# Check data directory permissions
ls -la /path/to/your/data/directory

# Verify environment variables
cat .env
```

### Health Check

```bash
# Check if MinIO is responding
curl -k -f https://localhost:9000/minio/health/live

# Check container status
docker-compose ps
```

## 🔄 Backup and Restore

### Backup Data

```bash
# Backup the data directory
sudo tar -czf minio-backup-$(date +%Y%m%d).tar.gz /path/to/your/data/directory

# Backup configuration
cp .env .env.backup
cp -r certs certs.backup
```

### Restore Data

```bash
# Stop MinIO
docker-compose down

# Restore data
sudo tar -xzf minio-backup-YYYYMMDD.tar.gz -C /

# Start MinIO
docker-compose up -d
```

## 🚀 Advanced Usage

### Custom Domains

To use custom domains, edit the certificate generation script or regenerate certificates:

```bash
# During certificate generation, specify additional domains
# Example: minio.local,storage.home.lan
```

### External Storage

For external storage (USB drive, NFS, etc.):

```bash
# Mount external storage
sudo mkdir -p /mnt/external-storage
sudo mount /dev/sda1 /mnt/external-storage

# Update .env
LOCAL_MOUNT=/mnt/external-storage/minio-data

# Redeploy
./deploy.sh
```

### Monitoring

Set up monitoring with Prometheus and Grafana:

```bash
# MinIO provides metrics endpoint
curl -k https://localhost:9000/minio/v2/metrics/cluster
```

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section
2. Review the logs: `docker-compose logs`
3. Verify your configuration: `cat .env`
4. Check system requirements
5. Open an issue with detailed information

---

**Happy storing! 🗄️**
