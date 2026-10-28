# IAM role for Lambda execution
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# IAM role for APIGATEWAY execution
data "aws_iam_policy_document" "apigateway_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambdaIam_role" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role" "apigatewayIam_role" {
  name               = "apigateway_execution_role"
  assume_role_policy = data.aws_iam_policy_document.apigateway_assume_role.json
}

resource "aws_lambda_function" "hono_serverless_floci" {
  filename      = "function.zip"
  function_name = "hono-api"
  role          = aws_iam_role.lambdaIam_role.arn
  handler       = "index.handler"
  runtime       = "nodejs22.x"
  memory_size   = 256
  timeout       = 15
}

resource "aws_apigatewayv2_api" "hono_api" {
  name          = "hono-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.hono_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.hono_serverless_floci.invoke_arn
  description            = "Integration for Lambda function"
  payload_format_version = "2.0"

}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.hono_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.hono_api.id
  name        = "$default"
  auto_deploy = true
}
