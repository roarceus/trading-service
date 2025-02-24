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

# Add user to the Docker group
sudo usermod -aG docker $USER
newgrp docker  # Apply changes immediately

# Install PostgreSQL
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Configure PostgreSQL
sudo -u postgres psql -c "CREATE DATABASE trading_db;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE trading_db TO $DB_USER;"

# Install Docker Credential Helper for Pass
sudo apt-get install -y golang-go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$PATH

go install github.com/docker/docker-credential-helpers/pass@latest
sudo mv ~/go/bin/docker-credential-pass /usr/local/bin/
sudo chmod +x /usr/local/bin/docker-credential-pass

# Configure Docker to use the pass credential helper
mkdir -p ~/.docker
echo '{ "credsStore": "pass" }' | tee ~/.docker/config.json

# Initialize pass for secure credential storage
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

# Initialize pass with the GPG key
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
