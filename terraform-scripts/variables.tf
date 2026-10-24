variable "aws_region" {
  description = "The AWS region to deploy the infrastructure"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Base name for project resources"
  type        = string
  default     = "nhtsa-safety-lakehouse"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}