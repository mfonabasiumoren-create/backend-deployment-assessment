
#!/bin/bash
set -euo pipefail

# Log bootstrap activity
exec > >(tee -a /var/log/backend-bootstrap.log) 2>&1

echo "Starting Backend EC2 setup..."

# Update installed packages and install curl
yum update -y
yum install -y curl

# Install Docker
amazon-linux-extras install docker -y

# Start and enable Docker
systemctl enable docker
systemctl start docker

# Add ec2-user to the Docker group
usermod -aG docker ec2-user

# Install Docker Compose v2
DOCKER_COMPOSE_VERSION="v2.29.7"

mkdir -p /usr/local/lib/docker/cli-plugins

curl -fsSL \
  "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose

chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Create application deployment directory
mkdir -p /opt/muchtodo
chown ec2-user:ec2-user /opt/muchtodo

# Verify Docker and Docker Compose
docker --version
docker compose version
systemctl is-active docker

echo "Backend EC2 setup completed."
