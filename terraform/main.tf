# --------------------------------------------------------------------------------
# Provider
# --------------------------------------------------------------------------------
provider "aws" {
    region = var.aws_region
    # AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are read from environment variables
}

# ================================================================================
# VPC and Subnets

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
        Name = "${var.web_app_name}-vpc"
    }
}


# Declare the data source
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnets[count.index]
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[count.index]
    tags = {
            Name = "${var.web_app_name}-public-subnet-${count.index + 1}" 
        }
}

resource "aws_subnet" "private" {
  count      = length(var.private_subnets)
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index] 
    tags = {
            Name = "${var.web_app_name}-private-subnet-${count.index + 1}"
        }
}

# ================================================================================
# Internet Gateway and Route Table for Public Subnets and Private subnets

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.web_app_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
    tags = {
        Name = "${var.web_app_name}-public-rt"
    }
}
resource "aws_route_table_association" "pub-rtb-aws_route_table_association" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
  
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.web_app_name}-nat-eip"
  }
}
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.web_app_name}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.gw]
  
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
    }   
    tags = {
        Name = "${var.web_app_name}-private-rt"
    } 
}
resource "aws_route_table_association" "priv-rtb-aws_route_table_association" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ================================================================================
# Security Groups
resource "aws_security_group" "alb_sg" {
  name        = "${var.web_app_name}-alb-sg"
  description = "Allow HTTP and HTTPS traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
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
        Name = "${var.web_app_name}-alb-sg"
    } 
}
resource "aws_security_group" "ec2_sg" {
  name        = "${var.web_app_name}-ec2-sg"
  description = "Allow traffic from ALB to EC2 instances and SSH for admin"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    description     = "App/Container Port (e.g., 3000/4000) from ALB"
    from_port       = 3000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
   ingress {
    description     = "SSH from admin IP"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = [var.my_ip] 
  }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "${var.web_app_name}-ec2-sg"
    }   
} 
resource "aws_security_group" "rds_sg" {
  name        = "${var.web_app_name}-rds-sg"
  description = "Allow MySQL traffic from EC2/App Server only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EC2/App Server"
    from_port       = 3306 
    to_port         = 3306 
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  ingress {
    description     = "MySQL from admin IP (for DB migration/restore)"
    from_port       = 3306 
    to_port         = 3306 
    protocol        = "tcp"
    cidr_blocks     = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
    tags = {
        Name = "${var.web_app_name}-rds-sg"
    }   
}

# ================================================================================
# Application Load Balancer + Target Group + Listener 
resource "aws_lb" "alb" {
  name               = "${var.web_app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.web_app_name}-alb"
  }
}

# Backend target group on port 4000
resource "aws_lb_target_group" "tg_backend" {
  name     = "${var.web_app_name}-backend"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.web_app_name}-backend-tg"
  }
}

# Rule: /api/* goes to backend target group
resource "aws_lb_listener_rule" "api_rule" {
  listener_arn = aws_lb_listener.listener_frontend.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# Frontend target group on port 3000
resource "aws_lb_target_group" "tg_frontend" {
  name     = "${var.web_app_name}-frontend"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
    tags = {
        Name = "${var.web_app_name}-frontend-tg"
    }
}
resource "aws_lb_listener" "listener_frontend" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_frontend.arn
  }
}

