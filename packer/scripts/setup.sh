#!/bin/bash
set -e

echo "Starting setup script..."

# Update and install dependencies
echo "Updating system and installing dependencies..."
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    postgresql \
    postgresql-contrib

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Start Docker service
echo "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Wait for Docker to be ready
echo "Waiting for Docker to be ready..."
timeout 60 bash -c 'until sudo docker info >/dev/null 2>&1; do echo "Waiting for Docker to start..."; sleep 2; done'

# Create application directory and .env file
echo "Creating application directory..."
sudo mkdir -p /opt/trading-service

# Set up environment file
echo "Setting up environment file..."
sudo tee /opt/trading-service/.env <<EOF
DB_HOST=localhost
DB_PORT=5432
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=trading_db
EOF

# Set proper permissions
sudo chown root:root /opt/trading-service/.env
sudo chmod 600 /opt/trading-service/.env

# Log in to Docker Hub
echo "Logging into Docker Hub..."
echo "${DOCKER_TOKEN}" | sudo docker login -u "${DOCKER_USERNAME}" --password-stdin

# Pull the latest image
echo "Pulling Docker image..."
sudo docker pull ${DOCKER_USERNAME}/trading-service:latest

# Create systemd service file
echo "Creating systemd service file..."
sudo tee /etc/systemd/system/trading-service.service <<EOF
[Unit]
Description=Trading Service Container
Requires=docker.service postgresql.service
After=docker.service postgresql.service

[Service]
Type=simple
Restart=always
RestartSec=10
User=root
Group=root
EnvironmentFile=/opt/trading-service/.env
ExecStartPre=/bin/bash -c 'until pg_isready -h localhost -p 5432; do sleep 2; done'
ExecStartPre=-/usr/bin/docker stop trading-service
ExecStartPre=-/usr/bin/docker rm trading-service
ExecStart=/usr/bin/docker run --name trading-service \
    --network="host" \
    -e DB_HOST=localhost \
    -e DB_PORT=5432 \
    -e DB_USER=${DB_USER} \
    -e DB_PASSWORD=${DB_PASSWORD} \
    -e DB_NAME=trading_db \
    -v /opt/trading-service/.env:/app/.env \
    ${DOCKER_USERNAME}/trading-service:latest
ExecStop=/usr/bin/docker stop trading-service
StandardOutput=append:/var/log/trading-service.log
StandardError=append:/var/log/trading-service.error.log

[Install]
WantedBy=multi-user.target
EOF

# Create log files with proper permissions
sudo touch /var/log/trading-service.log /var/log/trading-service.error.log
sudo chmod 644 /var/log/trading-service.log /var/log/trading-service.error.log

# Configure PostgreSQL
echo "Configuring PostgreSQL..."
sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
sudo -u postgres psql -c "CREATE DATABASE trading_db;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE trading_db TO ${DB_USER};"
# Grant schema permissions
sudo -u postgres psql -d trading_db -c "GRANT ALL ON SCHEMA public TO ${DB_USER};"
sudo -u postgres psql -d trading_db -c "ALTER USER ${DB_USER} WITH SUPERUSER;"

# Update PostgreSQL configuration to allow local connections
echo "Updating PostgreSQL configuration..."
sudo sed -i 's/peer/md5/g' /etc/postgresql/*/main/pg_hba.conf
sudo sed -i 's/ident/md5/g' /etc/postgresql/*/main/pg_hba.conf

# Update postgresql.conf to listen on all interfaces
echo "Updating PostgreSQL to listen on all interfaces..."
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf

# Restart PostgreSQL
echo "Restarting PostgreSQL..."
sudo systemctl restart postgresql

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
timeout 60 bash -c 'until pg_isready; do echo "Waiting for PostgreSQL to start..."; sleep 2; done'

# Verify environment file exists
echo "Verifying environment file..."
if [ ! -f /opt/trading-service/.env ]; then
    echo "ERROR: Environment file not found!"
    exit 1
fi

# Enable and start the trading service
echo "Enabling and starting trading service..."
sudo systemctl daemon-reload
sudo systemctl enable trading-service
sudo systemctl start trading-service || {
    echo "Failed to start trading-service. Checking logs..."
    echo "Environment file contents:"
    sudo cat /opt/trading-service/.env
    echo "System logs:"
    sudo journalctl -u trading-service --no-pager -n 50
    sudo docker ps -a
    sudo docker logs trading-service || true
    exit 1
}

# Verify service status
echo "Verifying service status..."
sudo systemctl status trading-service --no-pager

# Clean up
echo "Cleaning up..."
sudo docker system prune -f

echo "Setup complete!"