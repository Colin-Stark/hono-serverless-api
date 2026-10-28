# This file contains the output values for the Terraform configuration.

output "lambda_iam_role_arn" {
  description = "ARN of the IAM role for Lambda execution"
  value       = aws_iam_role.lambdaIam_role.arn
}

output "apigateway_iam_role_arn" {
  description = "ARN of the IAM role for API Gateway execution"
  value       = aws_iam_role.apigatewayIam_role.arn
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.hono_serverless_floci.arn
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_apigatewayv2_api.hono_api.id
}

output "api_gateway_endpoint" {
  description = "Endpoint of the API Gateway"
  value       = aws_apigatewayv2_api.hono_api.api_endpoint
}

output "api_gateway_stage" {
  description = "Stage of the API Gateway"
  value       = aws_apigatewayv2_stage.hono_api_stage.name
}

  
