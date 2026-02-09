#Provider configuration
terraform {
  required_version = "1.14.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.28.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.6.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.0"
    }
  }
}
provider "aws" {
  region = var.aws_region2
  alias  = "us-east"
}
provider "aws" {
  region = var.aws_region
}
provider "aws" {
  region = var.aws_region
  alias  = "saopaulo"
}

terraform {
  backend "local" {
    path = "secrets/terraform.tfstate"
  }
}

#VPC Resource
resource "aws_vpc" "Star" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true


  tags = {
    Name = "star1"
  }
}


#Public Subnet in AZ1
resource "aws_subnet" "Star_Public_AZ1" {
  vpc_id                  = local.vpc_id
  cidr_block              = var.public_subnet_cidr1
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = var.public_subnet

  tags = {
    Name = "Star_Public_AZ1"
  }
}
resource "aws_subnet" "Star_Public_AZ2" {
  vpc_id                  = local.vpc_id
  cidr_block              = var.public_subnet_cidr2
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = var.public_subnet

  tags = {
    Name = "Star_Public_AZ2"
  }
}


#Private Subnet in AZ1
resource "aws_subnet" "Star_Private_AZ1" {
  vpc_id                  = local.vpc_id
  cidr_block              = var.private_subnet_cidr1
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = var.private_subnet

  tags = {
    Name = "Star_Private_AZ1"
  }
}
resource "aws_subnet" "Star_Private_AZ2" {
  vpc_id                  = local.vpc_id
  cidr_block              = var.private_subnet_cidr2
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = var.private_subnet

  tags = {
    Name = "Star_Private_AZ2"
  }
}


#Internet Gateway
resource "aws_internet_gateway" "internet" {
  vpc_id = local.vpc_id

  tags = {
    Name = "Star_IGW"
  }
}

#Route Tables
resource "aws_route_table" "Public" {
  vpc_id = local.vpc_id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet.id
  }

  tags = {
    Name = "Public_Route"
  }
}

resource "aws_route_table" "Private" {
  vpc_id = local.vpc_id
  route {
    cidr_block = aws_vpc.Star.cidr_block
    gateway_id = "local" # Change to S3 Gateway Endpoint later// No S3 Gateway Automatically creates it's routes
  }

  tags = {
    Name = "Private_Route"
  }
}

#Route table association
resource "aws_route_table_association" "Known" {
  for_each = {
    uno = aws_subnet.Star_Public_AZ1.id
    dos = aws_subnet.Star_Public_AZ2.id
  }
  subnet_id      = each.value
  route_table_id = aws_route_table.Public.id
}

resource "aws_route_table_association" "Secret" {
  for_each = {
    uno = aws_subnet.Star_Private_AZ1.id
    dos = aws_subnet.Star_Private_AZ2.id
  }
  subnet_id      = each.value
  route_table_id = aws_route_table.Private.id
}

