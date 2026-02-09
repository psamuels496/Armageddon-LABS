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
  region = var.aws_region
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
    Name = "star"
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

#                                   Route Tables
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

#                                     Route table association
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

#                                       Security Groups
resource "aws_security_group" "RDS_SG" {
  name        = "RDS_SG"
  description = "Allow TLS inbound traffic from EC2_SG and outbound traffic to EC2_SG"
  vpc_id      = local.vpc_id

  tags = {
    Name = "RDS_SG"
  }
}
resource "aws_security_group" "Endpoint_SG" {
  name        = "Endpoint_SG"
  description = "Endpoints traffic from 80,443"
  vpc_id      = local.vpc_id

  tags = {
    Name = "Endpoint_SG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  for_each = {
    dos = aws_security_group.Endpoint_SG.id
  }
  security_group_id = each.value
  cidr_ipv4         = var.public_access_cidr
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  for_each = {
    dos = aws_security_group.Endpoint_SG.id
  }
  security_group_id = each.value
  cidr_ipv4         = var.public_access_cidr
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
resource "aws_vpc_security_group_ingress_rule" "RDS_EC2_SG" {
  count             = var.transit_peering_enabled ? 1 : 0
  security_group_id = aws_security_group.RDS_SG.id
  cidr_ipv4         = data.aws_vpc.foo[0].cidr_block
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}
resource "aws_vpc_security_group_ingress_rule" "allow_mysql_ipv4" {
  for_each = {
    dos = aws_security_group.Endpoint_SG.id
  }
  security_group_id = each.value
  cidr_ipv4         = var.public_access_cidr
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}

resource "aws_vpc_security_group_egress_rule" "allow_all_egress_ipv4" {
  for_each = {
    uno = aws_security_group.RDS_SG.id
    dos = aws_security_group.Endpoint_SG.id
  }
  security_group_id = each.value
  cidr_ipv4         = var.public_access_cidr
  ip_protocol       = "-1" # semantically equivalent to all ports
}



#                                       The Big Boy, RDS MySQL Instance
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.Star_Private_AZ1.id, aws_subnet.Star_Private_AZ2.id]

  tags = {
    Name = "My DB subnet group"
  }
}
resource "aws_db_instance" "below_the_valley" {
  allocated_storage               = 10
  db_name                         = "labdb"
  engine                          = "mysql"
  engine_version                  = "8.0.43"
  instance_class                  = "db.t3.micro"
  username                        = var.db_username
  password                        = random_password.master.result
  parameter_group_name            = "default.mysql8.0"
  skip_final_snapshot             = true
  vpc_security_group_ids          = [aws_security_group.RDS_SG.id]
  db_subnet_group_name            = aws_db_subnet_group.my_db_subnet_group.name
  enabled_cloudwatch_logs_exports = ["error"]

  tags = {
    Name      = "My_RDS_Instance"
    terraname = "aws_db_instance.below_the_valley"
  }
}
#                           Secrets Manager

#Secret Manager to store RDS Credentials
resource "random_password" "master" {
  length           = 16
  special          = true
  override_special = "_!%^"
}
resource "aws_secretsmanager_secret" "password" {
  name        = var.secret_location
  description = "RDS MySQL credentials for EC2 app"
  replica {
    # This replicates secret across regions
    region = var.second_aws_region
  }
}
resource "aws_secretsmanager_secret_version" "passwords" {
  secret_id = aws_secretsmanager_secret.password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.master.result
    port     = 3306
    host     = aws_db_instance.below_the_valley.address # Modification mistake cost me 6 hours of troubleshooting(Crazy Time Consumer)
    db_name  = aws_db_instance.below_the_valley.db_name
  })


}

