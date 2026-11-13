# MuchToDo Go API — AWS Deployment Assessment

## Project Overview

This project demonstrates the containerisation and deployment of the MuchToDo Go REST API using Docker, Docker Compose, Terraform and Amazon Web Services (AWS).

The project provisions the required cloud infrastructure using Infrastructure as Code, configures secure network access, deploys the Go API to an EC2 instance and connects it to a separately hosted MongoDB database.

The implementation demonstrates:

- Docker containerisation and multi-stage builds.
- Terraform infrastructure provisioning.
- AWS VPC networking and subnet segmentation.
- EC2 deployment and Bastion-host administration.
- Application Load Balancer configuration.
- IAM roles and least-privilege access.
- AWS Systems Manager Parameter Store for secret retrieval.
- Amazon ECR image publishing and deployment.
- Application health checks and end-to-end connectivity verification.

## Technology Stack

| Component | Technology |
|---|---|
| Application | Go |
| Containerisation | Docker |
| Container orchestration | Docker Compose |
| Database | MongoDB |
| Infrastructure as Code | Terraform |
| Cloud platform | Amazon Web Services |
| Compute | Amazon EC2 |
| Container registry | Amazon ECR |
| Networking | VPC, public/private subnets, IGW, NAT Gateway |
| Load balancing | Application Load Balancer |
| Secrets management | AWS Systems Manager Parameter Store |
| Access control | IAM roles and security groups |

## AWS Architecture

The infrastructure is deployed in the AWS Europe (Stockholm) region (`eu-north-1`).

### Network architecture

- VPC CIDR: `10.0.0.0/16`
- Two public subnets distributed across separate Availability Zones.
- Two private subnets distributed across separate Availability Zones.
- Internet Gateway for public subnet connectivity.
- NAT Gateway for outbound connectivity from private subnets.
- Separate public and private route tables.

### Compute architecture

Three EC2 instances are provisioned:

| Instance | Private IP | Placement | Responsibility |
|---|---|---|---|
| Bastion | `10.0.1.138` | Public subnet | Controlled SSH administration |
| Backend | `10.0.11.188` | Private subnet | Hosts the MuchToDo API container |
| MongoDB | `10.0.12.10` | Private subnet | Hosts the MongoDB database |

All three instances use the `t3.micro` instance type.

### Application traffic flow

External HTTP traffic enters through the internet-facing Application Load Balancer.

The ALB forwards requests to the Backend EC2 instance on port `8080`.

The MuchToDo API connects to MongoDB over the private VPC network on port `27017`.

The MongoDB server is deployed independently on its dedicated EC2 instance rather than as a container on the Backend EC2 instance.

### Architecture summary

```text
                    Internet
                       |
                       |
             Application Load Balancer
                   HTTP :80
                       |
                       |
             Backend Security Group
                       |
                       |
              Backend EC2 Instance
                 10.0.11.188
                       |
                Docker Container
                 MuchToDo API
                   Port 8080
                       |
                       |
                 MongoDB SG
                       |
                       |
               MongoDB EC2
                 10.0.12.10
                   Port 27017


Administrator
     |
     | SSH
     |
Bastion EC2
10.0.1.138
     |
     | SSH
     |
Backend EC2
10.0.11.188
```

## Repository Structure

```text
backend-deployment-assessment/
│
├── Dockerfile
├── docker-compose.yml
├── docker-compose.prod.yml
├── .dockerignore
├── .env.example
├── README.md
│
├── evidence/
│   └── Deployment and infrastructure screenshots
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── .terraform.lock.hcl
│   │
│   └── user_data/
│       ├── backend_setup.sh
│       └── mongodb_setup.sh
│
└── Server/
    └── MuchToDo/
```

## Local Docker Deployment

### Prerequisites

- Docker Desktop
- Docker Compose
- Git

### Clone the repository

```bash
git clone https://github.com/mfonabasiumoren-create/backend-deployment-assessment.git

cd backend-deployment-assessment
```

