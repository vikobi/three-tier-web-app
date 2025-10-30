# --------------------------------------------------------------------------------
# Network and Application Endpoints
# --------------------------------------------------------------------------------
output "application_load_balancer_dns" {
  description = "The DNS name of the Application Load Balancer (ALB) to access the app."
  value       = aws_lb.alb.dns_name
}

# --------------------------------------------------------------------------------
# SSH Access Information (EC2 IPs are dynamic within the ASG)
# --------------------------------------------------------------------------------
output "find_ec2_ips_command" {
  description = "Run this AWS CLI command after deployment to list public IPs of running EC2 instances for SSH/manual access."
  value       = "aws ec2 describe-instances --filters \"Name=tag:Name,Values=${var.web_app_name}-ec2-instance\" \"Name=instance-state-name,Values=running\" --query 'Reservations[].Instances[].PublicIpAddress'"
}

output "ssh_instructions" {
  description = "SSH access requires finding the running instance IP first (using the command above), then use your key with the ec2-user or deploy user."
  value       = "ssh -i <path/to/your/private_key.pem> ec2-user@<Instance_Public_IP> OR deploy@<Instance_Public_IP>"
}

# --------------------------------------------------------------------------------
# Secrets Manager Details (Use this ARN to fetch credentials securely in your app)
# --------------------------------------------------------------------------------
output "rds_secrets_manager_arn" {
  description = "The ARN for the database credentials stored in Secrets Manager."
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

# --------------------------------------------------------------------------------
# Database Connection Details
# --------------------------------------------------------------------------------
output "rds_endpoint" {
  description = "The host name for connecting to the RDS MySQL instance."
  value       = aws_db_instance.rds.address
}

output "rds_port" {
  description = "The connection port (3306) for the RDS MySQL instance."
  value       = aws_db_instance.rds.port
}