resource "aws_security_group" "Endpoint_SG" {
  name        = "Endpoint_SG"
  description = "Endpoints traffic from 80,443"
  vpc_id      = local.vpc_id

  tags = {
    Name = "Endpoint_SG"
  }
}
resource "aws_security_group" "EC2_SG" {
  name        = "EC2_SG"
  description = "Allow TLS inbound traffic on HTTP and RDP and all outbound traffic"
  vpc_id      = local.vpc_id

  tags = {
    Name = "EC2_SG"
  }
}
resource "aws_security_group" "ALB" {
  name        = "ALB"
  description = "Allow TLS inbound traffic on HTTPS all outbound traffic"
  vpc_id      = local.vpc_id

  tags = {
    Name = "EC2_SG"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  for_each = {
    uno = aws_security_group.EC2_SG.id
    dos = aws_security_group.Endpoint_SG.id
    # tri = aws_security_group.ALB.id
  }
  security_group_id = each.value
  cidr_ipv4         = var.public_access_cidr
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  for_each = {
    uno = aws_security_group.EC2_SG.id
    dos = aws_security_group.Endpoint_SG.id
  }
  security_group_id = each.value
  cidr_ipv4         = var.public_access_cidr
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
resource "aws_vpc_security_group_ingress_rule" "allow_mysql_ipv4" {
  for_each = {
    uno = aws_security_group.EC2_SG.id
    #dos = aws_security_group.Endpoint_SG.id
  }
  security_group_id = each.value
  cidr_ipv4         = var.public_access_cidr
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}

resource "aws_vpc_security_group_egress_rule" "allow_all_egress_ipv4" {
  for_each = {
    uno = aws_security_group.EC2_SG.id
    dos = aws_security_group.Endpoint_SG.id
    tre = aws_security_group.ALB.id
  }
  security_group_id = each.value
  cidr_ipv4         = var.public_access_cidr
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#                                                      EC2 Blocks
#Identy and Access Management Role for EC2 to access RDS
#Private Instance Subnet
resource "aws_iam_role" "EC2_Role" {
  name = "EC2_Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}
#For the Public Instance to download Sessions Manager
resource "aws_iam_role" "EC2_Role2" {
  name = "EC2_Role2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}

# IF you want stronger Controls use this policy instead of SecretsManagerReadWrite
resource "aws_iam_policy" "secretsmanager_read_policy" {
  name        = "test_policy"
  path        = "/"
  description = "My test policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "ReadSpecificSecret",
        "Effect" : "Allow",
        "Action" : ["secretsmanager:GetSecretValue"],
        "Resource" : "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${var.secret_location}*" #Remember add a * or your policy will not work
      }
    ]
  })
}
resource "aws_iam_policy" "parameter_store_secrets" {
  name        = "${local.Environment}-lp-ssm-read01"
  description = "Least-privilege read for SSM Parameter Store under /lab/db/*"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadLabDbParams"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${var.parameter_location}**"
        ]
      }
    ]
  })
}
resource "aws_iam_policy" "cloudwatch_least_priviege" {
  name        = "${local.Environment}-lp-cwlogs01"
  description = "Least-privilege CloudWatch Logs write for the app log group"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.star-alb-log1[0].arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "example_attachment" {
  role = aws_iam_role.EC2_Role.name
  # Secrets Manager Read Access to allow access to RDS credentials
  policy_arn = aws_iam_policy.cloudwatch_least_priviege.arn
}
resource "aws_iam_role_policy_attachment" "example_attachment4" {
  role = aws_iam_role.EC2_Role.name
  # Secrets Manager Read Access to allow access to RDS credentials
  policy_arn = aws_iam_policy.secretsmanager_read_policy.arn
}
resource "aws_iam_role_policy_attachment" "example_attachment3" {
  role = aws_iam_role.EC2_Role.name
  # Secrets Manager Read Access to allow access to RDS credentials
  policy_arn = aws_iam_policy.parameter_store_secrets.arn
}
resource "aws_iam_role_policy_attachment" "example_attachment2" {
  role = aws_iam_role.EC2_Role.name
  # SSM Managed Instance Core to allow SSM Session Manager access
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "public-ssm" {
  role = aws_iam_role.EC2_Role2.name
  # SSM Managed Instance Core to allow SSM Session Manager access
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
#Associate the EC2 Instance with the Role to access the DB
#Solution to EC2-RDS profile already exist

resource "aws_iam_instance_profile" "this" {

  name = var.ec2_instance_profile_name
  role = aws_iam_role.EC2_Role.name
}
resource "aws_iam_instance_profile" "second" {

  name = var.ec2_instance_profile_name2
  role = aws_iam_role.EC2_Role2.name
}

#                                            EC2 Instances Public & Private

resource "aws_instance" "lab-ec2-app-public" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.Star_Public_AZ1.id
  security_groups             = [aws_security_group.EC2_SG.id]
  associate_public_ip_address = var.public_subnet
  user_data_base64            = base64encode(file("userdata.sh"))
  iam_instance_profile        = aws_iam_instance_profile.second.name
  # This is a new requirement for security that is coming up
  metadata_options {
    http_endpoint               = "enabled"  # Must be "enabled" to use IMDSv2
    http_tokens                 = "required" # Enforces the use of session tokens (IMDSv2)
    http_put_response_hop_limit = 1          # The hop limit for PUT requests
  }


  #You definately need SSMCore to install session manager on instance so I will create a second profile just for this. Hours lost to a small misconfiguration
  #Do not associate IAM Role, it is more secure this way


  tags = {
    Name = "lab-ec2-app"
  }
}

resource "time_sleep" "wait_for_ami_settle" {
  depends_on = [
    aws_instance.lab-ec2-app-public # or aws_ami, or aws_imagebuilder_image
  ]
  create_duration = "120s"
}
#Snapshot for Golden AMI Free Tier Eligible

resource "aws_ami_from_instance" "ec2_golden_ami" {
  name               = "ec2-golden-ami"
  source_instance_id = aws_instance.lab-ec2-app-public.id

  depends_on = [
    time_sleep.wait_for_ami_settle
  ]
}

#Use this data block to retrieve the AMI ID Once it's created instaed of calling the creation resource directly
data "aws_ami" "ec2_golden_ami" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["ec2-golden-ami"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
  depends_on = [aws_ami_from_instance.ec2_golden_ami]
}
#EC2 Instance in Private Subnet from Golden AMI Launch template
resource "aws_launch_template" "lab-ec2-app-private" {
  image_id               = data.aws_ami.ec2_golden_ami.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.EC2_SG.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.this.name #Use .name
  }
  update_default_version = true

  tags = {
    Name = "lab-ec2-app-private"
  }
}

#Placement Group for ASG
resource "aws_placement_group" "private" {
  name     = "test"
  strategy = "spread"
}
#Auto Scaling group for my instances
resource "aws_autoscaling_group" "bar" {
  name                      = "Autoscaler"
  max_size                  = 5
  min_size                  = 0
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 1
  force_delete              = true
  placement_group           = aws_placement_group.private.id

  launch_template {
    id      = aws_launch_template.lab-ec2-app-private.id
    version = "$Default"

  }

  target_group_arns = [
    aws_lb_target_group.hidden_target_group.arn
  ]

  vpc_zone_identifier = [aws_subnet.Star_Private_AZ1.id, aws_subnet.Star_Private_AZ2.id]

  instance_maintenance_policy {
    min_healthy_percentage = 90
    max_healthy_percentage = 120
  }
  depends_on = [data.aws_ami.ec2_golden_ami]
}

#Auto Scaling policy
resource "aws_autoscaling_policy" "cpu_utilization_target" {
  name                   = "cpu-utilization-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.bar.name
  policy_type            = "TargetTrackingScaling"

  estimated_instance_warmup = 300

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value     = 70.0
    disable_scale_in = false
  }
}



