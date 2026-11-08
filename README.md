**# MuchToDo Go API â€“ AWS Deployment Assessment**



**## Project Overview**



**This project packages and deploys the MuchToDo Go REST API using Docker and provisions its AWS infrastructure using Terraform.**



**The assessment demonstrates containerisation, infrastructure as code, network segmentation, security-group configuration, IAM roles, secure parameter retrieval and application deployment architecture.**



**## Technology Stack**



**- \*\*Application:\*\* Go**

**- \*\*Containerisation:\*\* Docker and Docker Compose**

**- \*\*Database:\*\* MongoDB**

**- \*\*Infrastructure as Code:\*\* Terraform**

**- \*\*Cloud Platform:\*\* Amazon Web Services (AWS)**

**- \*\*Compute:\*\* Amazon EC2**

**- \*\*Networking:\*\* VPC, public and private subnets, Internet Gateway and NAT Gateway**

**- \*\*Load Balancing:\*\* Application Load Balancer**

**- \*\*Secrets Management:\*\* AWS Systems Manager Parameter Store**

**- \*\*Access Control:\*\* IAM roles and security groups**



**## Architecture**



**The planned AWS architecture consists of:**



**1. A VPC with CIDR block `10.0.0.0/16`.**

**2. Two public subnets distributed across separate Availability Zones.**

**3. Two private subnets distributed across separate Availability Zones.**

**4. An Internet Gateway for public subnet connectivity.**

**5. A NAT Gateway for outbound connectivity from private subnets.**

**6. A Bastion EC2 instance for controlled administrative access.**

**7. A Backend EC2 instance hosting the Go API.**

**8. A separate MongoDB EC2 instance.**

**9. An Application Load Balancer distributing HTTP traffic to the backend.**

**10. IAM roles and security groups restricting access between components.**



**## Repository Structure**



**```text**

**backend-deployment-assessment/**

**â”œâ”€â”€ Dockerfile**

**â”œâ”€â”€ docker-compose.yml**

**â”œâ”€â”€ .dockerignore**

**â”œâ”€â”€ .env.example**

**â”œâ”€â”€ README.md**

**â”œâ”€â”€ evidence/**

**â”œâ”€â”€ terraform/**

**â”‚   â”œâ”€â”€ main.tf**

**â”‚   â”œâ”€â”€ variables.tf**

**â”‚   â”œâ”€â”€ outputs.tf**

**â”‚   â”œâ”€â”€ terraform.tfvars.example**

**â”‚   â”œâ”€â”€ .terraform.lock.hcl**

**â”‚   â””â”€â”€ user\_data/**

**â”‚       â”œâ”€â”€ backend\_setup.sh**

**â”‚       â””â”€â”€ mongodb\_setup.sh**

**â””â”€â”€ Server/**

&#x20;   **â””â”€â”€ MuchToDo/**

**```**



**## Local Docker Deployment**



**### Prerequisites**



**- Docker Desktop**

**- Docker Compose**

**- Git**



**### Setup**



**Clone the repository:**



**```bash**

**git clone https://github.com/mfonabasiumoren-create/backend-deployment-assessment.git**

**cd backend-deployment-assessment**

**```**



**Create your local environment file:**



**```bash**

**cp .env.example .env**

**```**



**Update `.env` with appropriate local credentials and application configuration.**



**Build and start the containers:**



**```bash**

**docker compose build**

**docker compose up -d**

**```**



**Check container status:**



**```bash**

**docker compose ps**

**```**



**Test the API health endpoint:**



**```bash**

**curl http://localhost:8080/health**

**```**



**The local Compose configuration runs the API and MongoDB with persistent storage, a shared Docker network and a MongoDB health check.**



**## Terraform Infrastructure**



**### Prerequisites**



**- Terraform**

**- AWS CLI**

**- An authenticated AWS account**

**- An EC2 key pair**



**### Deployment preparation**



**Navigate to the Terraform directory:**



**```bash**

**cd terraform**

**```**



**Create a local variables file from the example:**



**```bash**

**cp terraform.tfvars.example terraform.tfvars**

**```**



**Update the variables with the appropriate AWS region, Availability Zones, instance type, AMI, key pair and current public IP address.**



**Initialise Terraform:**



**```bash**

**terraform init**

**```**



**Format and validate the configuration:**



**```bash**

**terraform fmt -recursive**

**terraform validate**

**```**



**Review the proposed infrastructure:**



**```bash**

**terraform plan**

**```**



**Apply the configuration only after reviewing the plan:**



**```bash**

**terraform apply**

**```**



**Retrieve the infrastructure outputs:**



**```bash**

**terraform output**

**```**



**## Security Considerations**



**- Backend and MongoDB instances are placed in private subnets.**

**- SSH access to the Bastion is restricted to the configured administrator IP.**

**- Backend access is restricted to the Application Load Balancer and Bastion security groups.**

**- MongoDB access is restricted to the Backend security group.**

**- IAM roles provide scoped access to required Systems Manager parameters.**

**- Environment files, Terraform state, saved plans and private keys are excluded from version control.**

**- The application container runs as a non-root user with additional container security restrictions.**



**## Evidence**



**The `evidence/` directory contains screenshots documenting the Docker build and runtime tests, API functionality, authentication, Terraform initialisation and planning, and AWS infrastructure provisioning.**



**## Implementation Status**



**The following work has been completed:**



**- Docker image built successfully.**

**- Local MongoDB and API containers started and reported healthy.**

**- API health endpoint tested successfully.**

**- User registration and login tested successfully.**

**- JWT authentication and a protected API endpoint tested successfully.**

**- Terraform configuration formatted and validated.**

**- AWS infrastructure provisioned successfully: 34 resources added, with no changes or deletions.**



**\*\*Remaining verification:\*\* AWS EC2 bootstrap completion, remote MongoDB connectivity, backend application deployment and successful end-to-end access through the Application Load Balancer have not yet been verified.**



**## Important Notes**



**Do not commit the following files:**



**- `.env`**

**- `terraform/terraform.tfvars`**

**- `terraform/terraform.tfstate`**

**- `terraform/tfplan`**

**- Private SSH keys**



**Use the supplied example files to configure your own environment.**