### Configure environment variables

Create a local environment file:

```bash
cp .env.example .env
```

Configure the required application and MongoDB credentials in `.env`.

Do not commit this file.

### Build and start the services

```bash
docker compose build

docker compose up -d
```

### Verify container status

```bash
docker compose ps
```

The local Compose configuration defines:

- MuchToDo API service.
- MongoDB service.
- Persistent MongoDB volumes.
- Shared Docker network.
- MongoDB health check.
- Backend dependency on MongoDB health.
- Restart policies.

### Test the API

```bash
curl http://localhost:8080/health
```

The health endpoint should return a successful response indicating the application and database status.

## Terraform Infrastructure

### Prerequisites

- Terraform
- AWS CLI
- Authenticated AWS account
- Existing EC2 key pair

### Configure Terraform variables

Navigate to the Terraform directory:

```bash
cd terraform
```

Create the local variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Configure the appropriate:

- AWS region.
- Availability Zones.
- Instance types.
- Amazon Linux 2 AMI.
- EC2 key pair.
- Administrator public IP address.

The `terraform.tfvars` file must remain excluded from version control.

### Initialise Terraform

```bash
terraform init
```

### Format and validate

```bash
terraform fmt -recursive

terraform validate
```

### Review the infrastructure plan

```bash
terraform plan
```

### Provision the infrastructure

After reviewing the proposed changes:

```bash
terraform apply
```

Confirm the operation when prompted.

### Retrieve infrastructure outputs

```bash
terraform output
```

The configured outputs include:

- VPC ID.
- ALB DNS name.
- Bastion public IP.
- Backend private IP.

### Infrastructure verification

The deployed Terraform state records 34 infrastructure resources.

The configuration has been formatted and validated successfully.

## AWS Application Deployment

### 1. Build the Docker image

The application uses a multi-stage Dockerfile to produce a lean runtime image.

The container:

- Uses a non-root application user.
- Exposes port `8080`.
- Includes an application health check.
- Uses additional container security restrictions.

### 2. Publish the image to Amazon ECR

The production image is stored in the following ECR repository:

```text
849076101572.dkr.ecr.eu-north-1.amazonaws.com/muchtodo-api
```

The deployed image tag is:

```text
v1
```

The image was built locally for the Linux AMD64 platform and successfully pushed to ECR.

### 3. Access the Backend EC2 instance

SSH access to the private Backend EC2 instance is established through the Bastion host.

The Backend instance does not require a public IP address.

### 4. Retrieve application configuration

Production application configuration is stored in `.env.production` on the Backend EC2 instance.

Sensitive configuration values are retrieved from AWS Systems Manager Parameter Store using the Backend instance's IAM role.

Credentials are not embedded directly in the production Docker image.

### 5. Deploy the API container

The production Compose configuration references the ECR image and the production environment file.

Start the application:

```bash
sudo docker compose -f docker-compose.prod.yml up -d
```

Check container status:

```bash
sudo docker compose -f docker-compose.prod.yml ps
```

Inspect container health:

```bash
sudo docker inspect muchtodo-api --format 'Status: {{.State.Status}} | Health: {{.State.Health.Status}}'
```

The deployed API container was verified as running and healthy.

### 6. MongoDB connectivity

MongoDB is hosted independently on the dedicated private MongoDB EC2 instance.

The database:

- Uses authentication.
- Runs as a replica set.
- Uses a dedicated application database user.
- Restricts inbound access to the Backend security group.
- Retrieves bootstrap credentials from Systems Manager Parameter Store.

The Backend application successfully connected to MongoDB.

## Production Docker Compose Design

Two Compose configurations are maintained for different deployment environments.

### Local development

`docker-compose.yml` defines both the API and MongoDB services.

This supports local application development and testing.

### AWS production

`docker-compose.prod.yml` defines the API service and uses the prebuilt ECR image.

MongoDB is accessed remotely through its private EC2 address.