##################################################################
#               Section  B
##################################################################

#                                                                     Cloudwatch ALARM
#Cloudwatch Logs to watch database and EC2 for any failures and Alert me
resource "aws_sns_topic" "health_check_topic" {
  name = "ServiceHealthCheckTopic"
}
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.health_check_topic.arn
  protocol  = "email"
  # Replace with your email address
  endpoint = var.sns_email
  #Remember you have to confirm your subscription for this to work
}

# EC2 Alarms
resource "aws_cloudwatch_metric_alarm" "asg_instance_unhealthy" {
  alarm_name          = "/lab/${local.Environment}/ec2/health"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = 1

  metric_name        = "StatusCheckFailed"
  namespace          = "AWS/EC2"
  period             = 60
  statistic          = "Maximum"
  treat_missing_data = "breaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.bar.name
  }

  alarm_description = "Triggers when an EC2 instance fails system or instance status checks"
  alarm_actions     = [aws_sns_topic.health_check_topic.arn]
}

#S3 Gateway VPC Endpoint for S3 access within the VPC
resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.Private.id]

  tags = {
    Name = "S3-Gateway-Endpoint"
  }
}

# Cloudwatch Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id             = local.vpc_id
  service_name       = "com.amazonaws.${data.aws_region.current.region}.logs" # Use the specific service name for CloudWatch Logs
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.Star_Private_AZ1.id, aws_subnet.Star_Private_AZ2.id]
  security_group_ids = [aws_security_group.Endpoint_SG.id]

  # Enable private DNS names for the endpoint
  private_dns_enabled = true

  tags = {
    Name = "deathless-god-endpoint-cloudwatch-logs"
  }
}

#Secrets Manager VPC Endpoint
resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = local.vpc_id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${data.aws_region.current.region}.secretsmanager"
  subnet_ids          = [aws_subnet.Star_Private_AZ1.id, aws_subnet.Star_Private_AZ2.id]
  security_group_ids  = [aws_security_group.Endpoint_SG.id]
  private_dns_enabled = true

  tags = {
    Name = "SecretsManagerVPCEndpoint"
  }
}

#STS Endpoint, Theo doesn't mention it but this is necessary for EC2 to communicate with Secrets Manager
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = local.vpc_id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${data.aws_region.current.region}.sts"
  subnet_ids          = [aws_subnet.Star_Private_AZ1.id, aws_subnet.Star_Private_AZ2.id]
  security_group_ids  = [aws_security_group.Endpoint_SG.id]
  private_dns_enabled = true

  tags = {
    Name = "STSVPCEndpoint"
  }
}
# KMS Endpoint

# I am not using KMS for my key storage
# resource "aws_vpc_endpoint" "kms" {
#   vpc_id            = local.vpc_id
#   vpc_endpoint_type = "Interface"
#   service_name      = "com.amazonaws.${data.aws_region.current.region}.kms"
#   subnet_ids = [
#     aws_subnet.Star_Private_AZ1.id,
#     aws_subnet.Star_Private_AZ2.id
#   ]
#   security_group_ids  = [aws_security_group.Endpoint_SG.id]
#   private_dns_enabled = true

#   tags = {
#     Name = "KMS-VPCEndpoint"
#   }
# }

# EC2 Messages VPC Endpoint
resource "aws_vpc_endpoint" "ec2messages" {
  # The service name format is "com.amazonaws.<region>.ec2messages"
  service_name      = "com.amazonaws.${data.aws_region.current.region}.ec2messages"
  vpc_id            = local.vpc_id
  vpc_endpoint_type = "Interface"
  # Associate the endpoint with your private subnet IDs
  subnet_ids = [aws_subnet.Star_Private_AZ1.id, aws_subnet.Star_Private_AZ2.id]
  # Associate the dedicated security group
  security_group_ids = [aws_security_group.Endpoint_SG.id]
  # Enable private DNS names for seamless resolution within the VPC
  private_dns_enabled = true

  tags = {
    Name = "EC2Messages VPC Endpoint"
  }
}

# SSM VPC Endpoint
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.Endpoint_SG.id]
  subnet_ids          = [aws_subnet.Star_Private_AZ1.id, aws_subnet.Star_Private_AZ2.id]
  private_dns_enabled = true

  tags = {
    Name = "ssmmessages-endpoint"
  }
}
resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = local.vpc_id
  service_name       = "com.amazonaws.${data.aws_region.current.region}.ssm"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.Endpoint_SG.id]
  subnet_ids = [
    aws_subnet.Star_Private_AZ1.id,
    aws_subnet.Star_Private_AZ2.id
  ]
  private_dns_enabled = true

  tags = {
    Name = "ssm-endpoint"
  }
}

#####################################################################
#                         Section 1C
#####################################################################

