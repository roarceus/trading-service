#!/bin/bash
set -e

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker

# Install PostgreSQL
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl enable postgresql

# Configure PostgreSQL
sudo -u postgres psql -c "CREATE DATABASE trading_db;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE trading_db TO $DB_USER;"

# Configure Docker credentials and pull image
echo "$DOCKER_TOKEN" | docker login --username "$DOCKER_USERNAME" --password-stdin
docker pull $DOCKER_USERNAME/trading-service:latest

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

chmod +x /opt/trading-service/start.sh