#######################################################################################
#                         Section 1B
#######################################################################################
#                             SSM Paramter Store
# I don't need this and this service is expensive for a single consumer
# resource "aws_ssm_parameter" "port" {
#   name        = "${var.parameter_location}port"
#   description = "This is the RDS port"
#   type        = "SecureString"
#   value       = 3306
#   tags = {
#     environment = "production"
#   }
# }
# resource "aws_ssm_parameter" "host" {
#   name        = "${var.parameter_location}host"
#   description = "This is the endpoint to the RDS instance"
#   type        = "SecureString"
#   value       = aws_db_instance.below_the_valley.address
#   tags = {
#     environment = "production"
#   }
# }
# resource "aws_ssm_parameter" "db_name" {
#   name        = "${var.parameter_location}db_name"
#   description = "This is the name of the database within the RDS instance"
#   type        = "SecureString"
#   value       = aws_db_instance.below_the_valley.db_name
#   tags = {
#     environment = "production"
#   }
# }
#                                             Simple Notification Service
resource "aws_sns_topic" "health_check_topic" {
  name = "ServiceHealthCheckTopic"
}
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.health_check_topic.arn
  protocol  = "email"
  endpoint  = var.sns_email # Replace with your email address by changing the variable sns_email
  #Remember you have to confirm your subscription for this to work
}

#                                 Cloud Watch Alarms

# Cloudwatch Log Group
resource "aws_cloudwatch_log_group" "db_logs" {
  name              = "rds/${aws_db_instance.below_the_valley.id}/error"
  retention_in_days = var.cloudwatch_log_retention_days
}
resource "aws_cloudwatch_log_metric_filter" "connection_failure_filter" {
  name           = "DBConnectionFailureFilter"
  log_group_name = aws_cloudwatch_log_group.db_logs.name
  pattern        = "?ERROR ?FATAL ?CRITICAL ?Connection ?failed"
  # Adjust pattern based on exact error messages in your specific DB engine logs

  metric_transformation {
    name      = "DBConnectionFailureCount"
    namespace = "Custom/RDS"
    value     = "1"
  }
}

#   RDS Alarms
resource "aws_cloudwatch_metric_alarm" "below_the_valley_db_alarm01" {
  alarm_name          = "${local.name_prefix}-db-connection-failure"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "DBConnectionErrors"
  namespace           = "Lab/RDSApp"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_actions       = [aws_sns_topic.health_check_topic.arn]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.below_the_valley.identifier
  }
  tags = {
    Name = "${local.name_prefix}-alarm-db-fail"
  }

  depends_on = [aws_db_instance.below_the_valley]
}

#My Custom Metric for Cloudwatch Database logs
resource "aws_cloudwatch_metric_alarm" "connection_failure_alarm" {
  alarm_name          = "High-DB-Connection-Failure-Rate"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.connection_failure_filter.metric_transformation[0].name
  namespace           = "AWS/RDS"
  period              = 60 # Check every 60 seconds
  statistic           = "Average"
  threshold           = 3 # Trigger if 3 or more failures in the period
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.below_the_valley.identifier
  }
  alarm_description = "The following ${local.terradbname} RDS server is running into connection issues. Check to see what the problem is and if you cannont remedy it, replace it. Replace it in terraform by running -terraform apply -replace ${local.terradbname} (If you have access to the terraform this is the remedy) "
  alarm_actions     = [aws_sns_topic.health_check_topic.arn]

  depends_on = [aws_db_instance.below_the_valley]
}

#This tracks for when the CPU utilization is below 1 percent for more than 5 minutes which means the server is not running
resource "aws_cloudwatch_metric_alarm" "rds-CPUUtilization" {
  alarm_name          = "rds-CPUUtilization"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 5
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60 #Requirements is 5 minutes, so 300 seconds(50s X 2 periods = 100s x3 thresholds = 300s)
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.below_the_valley.identifier
  }
  alarm_description = "The following ${local.terradbname} RDS is not running because a running server CPU utilization  doesn't go lower than one. Check to see what the problem is and if you cannont remedy it, replace it. Replace it in terraform by running -terraform apply -replace ${local.terradbname} (If you have access to the terraform this is the remedy) "
  alarm_actions     = [aws_sns_topic.health_check_topic.arn]

  depends_on = [aws_db_instance.below_the_valley]
}