#s3 Bucket
resource "aws_s3_bucket" "spire" {
  bucket        = "aws-alb-logs-${data.aws_region.current.region}-${local.Environment}-${data.aws_caller_identity.current.account_id}"
  region        = data.aws_region.current.region
  force_destroy = true # Auto-delete objects on terraform destroy

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

#                            ELITE TIP: USE AWS POLICY GENERATOR SAVES SUFFERING
#S3 Bucket to store ALB logs
resource "aws_s3_bucket_policy" "lb_bucket_policy" {
  bucket = aws_s3_bucket.spire.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Deny insecure transport (TLS-only)
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.spire.id}",
          "arn:aws:s3:::${aws_s3_bucket.spire.id}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      # REQUIRED: ALB access logs - uses regional ELB service account
      {
        Sid    = "AllowELBLogDelivery"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.spire.id}/${var.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      # ALB access logs via service principal (recommended for newer regions)
      {
        Sid    = "AllowELBPutObject"
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.spire.id}/${var.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      }
    ]
  })
}
# Use if terraform doesn't return an identifier
# import {
#   to = aws_lb.hidden_alb
#   id = "arn:aws:elasticloadbalancing:sa-east-1:814910273374:loadbalancer/app/LoadExternal/d990e1ab7e539256"
# }

resource "aws_lb" "hidden_alb" {
  name               = "LoadExternal"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ALB.id]

  subnets = [
    aws_subnet.Star_Public_AZ1.id,
    aws_subnet.Star_Public_AZ2.id,
  ]
  access_logs {
    bucket  = aws_s3_bucket.spire.id
    prefix  = var.alb_access_logs_prefix
    enabled = true
  }
  tags = {
    Name = "App1LoadBalancer"
  }
}

#                                      DOMAIN NAME : ROUTE 53
#############################################################################################
#Target Group for Load Balancer

resource "aws_lb_target_group" "hidden_target_group" {
  name     = "hidden-target-group"
  port     = 80 # You forgot the Port here
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200-399"
  }

  tags = {
    Name = "Target Group for hidden target_group"
  }
}
#                                   Listeners for TARGET GROUP

import {
  to = aws_route53domains_registered_domain.unshieldedhollow
  id = "armageddonlab.com" # Your domain here
}


resource "aws_route53_zone" "primary" {
  name = var.root_domain_name
}
resource "aws_route53domains_registered_domain" "unshieldedhollow" {
  domain_name = var.root_domain_name

  name_server {
    name = aws_route53_zone.primary.name_servers[0]
  }
  name_server {
    name = aws_route53_zone.primary.name_servers[1]
  }
  name_server {
    name = aws_route53_zone.primary.name_servers[2]
  }
  name_server {
    name = aws_route53_zone.primary.name_servers[3]
  }
}
# This is the Route 53 record creation for ALB so Cloudfront can work
resource "aws_route53_record" "Alb_zone" {
  count   = var.enable_cloudfront ? 1 : 0
  zone_id = aws_route53_zone.primary.zone_id
  name    = "${var.alb_domain_name}.${var.root_domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.hidden_alb.dns_name
    zone_id                = aws_lb.hidden_alb.zone_id
    evaluate_target_health = false
  }
  depends_on = [ aws_acm_certificate.cloudfront_cert ]
}
resource "aws_acm_certificate" "hidden_target_group2" {
  domain_name       = "${var.alb_domain_name}.${var.root_domain_name}"
  validation_method = "DNS"

  tags = {
    Name = "hidden target_group certificate"
  }
}
resource "aws_route53_record" "cert_validation" {
  for_each = (
    var.certificate_validation_method == "DNS" &&
    length(aws_acm_certificate.hidden_target_group2.domain_validation_options) > 0
  ) ? {
    for dvo in aws_acm_certificate.hidden_target_group2.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_acm_certificate_validation" "star_cert_validation1" {
  count                   = var.certificate_validation_method == "DNS" ? 1 : 0
  certificate_arn         = aws_acm_certificate.hidden_target_group2.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.hidden_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.hidden_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.hidden_target_group2.arn



  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hidden_target_group.arn
  }
#  depends_on = [aws_acm_certificate_validation.star_cert_validation1]
}

resource "aws_autoscaling_attachment" "load_asg" {
  autoscaling_group_name = aws_autoscaling_group.bar.id
  lb_target_group_arn    = aws_lb_target_group.hidden_target_group.arn
}


# resource "aws_wafv2_web_acl_association" "chewbacca_waf_assoc01" {
#   count = var.enable_waf ? 1 : 0

#   resource_arn = aws_cloudfront_distribution.main[0].arn
#   web_acl_arn  = aws_wafv2_web_acl.alb_waf[0].arn
# }

############################################
# CloudWatch Alarm: ALB 5xx -> SNS
############################################
resource "aws_cloudwatch_metric_alarm" "chewbacca_alb_5xx_alarm01" {
  alarm_name          = "${local.Environment}-alb-5xx-alarm01"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alb_5xx_evaluation_periods
  threshold           = var.alb_5xx_threshold
  period              = var.alb_5xx_period_seconds
  statistic           = "Sum"

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_ELB_5XX_Count"

  dimensions = {
    LoadBalancer = aws_lb.hidden_alb.arn_suffix
  }

  alarm_actions = [aws_sns_topic.health_check_topic.arn]

  tags = {
    Name = "${local.Environment}-alb-5xx-alarm01"
  }
}

############################################
# CloudWatch Dashboard (Skeleton)
############################################

