variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "devops-project"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"   # free-tier eligible
}

variable "key_pair_name" {
  description = "Name of your existing AWS key pair for SSH access"
  type        = string
  # Set this in Jenkins as an environment variable or terraform.tfvars
}
