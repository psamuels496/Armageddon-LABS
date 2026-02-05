variable "aws_region" {
  description = "AWS Region for the Chewbacca fleet to patrol."
  type        = string
  default     = "us-east-2"
}

variable "lab1c" {
  description = "Prefix for naming. Students should change from 'chewbacca' to their own."
  type        = string
  default     = "lab1c"
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
  default     = "lab1c" # Students can change
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