# Explanation: Dashboards are your cockpit HUD — Chewbacca wants dials, not vibes.
resource "aws_cloudwatch_dashboard" "chewbacca_dashboard01" {
  dashboard_name = "${local.Environment}-dashboard01"

  # TODO: students can expand widgets; this is a minimal workable skeleton
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.hidden_alb.arn_suffix],
            [".", "HTTPCode_ELB_5XX_Count", ".", aws_lb.hidden_alb.arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.region
          title  = "Chewbacca ALB: Requests + 5XX"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.hidden_alb.arn_suffix]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.region
          title  = "Chewbacca ALB: Target Response Time"
        }
      }
    ]
  })
}
##############################################################################################################################################################################################################
# Explanation: The zone apex is the throne room—chewbacca-growl.com itself should lead to the ALB.


############################################
# S3 bucket for ALB access logs
############################################

# Explanation: Block public access—Chewbacca does not publish the ship’s black box to the galaxy.
resource "aws_s3_bucket_public_access_block" "chewbacca_alb_logs_pab01" {
  count = var.s3_bucket_no_access ? 1 : 0

  bucket                  = aws_s3_bucket.spire.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Explanation: Bucket ownership controls prevent log delivery chaos—Chewbacca likes clean chain-of-custody.
resource "aws_s3_bucket_ownership_controls" "alb_logs_owner01" {
  count = var.s3_bucket_no_access ? 1 : 0

  bucket = aws_s3_bucket.spire.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Explanation: TLS-only—Chewbacca growls at plaintext and throws it out an airlock.
resource "aws_s3_bucket_policy" "alb_logs_policy01" {
  count = var.s3_bucket_no_access ? 1 : 0

  bucket = aws_s3_bucket.spire.id

  # NOTE: This is a skeleton. Students may need to adjust for region/account specifics.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.spire.arn,
          "${aws_s3_bucket.spire.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid    = "AllowELBPutObject"
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.spire.arn}/${var.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      }
    ]
  })
}


#####################################################################################################################
#                                           WAF Log Group
#####################################################################################################################

resource "aws_cloudwatch_log_group" "star-alb-log1" {
  count = var.waf_log_destination == "cloudwatch" ? 1 : 0
  provider = aws.us-east

  # NOTE: AWS requires WAF log destination names start with aws-waf-logs- (students must not rename this).
  name              = "aws-waf-logs-${local.Environment}-webacl01"
  retention_in_days = var.waf_log_retention_days

  tags = {
    Name = "${local.Environment}-waf-log-group01"
  }
}

# Explanation: This wire connects the shield generator to the black box—WAF -> CloudWatch Logs.
resource "aws_wafv2_web_acl_logging_configuration" "chewbacca_waf_logging01" {
  count = var.enable_waf && var.waf_log_destination == "cloudwatch" ? 1 : 0
  provider =aws.us-east

  resource_arn = aws_wafv2_web_acl.alb_waf[0].arn
  log_destination_configs = [
    aws_cloudwatch_log_group.star-alb-log1[0].arn
  ]

  # TODO: Students can add redacted_fields (authorization headers, cookies, etc.) as a stretch goal.
  # redacted_fields { ... }

  depends_on = [aws_wafv2_web_acl.alb_waf[0]]
}

############################################
# Option 2: S3 destination (direct)
############################################

# Explanation: S3 WAF logs are the long-term archive—Chewbacca likes receipts that survive dashboards.
resource "aws_s3_bucket" "star_waf_bucket_uno" {
  count = var.waf_log_dest == "s3" ? 1 : 0

  bucket        = "aws-waf-logs-${data.aws_region.current.region}-${local.Environment}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # Auto-delete objects on terraform destroy

  tags = {
    Name = "${local.Environment}-waf-logs-bucket01"
  }
}

# Explanation: Public access blocked—WAF logs are not a bedtime story for the entire internet.
resource "aws_s3_bucket_public_access_block" "chewbacca_waf_logs_pab01" {
  count = var.waf_log_dest == "s3" ? 1 : 0

  bucket                  = aws_s3_bucket.star_waf_bucket_uno[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

# Explanation: Connect shield generator to archive vault—WAF -> S3.
resource "aws_wafv2_web_acl_logging_configuration" "chewbacca_waf_logging_s3_01" {
  count = var.enable_waf && var.waf_log_dest == "s3" ? 1 : 0
  provider = aws.us-east
  resource_arn = aws_wafv2_web_acl.alb_waf[0].arn
  log_destination_configs = [
    aws_s3_bucket.star_waf_bucket_uno[0].arn
  ]

  depends_on = [aws_wafv2_web_acl.alb_waf]#, aws_wafv2_web_acl_logging_configuration.chewbacca_waf_logging01]
}

############################################
# Option 3: Firehose destination (classic “stream then store”)
############################################

# Explanation: Firehose is the conveyor belt—WAF logs ride it to storage (and can fork to SIEM later).
resource "aws_s3_bucket" "star_firehouse_waf_log" {
  count = var.firehose_log == "firehose" ? 1 : 0

  bucket        = "${data.aws_region.current.region}-${local.Environment}-waf-firehose-dest-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # Auto-delete objects on terraform destroy

  tags = {
    Name = "${local.Environment}-waf-firehose-dest-bucket01"
  }
}

# Explanation: Firehose needs a role—Chewbacca doesn’t let random droids write into storage.
resource "aws_iam_role" "star_fire_hose1" {
  count = var.firehose_log == "firehose" ? 1 : 0
  name  = "${local.Environment}-firehose-role01"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Explanation: Minimal permissions—allow Firehose to put objects into the destination bucket.
resource "aws_iam_role_policy" "chewbacca_firehose_policy01" {
  count = var.firehose_log == "firehose" ? 1 : 0
  name  = "${local.Environment}-firehose-policy01"
  role  = aws_iam_role.star_fire_hose1[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.star_firehouse_waf_log[0].arn,
          "${aws_s3_bucket.star_firehouse_waf_log[0].arn}/*"
        ]
      }
    ]
  })
}