#                                             VPC Endpoints

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
    Name = "endpoint-cloudwatch-logs"
  }
}
# This stuff is expensive and unnecessary
#Secrets Manager VPC Endpoint
# resource "aws_vpc_endpoint" "secrets_manager" {
#   vpc_id              = local.vpc_id
#   vpc_endpoint_type   = "Interface"
#   service_name        = "com.amazonaws.${data.aws_region.current.region}.secretsmanager"
#   subnet_ids          = [aws_subnet.Star_Private_AZ1.id, aws_subnet.Star_Private_AZ2.id]
#   security_group_ids  = [aws_security_group.Endpoint_SG.id]
#   private_dns_enabled = true

#   tags = {
#     Name = "SecretsManagerVPCEndpoint"
#   }
# }

#STS Endpoint, Theo doesn't mention it but this is necessary for EC2 to communicate with Secrets Manager
# resource "aws_vpc_endpoint" "sts" {
#   vpc_id              = local.vpc_id
#   vpc_endpoint_type   = "Interface"
#   service_name        = "com.amazonaws.${data.aws_region.current.region}.sts"
#   subnet_ids          = [aws_subnet.Star_Private_AZ1.id, aws_subnet.Star_Private_AZ2.id]
#   security_group_ids  = [aws_security_group.Endpoint_SG.id]
#   private_dns_enabled = true

#   tags = {
#     Name = "STSVPCEndpoint"
#   }
# }
# KMS Endpoint
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
# resource "aws_vpc_endpoint" "ec2messages" {
#   service_name        = "com.amazonaws.${data.aws_region.current.region}.ec2messages"
#   vpc_id              = local.vpc_id
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = [aws_subnet.Star_Private_AZ1.id, aws_subnet.Star_Private_AZ2.id]
#   security_group_ids  = [aws_security_group.Endpoint_SG.id]
#   private_dns_enabled = true

#   tags = {
#     Name = "EC2Messages VPC Endpoint"
#   }
# }

# SSM Messages VPC Endpoint
# resource "aws_vpc_endpoint" "ssmmessages" {
#   vpc_id              = local.vpc_id
#   service_name        = "com.amazonaws.${data.aws_region.current.region}.ssmmessages"
#   vpc_endpoint_type   = "Interface"
#   security_group_ids  = [aws_security_group.Endpoint_SG.id]
#   subnet_ids          = [aws_subnet.Star_Private_AZ1.id, aws_subnet.Star_Private_AZ2.id]
#   private_dns_enabled = true

#   tags = {
#     Name = "ssmmessages-endpoint"
#   }
# }
# # SSM VPC Endpoint
# resource "aws_vpc_endpoint" "ssm" {
#   vpc_id             = local.vpc_id
#   service_name       = "com.amazonaws.${data.aws_region.current.region}.ssm"
#   vpc_endpoint_type  = "Interface"
#   security_group_ids = [aws_security_group.Endpoint_SG.id]
#   subnet_ids = [
#     aws_subnet.Star_Private_AZ1.id,
#     aws_subnet.Star_Private_AZ2.id
#   ]
#   private_dns_enabled = true

#   tags = {
#     Name = "ssm-endpoint"
#   }
# }


#############################################################################################
#                                     Transit Gateway
############################################################################################


#                                        Enable Transit gateway Peering Initialtion

# Turn this on and add the other transit gateway id, I will try doing it with a datablock
variable "transit_peering_enabled" {
  description = "Enable when the other transit gateway is created"
  type        = bool
  default     = false
}

locals {
  count = var.transit_peering_enabled ? 1 : 0
  # sao_paulo_cidr_range = data.aws_vpcs.foo.cidr_block[0] # "10.200.0.0/16"  Set it to the other region Cidr
}
# 
data "aws_vpc" "foo" {
  count  = var.transit_peering_enabled ? 1 : 0
  region = "sa-east-1"
  tags = {
    Name = "star1"
  }
}






