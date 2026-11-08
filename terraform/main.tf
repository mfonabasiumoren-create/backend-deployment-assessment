
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

# Retrieve the current AWS account ID
data "aws_caller_identity" "current" {}


# =========================================================
# 1. VPC
# =========================================================

resource "aws_vpc" "startuptech_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "startuptech-vpc"
  }
}


# =========================================================
# 2. SUBNETS
# =========================================================

# Public Subnet A
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.startuptech_vpc.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-a"
    Type = "Public"
  }
}

# Public Subnet B
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.startuptech_vpc.id
  cidr_block              = var.public_subnet_cidrs[1]
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-b"
    Type = "Public"
  }
}

# Private Subnet A
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.startuptech_vpc.id
  cidr_block        = var.private_subnet_cidrs[0]
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "${var.project_name}-private-subnet-a"
    Type = "Private"
  }
}

# Private Subnet B
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.startuptech_vpc.id
  cidr_block        = var.private_subnet_cidrs[1]
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "${var.project_name}-private-subnet-b"
    Type = "Private"
  }
}


# =========================================================
# 3. INTERNET GATEWAY
# =========================================================

resource "aws_internet_gateway" "startuptech_igw" {
  vpc_id = aws_vpc.startuptech_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}


# =========================================================
# 4. NAT GATEWAY
# =========================================================

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }

  depends_on = [
    aws_internet_gateway.startuptech_igw
  ]
}

resource "aws_nat_gateway" "startuptech_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "${var.project_name}-nat-gateway"
  }

  depends_on = [
    aws_internet_gateway.startuptech_igw
  ]
}


# =========================================================
# 5. ROUTE TABLES
# =========================================================

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.startuptech_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.startuptech_igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Public Subnet A Association
resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

# Public Subnet B Association
resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.startuptech_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.startuptech_nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Private Subnet A Association
resource "aws_route_table_association" "private_a_assoc" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

# Private Subnet B Association
resource "aws_route_table_association" "private_b_assoc" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}


# =========================================================
# 6. SECURITY GROUPS
# =========================================================

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP and HTTPS from the internet"
  vpc_id      = aws_vpc.startuptech_vpc.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Backend Security Group
resource "aws_security_group" "backend_sg" {
  name        = "${var.project_name}-backend-sg"
  description = "Allow API traffic from ALB and SSH from Bastion"
  vpc_id      = aws_vpc.startuptech_vpc.id

  ingress {
    description     = "API traffic from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-backend-sg"
  }
}

# Bastion Security Group
resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH only from administrator IP"
  vpc_id      = aws_vpc.startuptech_vpc.id

  ingress {
    description = "SSH from administrator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

# MongoDB Security Group
resource "aws_security_group" "mongodb_sg" {
  name        = "${var.project_name}-mongodb-sg"
  description = "Allow MongoDB access only from Backend"
  vpc_id      = aws_vpc.startuptech_vpc.id

  ingress {
    description     = "MongoDB from Backend only"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-mongodb-sg"
  }
}


# =========================================================

# =========================================================
# 7. IAM ROLES
# =========================================================

# EC2 Assume Role Policy
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Backend IAM Role
resource "aws_iam_role" "backend_role" {
  name               = "${var.project_name}-backend-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-backend-role"
  }
}

# MongoDB IAM Role
resource "aws_iam_role" "mongodb_role" {
  name               = "${var.project_name}-mongodb-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-mongodb-role"
  }
}


# =========================================================
# 8. EC2 INSTANCE PROFILES
# =========================================================

resource "aws_iam_instance_profile" "backend_profile" {
  name = "${var.project_name}-backend-profile"
  role = aws_iam_role.backend_role.name
}

resource "aws_iam_instance_profile" "mongodb_profile" {
  name = "${var.project_name}-mongodb-profile"
  role = aws_iam_role.mongodb_role.name
}


# =========================================================
# 9. SYSTEMS MANAGER ACCESS
# =========================================================

resource "aws_iam_role_policy_attachment" "backend_ssm" {
  role       = aws_iam_role.backend_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "mongodb_ssm" {
  role       = aws_iam_role.mongodb_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# =========================================================
# 10. PARAMETER STORE PERMISSIONS
# =========================================================

# Backend can access backend parameters only
resource "aws_iam_role_policy" "backend_parameter_access" {
  name = "${var.project_name}-backend-parameter-access"
  role = aws_iam_role.backend_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]

      Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/backend/*"
    }]
  })
}

# MongoDB can access MongoDB parameters only
resource "aws_iam_role_policy" "mongodb_parameter_access" {
  name = "${var.project_name}-mongodb-parameter-access"
  role = aws_iam_role.mongodb_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]

      Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/mongodb/*"
    }]
  })
}


# =========================================================
# 8. EC2 INSTANCE PROFILE
# =========================================================


# =========================================================
# 9. SYSTEMS MANAGER POLICY
# =========================================================


# =========================================================
# 10. PARAMETER STORE PERMISSIONS
# =========================================================



# =========================================================
# 11. BASTION EC2 INSTANCE
# =========================================================

resource "aws_instance" "bastion" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = var.key_pair_name

  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-bastion"
  }
}


# Bastion Elastic IP
resource "aws_eip" "bastion_eip" {
  domain   = "vpc"
  instance = aws_instance.bastion.id

  tags = {
    Name = "${var.project_name}-bastion-eip"
  }
}


# =========================================================
# 12. BACKEND EC2 INSTANCE
# =========================================================

resource "aws_instance" "backend" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = var.key_pair_name

  associate_public_ip_address = false

  iam_instance_profile = aws_iam_instance_profile.backend_profile.name

  user_data = file("${path.module}/user_data/backend_setup.sh")

  tags = {
    Name = "${var.project_name}-backend"
  }
}


# =========================================================
# 13. MONGODB EC2 INSTANCE
# =========================================================

resource "aws_instance" "mongodb" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_b.id
  private_ip             = "10.0.12.10"
  vpc_security_group_ids = [aws_security_group.mongodb_sg.id]
  key_name               = var.key_pair_name

  associate_public_ip_address = false

  iam_instance_profile = aws_iam_instance_profile.mongodb_profile.name
  user_data            = file("${path.module}/user_data/mongodb_setup.sh")

  tags = {
    Name = "${var.project_name}-mongodb"
  }
}
# Application Load Balancer
resource "aws_lb" "startuptech_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}
# Backend Target Group
resource "aws_lb_target_group" "backend_tg" {
  name        = "${var.project_name}-backend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.startuptech_vpc.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-backend-tg"
  }
}
# Register Backend with Target Group
resource "aws_lb_target_group_attachment" "backend_attachment" {
  target_group_arn = aws_lb_target_group.backend_tg.arn
  target_id        = aws_instance.backend.id
  port             = 8080
}
# HTTP Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.startuptech_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}