# Explanation: The delivery stream is the belt itself—logs move from WAF -> Firehose -> S3.
resource "aws_kinesis_firehose_delivery_stream" "Star_Firehose_delivery1" {
  count       = var.firehose_log == "firehose" ? 1 : 0
  provider = aws.us-east
  name        = "aws-waf-logs-${local.Environment}-firehose01"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.star_fire_hose1[0].arn
    bucket_arn = aws_s3_bucket.star_firehouse_waf_log[0].arn
    prefix     = "waf-logs/"
  }
}

# Explanation: Connect shield generator to conveyor belt—WAF -> Firehose stream.
resource "aws_wafv2_web_acl_logging_configuration" "chewbacca_waf_logging_firehose01" {
  count = var.enable_waf && var.firehose_log == "firehose" ? 1 : 0
  provider = aws.us-east
  resource_arn = aws_wafv2_web_acl.alb_waf[0].arn
  log_destination_configs = [
    aws_kinesis_firehose_delivery_stream.Star_Firehose_delivery1[0].arn
  ]

  depends_on = [aws_wafv2_web_acl.alb_waf, aws_wafv2_web_acl_logging_configuration.chewbacca_waf_logging_s3_01]
}

#####################################################################################################################
#                                           LAB 2: CloudFront CDN with Origin Cloaking
#####################################################################################################################

#                                           Variables for CloudFront
variable "app_subdomain" {
  description = "Subdomain for the app (e.g., 'app' for app.domain.com)"
  type        = string
  default     = "app"
}

#                                           CloudFront ACM Certificate (must be in us-east-1)
# Note: CloudFront requires certificates in us-east-1 (provider alias defined in 1a.tf)

resource "aws_acm_certificate" "cloudfront_cert" {
  count    = var.enable_cloudfront ? 1 : 0
  provider = aws.us-east

  domain_name               = var.root_domain_name
  subject_alternative_names = ["*.${var.root_domain_name}"]
  validation_method         = "DNS"

  tags = {
    Name = "${var.Environment}-cloudfront-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}
# We only need 1 of these
resource "aws_route53_record" "cloudfront_cert_validation" {
  for_each = var.enable_cloudfront ? {
    for dvo in aws_acm_certificate.cloudfront_cert[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cloudfront_cert_validation" {
  count    = var.enable_cloudfront ? 1 : 0
  provider = aws.us-east

  certificate_arn         = aws_acm_certificate.cloudfront_cert[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cloudfront_cert_validation : r.fqdn]
}

#####################################################################################################################
#                                           Origin Cloaking - Secret Header
#####################################################################################################################

# Secret header value for origin cloaking - CloudFront sends this, ALB validates it
resource "random_password" "origin_header_secret" {
  count   = var.enable_cloudfront ? 1 : 0
  length  = 32
  special = false
}

#####################################################################################################################
#                                           Origin Cloaking - Security Group Rules
#####################################################################################################################

# CloudFront origin-facing prefix list for restricting ALB access
data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  count = var.enable_cloudfront ? 1 : 0
  name  = "com.amazonaws.global.cloudfront.origin-facing"
}

# Allow only CloudFront IPs to reach ALB on port 443
resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront_443" {
  count             = var.enable_cloudfront ? 1 : 0
  security_group_id = aws_security_group.ALB.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_origin_facing[0].id

  description = "Allow HTTPS from CloudFront only"
}

#####################################################################################################################
#                                           Origin Cloaking - ALB Listener Rules
#####################################################################################################################

# Forward requests with valid secret header
resource "aws_lb_listener_rule" "require_origin_header" {
  count        = var.enable_cloudfront ? 1 : 0
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hidden_target_group.arn
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [random_password.origin_header_secret[0].result]
    }
  }
}

# Block all requests without the secret header (lower priority = evaluated last)
resource "aws_lb_listener_rule" "block_direct_access" {
  count        = var.enable_cloudfront ? 1 : 0
  listener_arn = aws_lb_listener.https.arn
  priority     = 99

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden - Direct access not allowed"
      status_code  = "403"
    }
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}

#####################################################################################################################
#                                           CloudFront Cache Policies
#####################################################################################################################

# Aggressive caching for static content
resource "aws_cloudfront_cache_policy" "static_cache" {
  count   = var.enable_cloudfront ? 1 : 0
  name    = "${var.Environment}-cache-static"
  comment = "Aggressive caching for static assets"

  default_ttl = 86400    # 1 day
  max_ttl     = 31536000 # 1 year
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

# No caching for API endpoints (safe default)
resource "aws_cloudfront_cache_policy" "api_no_cache" {
  count   = var.enable_cloudfront ? 1 : 0
  name    = "${var.Environment}-cache-api-disabled"
  comment = "Disable caching for API endpoints"

  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    enable_accept_encoding_gzip   = false
    enable_accept_encoding_brotli = false
  }
}