# ================================================================================
# IAM Role and Instance Profile for EC2
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name  = "name"
    values = ["al2023-ami-*-x86_64*"]
  }
  filter {
    name  = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "ec2_role" {
  name               = "${var.web_app_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.web_app_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --------------------------------------------------------------------------------
# IAM Policy to allow EC2 to read the RDS Secret
# --------------------------------------------------------------------------------
data "aws_iam_policy_document" "secrets_read_policy_doc" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.rds_credentials.arn]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "secrets_read_policy" {
  name   = "${var.web_app_name}-secrets-read-policy"
  policy = data.aws_iam_policy_document.secrets_read_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "ec2_secrets_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_read_policy.arn
}

# Launch Template for EC2 Instances (Used by the ASG)

resource "aws_key_pair" "dev-key" {
  key_name   = var.key_name
  public_key = file(var.public_key_location) 
  
}
resource "aws_launch_template" "app" {
  name_prefix   = "${var.web_app_name}-lt"
  image_id      = data.aws_ami.amazon_linux_2023.id 
  instance_type = var.instance_type
  key_name      = aws_key_pair.dev-key.key_name

  network_interfaces {
  associate_public_ip_address = true
  security_groups             = [aws_security_group.ec2_sg.id]
}

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(<<-EOF
                #!/bin/bash
                
                # --- System Setup ---
                sudo yum update -y
                
                # --- Docker/Compose Installation ---
                sudo amazon-linux-extras install docker -y
                sudo systemctl enable docker
                sudo systemctl start docker
                
                # Install Docker Compose (latest stable version)
                sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                sudo chmod +x /usr/local/bin/docker-compose
                
                # Optional: install git for cloning repo later
                sudo yum install -y git
                
                # --- New Deployment User Setup ---
                # 1. Create the 'deploy' user (with home directory)
                sudo useradd -m deploy
                
                # 2. Add 'deploy' user to the docker group
                sudo usermod -aG docker deploy
                
                # 3. Create .ssh directory for the new user
                sudo mkdir -p /home/deploy/.ssh
                
                # 4. Set strict permissions (700) on .ssh directory
                sudo chmod 400 /home/deploy/.ssh
                
                # 5. Set recursive ownership of the .ssh directory to the 'deploy' user
                sudo chown -R deploy:deploy /home/deploy/.ssh

                systemctl enable sshd
                systemctl start sshd
                
                # Add ec2-user to docker group (for easy access via standard SSH)
                sudo usermod -aG docker ec2-user
                
                EOF
            )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.web_app_name}-ec2-instance"
    }
  }
}

# ================================================================================
# AUTO SCALING GROUP (ASG) - High Availability Compute
# ================================================================================
resource "aws_autoscaling_group" "app" {
  desired_capacity    = var.asg_desired_capacity
  max_size            = var.asg_max_size
  min_size            = var.asg_min_size
 
  
  # Deploy instances across public subnets for load balancer access
  vpc_zone_identifier = aws_subnet.public[*].id
  
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  
  # Connect the ASG instances to both target groups
  target_group_arns = [aws_lb_target_group.tg_frontend.arn, aws_lb_target_group.tg_backend.arn]

  tag {
    key             = "Name"
    value           = "${var.web_app_name}-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ================================================================================
# SECRETS MANAGER (Updated Payload)
# ================================================================================
resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "${var.web_app_name}-rds-credentials"
  description             = "Master credentials for the RDS MySQL instance."
  recovery_window_in_days = 0 
  tags = {
    Name = "${var.web_app_name}-rds-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials_version" {
  secret_id     = aws_secretsmanager_secret.rds_credentials.id
  # Storing the credentials as JSON for easy parsing by the application later
  secret_string = jsonencode({
    # Using Master/Root credentials for consistency with your DB_USER/DB_PASSWORD
    username = var.rds_master_username
    password = var.rds_master_password
    database = "three_tier_web"
    engine   = "mysql" 
    host     = aws_db_instance.rds.address
    port     = aws_db_instance.rds.port
  })
  depends_on = [aws_db_instance.rds]

  lifecycle {
    # Prevent accidental deletion of secret versions
  }

}


# ================================================================================
# RDS MySQL 8.0 (Updated References)
# ================================================================================
resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "${var.web_app_name}-rds-subnet-group"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name = "${var.web_app_name}-rds-subnet-group"
  }
}

resource "aws_db_instance" "rds" {
  identifier              = "${var.web_app_name}-db-instance"
  allocated_storage       = var.rds_allocated_storage
  engine                  = "mysql"
  engine_version          = "8.0"   
  instance_class          = var.rds_instance_class
  
  # Set RDS Master Credentials using the new variables
  username                = var.rds_master_username
  password                = var.rds_master_password
  
  db_name                 = "three_tier_web" 
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = false 

  tags = {
    Name = "${var.web_app_name}-rds-instance"
  }
}