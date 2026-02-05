variable "aws_region" {
  description = "AWS Region for the Chewbacca fleet to patrol."
  type        = string
  default     = "us-east-2"
}

variable "lab1c_bonusA" {
  description = "Prefix for naming. Students should change from 'chewbacca' to their own."
  type        = string
  default     = "lab1c_bonusA"
}

variable "vpc_cidr" {
  description = "VPC CIDR (use 10.x.x.x/xx as instructed)."
  type        = string
  default     = "10.180.0.0/16" # TODO: student supplies
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (use 10.180.x.x/xx)."
  type        = list(string)
  default     = ["10.180.1.0/24", "10.180.2.0/24"] # TODO: student supplies
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (use 10.180.x.x/xx)."
  type        = list(string)
  default     = ["10.180.11.0/24", "10.180.12.0/24"] # TODO: student supplies
}

variable "azs" {
  description = "Availability Zones list (match count with subnets)."
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"] # TODO: student supplies
}

variable "ec2_ami_id" {
  description = "AMI ID for the EC2 app host."
  type        = string
  default     = "ami-06f1fc9ae5ae7f31e" # TODO
}

variable "ec2_instance_type" {
  description = "EC2 instance size for the app."
  type        = string
  default     = "t3.micro"
}

variable "db_engine" {
  description = "RDS engine."
  type        = string
  default     = "mysql"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "lab1c_bonusA" # Students can change
}

variable "db_username" {
  description = "DB master username (students should use Secrets Manager in 1B/1C)."
  type        = string
  default     = "admin" # TODO: student supplies
}

variable "db_password" {
  description = "DB master password (DO NOT hardcode in real life; for lab only)."
  type        = string
  sensitive   = true
  default     = "lizzo123" # TODO: student supplies
}

variable "sns_email_endpoint" {
  description = "Email for SNS subscription (PagerDuty simulation)."
  type        = string
  default     = "pauljacksonn596@gmail.com" # TODO: student supplies
}

variable "public_access_cidr" {
  description = "CIDR block allowed to access EC2 via HTTP/SSH"
  type        = string
  default     = "0.0.0.0/0"
}
variable "domain_name" {
  description = "Root domain name managed in Route53"
  type        = string
}

variable "app_subdomain" {
  description = "Subdomain for the application"
  type        = string
  default     = "app"
}

# ----------------------------
# Bonus B - Common
# ----------------------------
variable "project_name" {
  description = "Project name used for tagging and naming"
  type        = string
  default     = "armageddon-lab"
}

variable "certificate_validation_method" {
  description = "ACM certificate validation method"
  type        = string
  default     = "DNS"
}

# ----------------------------
# Bonus B - WAF
# ----------------------------
variable "enable_waf" {
  description = "Enable WAF on the ALB"
  type        = bool
  default     = true
}

variable "waf_log_destination" {
  description = "Where WAF logs are sent (cloudwatch | s3 | firehose)"
  type        = string
  default     = "cloudwatch"
}

variable "waf_log_retention_days" {
  description = "Retention for WAF CloudWatch logs"
  type        = number
  default     = 7
}

variable "manage_route53_in_terraform" {
  description = "If true, Terraform creates the hosted zone. If false, you provide an existing hosted zone id."
  type        = bool
  default     = false
}

variable "route53_hosted_zone_id" {
  description = "Existing Route53 hosted zone ID (used when manage_route53_in_terraform = false)"
  type        = string
  default     = ""
}

# variable "project_name" {
#   description = "Project name used for tagging/naming"
#   type        = string
#   default     = "armageddon-lab"
# }

# variable "certificate_validation_method" {
#   description = "ACM validation method (DNS or EMAIL)"
#   type        = string
#   default     = "DNS"
# }

variable "alb_5xx_evaluation_periods" {
  description = "CloudWatch alarm evaluation periods"
  type        = number
  default     = 1
}

variable "alb_5xx_threshold" {
  description = "Threshold for 5XX count"
  type        = number
  default     = 5
}

variable "alb_5xx_period_seconds" {
  description = "Alarm period in seconds"
  type        = number
  default     = 60
}