#####################################################################################################################
#                                           CloudFront Origin Request Policies
#####################################################################################################################

# Forward necessary values for API calls
resource "aws_cloudfront_origin_request_policy" "api_origin" {
  count   = var.enable_cloudfront ? 1 : 0
  name    = "${var.Environment}-orp-api"
  comment = "Forward necessary values for API calls"

  cookies_config {
    cookie_behavior = "all"
  }
  query_strings_config {
    query_string_behavior = "all"
  }
  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["Content-Type", "Origin", "Host", "Accept"]
    }
  }
}

# Minimal forwarding for static assets
resource "aws_cloudfront_origin_request_policy" "static_origin" {
  count   = var.enable_cloudfront ? 1 : 0
  name    = "${var.Environment}-orp-static"
  comment = "Minimal forwarding for static assets"

  cookies_config {
    cookie_behavior = "none"
  }
  query_strings_config {
    query_string_behavior = "none"
  }
  headers_config {
    header_behavior = "none"
  }
}

#####################################################################################################################
#                                           CloudFront Response Headers Policy
#####################################################################################################################

resource "aws_cloudfront_response_headers_policy" "static_headers" {
  count   = var.enable_cloudfront ? 1 : 0
  name    = "${var.Environment}-rsp-static"
  comment = "Add Cache-Control for static content"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      override = true
      value    = "public, max-age=86400, immutable"
    }
  }
}

#####################################################################################################################
#                                           CloudFront WAF (CLOUDFRONT scope)
#####################################################################################################################

resource "aws_wafv2_web_acl" "alb_waf" {
  count    = var.enable_cloudfront ? 1 : 0
  provider = aws.us-east

  name  = "${var.Environment}-cloudfront-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.Environment}-cloudfront-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.Environment}-cf-waf-common"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name = "${var.Environment}-cloudfront-waf"
  }
}

#####################################################################################################################
#                                           CloudFront Distribution
#####################################################################################################################

resource "aws_cloudfront_distribution" "main" {
  count = var.enable_cloudfront ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.Environment}-cloudfront-distribution"
#  default_root_object = "index.html"         This Broke Everything, Know alot about this before using it.
  price_class         = "PriceClass_100" # Use only North America and Europe

  # ALB Origin with secret header for origin cloaking
  origin {
    origin_id   = "${var.Environment}-alb-origin"
    domain_name = "${var.alb_domain_name}.${var.root_domain_name}"


    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Secret header for origin verification
    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.origin_header_secret[0].result
    }
  }

  # Default behavior (API/dynamic content - no caching)
  default_cache_behavior {
    target_origin_id       = "${var.Environment}-alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = aws_cloudfront_cache_policy.api_no_cache[0].id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.api_origin[0].id

    compress = true
  }

  # Static content behavior (aggressive caching)
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "${var.Environment}-alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id            = aws_cloudfront_cache_policy.static_cache[0].id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.static_origin[0].id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.static_headers[0].id

    compress = true
  }

  # Attach CloudFront WAF
  web_acl_id = aws_wafv2_web_acl.alb_waf[0].arn

  # Domain aliases
  aliases = [
    var.root_domain_name,
    "www.${var.root_domain_name}",
    "${var.app_subdomain}.${var.root_domain_name}"
  ]

  # SSL Certificate (must be in us-east-1)
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudfront_cert[0].arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "${var.Environment}-cloudfront"
  }

  depends_on = [aws_acm_certificate_validation.cloudfront_cert_validation]
}

#####################################################################################################################
#                                           Route53 Records - Point to CloudFront
#####################################################################################################################

