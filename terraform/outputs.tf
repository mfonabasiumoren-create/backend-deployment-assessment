output "vpc_id" {
  description = "ID of the StartupTech VPC"
  value       = aws_vpc.startuptech_vpc.id
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.startuptech_alb.dns_name
}

output "bastion_public_ip" {
  description = "Public IP address of the Bastion host"
  value       = aws_eip.bastion_eip.public_ip
}

output "backend_private_ip" {
  description = "Private IP address of the Backend EC2 instance"
  value       = aws_instance.backend.private_ip
}