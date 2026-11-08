
variable "aws_region" {
  description = "AWS region where infrastructure will be deployed"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Project name used for AWS resource naming"
  type        = string
  default     = "startuptech"
}

variable "vpc_cidr" {
  description = "CIDR block for the StartupTech VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Two availability zones for the deployment"
  type        = list(string)
  default     = ["eu-north-1a", "eu-north-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the two private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for all three servers"
  type        = string
  default     = "t3.micro"
}

variable "my_ip" {
  description = "Your public IP address for restricted SSH access"
  type        = string
}

variable "key_pair_name" {
  description = "Existing AWS EC2 key pair name for SSH access"
  type        = string
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI ID for eu-north-1"
  type        = string
}