# Apex domain points to CloudFront (when enabled)
resource "aws_route53_record" "apex_to_cloudfront" {
  count   = var.enable_cloudfront ? 1 : 0
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.root_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main[0].domain_name
    zone_id                = aws_cloudfront_distribution.main[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# www subdomain points to CloudFront (when enabled)
resource "aws_route53_record" "www_to_cloudfront" {
  count   = var.enable_cloudfront ? 1 : 0
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.root_domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main[0].domain_name
    zone_id                = aws_cloudfront_distribution.main[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# App subdomain points to CloudFront
resource "aws_route53_record" "app_to_cloudfront" {
  count   = var.enable_cloudfront ? 1 : 0
  zone_id = aws_route53_zone.primary.zone_id
  name    = "${var.app_subdomain}.${var.root_domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main[0].domain_name
    zone_id                = aws_cloudfront_distribution.main[0].hosted_zone_id
    evaluate_target_health = false
  }
}
# Note: Origin secret for CloudFront is now managed in 2_cloudfront.tf
# using random_password.origin_header_secret resource.
# This file previously contained duplicate secret resources that have been removed.

# Store the secret in Secrets Manager (uses the secret from 2_cloudfront.tf when CloudFront is enabled)
resource "aws_secretsmanager_secret" "origin_verify" {
  count                   = var.enable_cloudfront ? 1 : 0
  name                    = "cloudfront/2${var.secret_location}"
  description             = "Secret header for CloudFront origin verification"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "origin_verify" {
  count         = var.enable_cloudfront ? 1 : 0
  secret_id     = aws_secretsmanager_secret.origin_verify[0].id
  secret_string = random_password.origin_header_secret[0].result
}
#####################################################################################################################
#                                           Outputs
#####################################################################################################################

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].id : null
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.main[0].domain_name : null
}



#########################################################################
#                       Transit Gateways
#########################################################################

# locals {
#   japan_cidr_range = "10.100.0.0/16" # Set it to the other region Cidr
# }
data "aws_vpc" "Tokyo" {
  count  = var.transit_peering_enabled ? 1 : 0
  region = "ap-northeast-1"
  tags = {
    Name = "star"
  }
}


#             Flip This to true when the necessary parts are created
variable "transit_peering_enabled" {
  description = "Enable when the other transit gateway is created"
  type        = bool
  default     = false
}
# Explanation: Liberdade is São Paulo’s Japanese town—local doctors, local compute, remote data.
resource "aws_ec2_transit_gateway" "liberdade_tgw01" {
  provider    = aws.saopaulo
  description = "liberdade-tgw01 (Sao Paulo spoke)"
  default_route_table_association  = "disable"
  default_route_table_propagation  = "disable"

  tags = {
  Name = "liberdade-tgw01" }
}

data "aws_ec2_transit_gateway_peering_attachment" "attachment" {
  count  = var.transit_peering_enabled ? 1 : 0
  region = "ap-northeast-1"
  tags = {
  Name = "shinjuku-to-liberdade-peer01" }
}
# Explanation: Liberdade knows the way to Shinjuku—Tokyo CIDR routes go through the TGW corridor.




# Explanation: Liberdade accepts the corridor from Shinjuku—permissions are explicit, not assumed.
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "liberdade_accept_peer01" {
  count                         = var.transit_peering_enabled ? 1 : 0
  provider                      = aws.saopaulo
  transit_gateway_attachment_id = data.aws_ec2_transit_gateway_peering_attachment.attachment[0].id

  tags = {
  Name = "liberdade-accept-peer01" }

}

# Explanation: Liberdade attaches to its VPC—compute can now reach Tokyo legally, through the controlled corridor.
resource "aws_ec2_transit_gateway_vpc_attachment" "liberdade_attach_sp_vpc01" {
  provider           = aws.saopaulo
  transit_gateway_id = aws_ec2_transit_gateway.liberdade_tgw01.id
  vpc_id             = aws_vpc.Star.id
  subnet_ids         = [aws_subnet.Star_Private_AZ1.id, aws_subnet.Star_Private_AZ2.id]
  appliance_mode_support = "enable"
  dns_support            = "enable"

  tags = {
  Name = "liberdade-attach-sp-vpc01" }
}
#  Route Table Creation
resource "aws_ec2_transit_gateway_route_table" "rt_a" {
  transit_gateway_id = aws_ec2_transit_gateway.liberdade_tgw01.id
  tags = {
    Name = "tgw-rt-b"
  }
}


# Transit Gateway Asoociation
resource "aws_ec2_transit_gateway_route_table_association" "vpc_assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.liberdade_attach_sp_vpc01.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_a.id

}
# Route Propagation from transit gateway to route tables in the vpc
resource "aws_ec2_transit_gateway_route_table_propagation" "vpc_prop" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.liberdade_attach_sp_vpc01.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_a.id

}

#                 Transit Gateway Route table entry for local Cidr 


resource "aws_ec2_transit_gateway_route" "to_region_b_vpc1" {
  count                          = var.transit_peering_enabled ? 1 : 0
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_a.id
  destination_cidr_block         = aws_vpc.Star.cidr_block

  # IMPORTANT: Use the peering attachment ID (requester resource ID is fine)
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.liberdade_attach_sp_vpc01.id

  # Ensure the accepter exists before routes are attempted
}

# Route Table creation for transit gateway to route traffic from other vpc using it's Cidr for TGW communication
resource "aws_ec2_transit_gateway_route" "to_region_b_vpc" {
  count                          = var.transit_peering_enabled ? 1 : 0
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_a.id
  destination_cidr_block         = data.aws_vpc.Tokyo[0].cidr_block

  # IMPORTANT: Use the peering attachment ID (requester resource ID is fine)
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment_accepter.liberdade_accept_peer01[0].id

  # Ensure the accepter exists before routes are attempted
}
##################################################################################
#########                  LAST STEP:ACTIVATE THIS AFTER EVERYTHING ELSE IS DONE
##################################################################################
variable "transit-peering-route" {
  description = "Enable routing assocation to the peering transit gateway"
  type        = bool
  default     = false
}

# Run terraform apply for this to be added after you active the above variable
resource "aws_ec2_transit_gateway_route_table_association" "vpc_assoc2" {
  count                          = var.transit-peering-route ? 1 : 0
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.liberdade_accept_peer01[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_a.id

}

# Run terraform apply again for this route to get added to the route table, It is a fault of terraform and there isn't much that can be done
resource "aws_route" "liberdade_to_tokyo_route01" {
  count                  = var.transit_peering_enabled ? 1 : 0
  provider               = aws.saopaulo
  route_table_id         = aws_route_table.Private.id
  destination_cidr_block = data.aws_vpc.Tokyo[0].cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.liberdade_tgw01.id

}