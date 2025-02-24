# Trading WebApp

## Description
A simple backend service that exposes REST APIs, containerizes the application using Docker, deploys it on an AWS EC2 instance, and sets up a CI/CD pipeline using GitHub Actions.

## Tech Stack
- **Golang (Gin/Echo)** for building REST APIs
- **PostgreSQL** for storing order data
- **Docker** for containerization
- **Packer** for AMI creation
- **Terraform** for infrastructure provisioning
- **GitHub Actions** for CI/CD

## Deployment Process
### Automated Deployment (CI/CD Pipeline)
1. **Push to Main Branch**: When code is pushed to the `main` branch, GitHub Actions triggers an automated build and deployment workflow.
2. **Docker Image Build & Push**: The workflow builds the Docker image and pushes it to DockerHub.
3. **AMI Creation**: Packer builds a new AMI using the latest Docker image.
4. **Infrastructure Deployment**: Run Terraform locally to provision infrastructure, which fetches the latest AMI.
5. **Instance Startup**: The EC2 instance launches with the latest AMI, starting the trading service.
6. **API Testing**: Once the instance is running, test the API endpoints.

### Manual Deployment
#### 1. Build & Push Docker Image
```sh
docker build -t trading-service .
docker tag trading-service:latest <dockerhub-username>/trading-service:latest
docker push <dockerhub-username>/trading-service:latest
```

#### 2. Build AMI with Packer
```sh
cd packer
packer init ami.pkr.hcl
packer build ami.pkr.hcl
```
This process pulls the Docker image from DockerHub and sets up a service for the Go webapp inside the AMI.

#### 3. Deploy Infrastructure with Terraform
```sh
cd terraform
terraform init
terraform apply -var-file="terraform.tfvars"
```
Once the EC2 instance launches, the application will be available at `http://<ec2-ip>:8080`

## API Endpoints
### 1. Submit Trade Order
**Endpoint:** `POST http://<ip_address>:8080/orders`

**Request Body:**
```json
{
    "symbol": "GOOGL",
    "price": 150.50,
    "quantity": 100,
    "order_type": "SELL"
}
```

**Response:**
```json
{
    "id": 1,
    "symbol": "GOOGL",
    "price": 150.5,
    "quantity": 100,
    "order_type": "SELL",
    "status": "PENDING",
    "created_at": "2025-02-24T21:02:49.665972Z",
    "updated_at": "2025-02-24T21:02:49.665972Z"
}
```

### 2. Get All Orders
**Endpoint:** `GET http://<ip_address>:8080/orders`

**Response:**
```json
[
    {
        "id": 1,
        "symbol": "GOOGL",
        "price": 150.5,
        "quantity": 100,
        "order_type": "SELL",
        "status": "PENDING",
        "created_at": "2025-02-24T21:02:49.665972Z",
        "updated_at": "2025-02-24T21:02:49.665972Z"
    }
]
```

## Directory Structure
```
trading-webapp/
├── .github/workflows/
│   ├── packer-check.yml  # Check packer fmt and validate
│   ├── docker-build.yml  # Builds Docker image but does not push
│   ├── packer-build.yml  # Builds and pushes Docker image, then creates AMI
│
├── cmd/trading-service/
│   ├── main.go  # Application entry point
│
├── internal/
│   ├── app/
│   │   ├── server.go  # Server setup and routing
│   ├── config/
│   │   ├── config.go  # Configuration management
│   ├── database/
│   │   ├── database.go  # Database connection setup
│   ├── model/
│   │   ├── order.go  # Order struct and schema
│   ├── repository/
│   │   ├── repository.go  # Order repository methods
│   ├── websocket/
│   │   ├── hub.go  # WebSocket implementation
│
├── packer/
│   ├── ami.pkr.hcl  # AMI creation script
│   ├── scripts/
│   │   ├── setup.sh  # AMI setup scripts
│
├── terraform/
│   ├── main.tf  # Infrastructure setup
│   ├── variables.tf  # Variable definitions
│   ├── terraform.tfvars (not committed) # Deployment values
│
├── Dockerfile  # Docker image creation
```

## Terraform Variables (`terraform.tfvars` Example)
```hcl
aws_region           = "us-east-1"
project_name         = "trading-webapp"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]
instance_type        = "t2.micro"
key_name             = "your-key-pair-name"
ssh_allowed_cidr     = "your-ip"
```

## References
- [Gin Web Framework](https://gin-gonic.com/)
- [Docker Documentation](https://docs.docker.com/)
- [Packer by HashiCorp](https://www.packer.io/)
- [Terraform by HashiCorp](https://www.terraform.io/)
- [GitHub Actions](https://docs.github.com/en/actions)

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

