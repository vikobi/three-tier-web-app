# --------------------------------------------------------------------------------
# General Variables
# --------------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "web_app_name" {
  description = "A prefix for naming all resources."
  type        = string
  default     = "three-tier-web-app"
}

variable "my_ip" {
  description = "Your public IP address in CIDR notation (e.g., 1.2.3.4/32) for SSH and DB access."
  type        = string
}

# --------------------------------------------------------------------------------
# VPC Variables
# --------------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "A list of CIDR blocks for public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "A list of CIDR blocks for private subnets."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# --------------------------------------------------------------------------------
# EC2 & ASG Variables (High Availability Focused)
# --------------------------------------------------------------------------------
variable "instance_type" {
  description = "The EC2 instance type (e.g., t2.micro for Free Tier)."
  type        = string
  default     = "t3.micro" 
}

variable "key_name" {
  description = "The name of the SSH Key Pair to use for EC2."
  type        = string
}

variable "public_key_location" {
  description = "The path to your public SSH key file (e.g., ~/.ssh/id_rsa.pub)."
  type        = string
}

variable "asg_desired_capacity" {
  description = "The desired number of EC2 instances running."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "The maximum number of EC2 instances allowed."
  type        = number
  default     = 2
}

variable "asg_min_size" {
  description = "The minimum number of EC2 instances required to be running."
  type        = number
  default     = 1
}

# --------------------------------------------------------------------------------
# RDS Variables (MySQL 8.0)
# --------------------------------------------------------------------------------
variable "rds_engine" {
  description = "The database engine."
  type        = string
  default     = "mysql"
}

variable "rds_engine_version" {
  description = "The database engine version."
  type        = string
  default     = "8.0"
}

variable "rds_instance_class" {
  description = "The RDS instance class (db.t3.micro or db.t2.micro for Free Tier)."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "The allocated storage in GB (Free Tier allows up to 20 GB)."
  type        = number
  default     = 20 
}

variable "rds_master_username" { 
  description = "Master/Root username for the RDS instance (from DB_USER=root)."
  type        = string
}

variable "rds_master_password" { 
  description = "Master/Root password for the RDS instance (from DB_PASSWORD)."
  type        = string
  sensitive   = true
}