This separation avoids running a duplicate MongoDB service on the Backend EC2 instance.

## Security Considerations

The deployment implements the following security controls:

- Backend and MongoDB instances are placed in private subnets.
- Bastion SSH access is restricted to the administrator's current public IP.
- Backend HTTP access on port `8080` is restricted to the ALB security group.
- Backend SSH access is restricted to the Bastion security group.
- MongoDB port `27017` is accessible only from the Backend security group.
- IAM roles provide scoped access to required Systems Manager parameters and ECR image retrieval.
- Application credentials are retrieved from Parameter Store rather than embedded in the Docker image.
- The application container runs as a non-root user.
- Container capabilities are dropped.
- Privilege escalation is disabled.
- The container uses a read-only root filesystem.
- Environment files, Terraform state, saved plans and private SSH keys are excluded from Git.

## Deployment Verification

The following deployment tests were completed successfully.

| Verification | Result |
|---|---|
| Terraform formatting | Passed |
| Terraform validation | Passed |
| Infrastructure provisioning | 34 resources recorded |
| EC2 instances | All three running |
| Backend Docker container | Running and healthy |
| MongoDB connectivity | Successful |
| ALB target health | Healthy |
| Public `/health` endpoint | HTTP 200 OK |
| Public `/ping` endpoint | HTTP 200 OK |

### Public API health test

```bash
curl http://<ALB-DNS-NAME>/health
```

Verified response:

```json
{
  "cache": "disabled",
  "database": "ok"
}
```

### Public ping test

```bash
curl http://<ALB-DNS-NAME>/ping
```

Verified response:

```json
{
  "message": "pong"
}
```

Both endpoints were successfully tested through the public Application Load Balancer.

## Evidence

The `evidence/` directory contains screenshots documenting:

- Local Docker container status.
- Local API health checks.
- User registration and login.
- JWT authentication and protected endpoint access.
- Terraform initialisation and planning.
- VPC and subnet configuration.
- SSH access through the Bastion host.
- Docker Compose deployment on Backend EC2.
- Public API access through the ALB.
- Security-group inbound rules.
- EC2 instances running.
- Application Load Balancer and target group configuration.
- Healthy ALB target status.

The original Terraform Apply completion screenshot was not available during final evidence collection. Infrastructure provisioning is independently supported by the Terraform state resource inventory and the deployed AWS resources.

## Terraform State and Sensitive Files

The original assessment requests submission of the Terraform state file.

Terraform state can contain infrastructure metadata, resource attributes and sensitive information.

The state file is therefore excluded from Git version control.

Before any separate submission, inspect the state for sensitive information and follow the instructor's approved secure submission method.

Do not publish the raw state file in a public GitHub repository.

## Cleanup and Resource Teardown

AWS infrastructure incurs ongoing charges, particularly EC2 instances, NAT Gateway, Application Load Balancer, Elastic IPs and data transfer.

After completing the assessment and collecting all required evidence, review the infrastructure before destroying it.

To remove the Terraform-managed infrastructure:

```bash
cd terraform

terraform plan -destroy

terraform destroy
```

Review the destruction plan carefully before confirming.

Do not run the destruction command while the deployed application or infrastructure is still required.

Also review and remove any separately created resources that are not managed by the Terraform configuration, such as the ECR repository and its images, if they are no longer needed.

## Important Notes

Never commit:

- `.env`
- `.env.production`
- `terraform/terraform.tfvars`
- `terraform/terraform.tfstate`
- `terraform/terraform.tfstate.backup`
- `terraform/tfplan`
- Private SSH keys
- AWS credentials
- Database passwords
- JWT signing secrets

Use the supplied example files to configure your own environment.

---

**Project:** MuchToDo Go API — AWS Deployment Assessment

**Cloud Region:** `eu-north-1`

**Infrastructure:** Terraform-managed AWS resources

**Application Deployment:** Docker and Amazon ECR

**Database:** Dedicated MongoDB EC2 instance