# Explanation: Shinjuku Station is the hub—Tokyo is the data authority.
resource "aws_ec2_transit_gateway" "shinjuku_tgw01" {
  description                     = "shinjuku-tgw01 (Tokyo hub)"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  tags = {
  Name = "shinjuku-tgw01" }
}

# Connects Transit Gateway to VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "shinjuku_attach_tokyo_vpc01" {
  #  count              = var.transit_peering_enabled ? 1 : 0
  transit_gateway_id = aws_ec2_transit_gateway.shinjuku_tgw01.id
  vpc_id             = aws_vpc.Star.id
  subnet_ids         = [aws_subnet.Star_Private_AZ1.id, aws_subnet.Star_Private_AZ2.id]
  appliance_mode_support = "enable"
  dns_support            = "enable"

  tags = {
  Name = "shinjuku-attach-tokyo-vpc01" }
}
data "aws_ec2_transit_gateway" "attachment" {
  count  = var.transit_peering_enabled ? 1 : 0
  region = "sa-east-1"
  filter {
    name   = "tag:Name"
    values = ["liberdade-tgw01"]
  }

}

# Connects Japan to Sao Paulo
resource "aws_ec2_transit_gateway_peering_attachment" "shinjuku_to_liberdade_peer01" {
  count                   = var.transit_peering_enabled ? 1 : 0
  transit_gateway_id      = aws_ec2_transit_gateway.shinjuku_tgw01.id
  peer_region             = "sa-east-1"
  peer_transit_gateway_id = data.aws_ec2_transit_gateway.attachment[0].id # created in Sao Paulo module/state

  tags = {
  Name = "shinjuku-to-liberdade-peer02" }
}


#############################Future Optimization for better controlled process
resource "aws_ec2_transit_gateway_route_table" "rt_a" {
  transit_gateway_id = aws_ec2_transit_gateway.shinjuku_tgw01.id
  tags = {
    Name = "tgw-rt-a"
  }
}


#                           Transit Gateway Asoociation
resource "aws_ec2_transit_gateway_route_table_association" "vpc_assoc1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shinjuku_attach_tokyo_vpc01.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_a.id

}
# Route propagation so traffic goes to VPC from Transit Gateway
resource "aws_ec2_transit_gateway_route_table_propagation" "example" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shinjuku_attach_tokyo_vpc01.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_a.id
}
#                      Route Table to 

resource "aws_ec2_transit_gateway_route" "to_region_b_vpc1" {
  count                          = var.transit_peering_enabled ? 1 : 0
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_a.id
  destination_cidr_block         = aws_vpc.Star.cidr_block

  # IMPORTANT: Use the peering attachment ID (requester resource ID is fine)
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.shinjuku_attach_tokyo_vpc01.id

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
resource "aws_ec2_transit_gateway_route" "to_region_b_vpc2" {
  count                          = var.transit-peering-route ? 1 : 0
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_a.id
  destination_cidr_block         = data.aws_vpc.foo[0].cidr_block

  # IMPORTANT: Use the peering attachment ID (requester resource ID is fine)
  transit_gateway_attachment_id =  aws_ec2_transit_gateway_peering_attachment.shinjuku_to_liberdade_peer01[0].id

  # Ensure the accepter exists before routes are attempted
}


# Run terraform apply for this to be added after you active the above variable
resource "aws_ec2_transit_gateway_route_table_association" "vpc_assoc2" {
  count                          = var.transit-peering-route ? 1 : 0
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.shinjuku_to_liberdade_peer01[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.rt_a.id
}



# Run terraform apply again for this route to get added to the route table, It is a fault of terraform and there isn't much that can be done

resource "aws_route" "shinjuku_to_sp_route01" {
  count                  = var.transit_peering_enabled ? 1 : 0
  route_table_id         = aws_route_table.Private.id
  destination_cidr_block = data.aws_vpc.foo[0].cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.shinjuku_tgw01.id
}