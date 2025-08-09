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
sudo apt install -y docker.io openssl curl

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add user to docker group (requires logout/login)
sudo usermod -aG docker $USER

# Logout and login again, then verify
docker --version
docker compose version
```

### Ubuntu 24.04 (x86_64) – Install Docker from the official repository

Using Docker's official repository ensures you get the latest Docker Engine and the Compose v2 plugin.

```bash
# Prep
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install engine + compose plugin
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# (Optional) Create docker group if missing and add your user
getent group docker || sudo groupadd docker
sudo usermod -aG docker $USER

# Apply group change (either log out/in or use newgrp)
newgrp docker

# Verify
docker --version
docker compose version
ls -l /var/run/docker.sock   # expect: ... root docker ...
```

Note: If you prefer to keep using sudo for Docker commands, you can skip adding your user to the `docker` group, but be aware that running `./deploy.sh` with sudo will create root-owned files (e.g., `.env`, `certs/`, data directory).

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

### Docker Group and Privileges

- Members of the `docker` group can control the Docker daemon, which is effectively root-equivalent. On single-user/admin-only hosts this is standard practice. On multi-user systems, consider using sudo or rootless Docker instead of granting group membership to all users.

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
# First, extract the certificate from the TLS connection
openssl s_client -connect your-pi-ip:9000 -servername your-pi-hostname < /dev/null 2>/dev/null | openssl x509 -outform PEM > /tmp/minio-cert.pem

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

#### Method 1: Extract certificate from TLS connection (recommended)

```bash
# Extract the certificate from the TLS connection
openssl s_client -connect your-pi-ip:9000 -servername your-pi-hostname < /dev/null 2>/dev/null | openssl x509 -outform PEM > ~/Downloads/minio-cert.crt

# Add to system keychain
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/Downloads/minio-cert.crt

# Verify it was added
security find-certificate -a -c "your-hostname" /Library/Keychains/System.keychain
```

#### Method 2: Copy certificate from MinIO server

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
docker compose logs
docker compose logs -f  # Follow logs
```

### Stop Service

```bash
docker compose down
```

### Restart Service

```bash
docker compose restart
```

### Update MinIO

```bash
docker compose pull
docker compose up -d
```

### Regenerate Certificates

```bash
./deploy.sh --certs-only
```

### Get Certificate for Clients

```bash
# Extract certificate from your MinIO server
./scripts/get-cert.sh --host 192.168.1.100

# Extract and install to macOS keychain
./scripts/get-cert.sh --host 192.168.1.100 --keychain

# See all options
./scripts/get-cert.sh --help
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

#### 1. Permission Denied (Docker) or `group 'docker' does not exist`

If you see warnings like "User is not in the docker group" or errors such as `usermod: group 'docker' does not exist`:

```bash
# Check Docker install and group
docker --version
getent group docker || echo "no docker group"

# If the group is missing, create it and add your user
sudo groupadd docker   # safe if it already exists
sudo usermod -aG docker $USER

# Restart Docker so the socket picks up the group
sudo systemctl restart docker

# Apply group change without full logout (optional)
newgrp docker

# Verify socket group is docker (not root:root)
ls -l /var/run/docker.sock

# Sanity check
docker run --rm hello-world
```

Notes:

- If you use `sudo ./deploy.sh`, generated files (e.g., `.env`, `certs/`, data dir) may become root-owned.
- Compose v2 is available as `docker compose` when the `docker-compose-plugin` package is installed (no separate `docker-compose` binary needed).

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
docker compose logs minio

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
docker compose ps
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
docker compose down

# Restore data
sudo tar -xzf minio-backup-YYYYMMDD.tar.gz -C /

# Start MinIO
docker compose up -d
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

## Rootless Docker (Optional)

Rootless Docker runs the daemon and containers as an unprivileged user for stronger isolation. Suitable when you cannot grant `docker` group access to users.

### Pros
- Least privilege: no root daemon; reduced risk surface
- Multi-user friendly: each user can run their own daemon/socket
- No need to add users to the `docker` group

### Cons
- Networking: no `--network=host`; slower user-mode networking; cannot bind privileged ports (<1024)
- Features: limited device access (GPUs), no `--privileged`, constrained cgroups and kernel integrations
- Storage: uses `fuse-overlayfs`; slight performance overhead vs rootful
- Bind mounts: you can easily mount only paths you own

### Setup on Ubuntu
```bash
sudo apt update
sudo apt install -y uidmap dbus-user-session

# Install rootless components
dockerd-rootless-setuptool.sh install

# Start/enable user service
systemctl --user enable --now docker

# Keep user services after logout (optional)
loginctl enable-linger $USER

# Point the client to the rootless daemon
export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock
docker info | grep -i rootless
```

### MinIO Notes with Rootless
- Ports 9000/9001 (>1024) are fine in rootless.
- Set `LOCAL_MOUNT` in `.env` to a path you own (e.g., `/home/your-user/minio-data`).
- For heavy I/O scenarios, rootful Docker may offer better performance.

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section
2. Review the logs: `docker compose logs`
3. Verify your configuration: `cat .env`
4. Check system requirements
5. Open an issue with detailed information

---

**Happy storing! 🗄️**
