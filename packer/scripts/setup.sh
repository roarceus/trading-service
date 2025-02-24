#!/bin/bash
set -e

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install required dependencies
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2 pass

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Enable Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Add user to the Docker group (avoids using sudo for Docker commands)
sudo usermod -aG docker $USER
newgrp docker  # Apply changes to the current session

# Install PostgreSQL
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Configure PostgreSQL
sudo -u postgres psql -c "CREATE DATABASE trading_db;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE trading_db TO $DB_USER;"

# Configure Docker credential store securely
mkdir -p ~/.docker
echo '{ "credsStore": "pass" }' | tee ~/.docker/config.json

# Initialize pass for secure credential storage (requires GPG setup)
gpg --batch --gen-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Docker Credential Helper
Name-Email: docker@localhost
Expire-Date: 0
%commit
EOF

# Configure pass to store credentials
pass init "Docker Credential Helper"

# Login to Docker securely
echo "$DOCKER_TOKEN" | docker login --username "$DOCKER_USERNAME" --password-stdin

# Pull Docker image
docker pull $DOCKER_USERNAME/trading-service:latest

# Create service directory
sudo mkdir -p /opt/trading-service
sudo chown -R $USER:$USER /opt/trading-service

# Create startup script
cat << EOF > /opt/trading-service/start.sh
#!/bin/bash
docker run -d \
  --name trading-service \
  --network="host" \
  --env-file /opt/trading-service/.env \
  -p 8080:8080 \
  $DOCKER_USERNAME/trading-service:latest
EOF

# Make startup script executable
chmod +x /opt/trading-service/start.sh
