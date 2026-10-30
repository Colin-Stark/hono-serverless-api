variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "users_table_name" {
  description = "The name of the DynamoDB Users table."
  type        = string
  default     = "Users"
}

variable "aws_endpoint" {
  description = "The endpoint for AWS services (useful for local testing with Floci/LocalStack). Must be reachable from inside the Lambda container, so use the Docker host gateway (e.g. http://host.docker.internal:4566), not localhost."
  type        = string
  default     = "http://host.docker.internal:4566"
}

