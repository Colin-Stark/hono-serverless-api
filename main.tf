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

  environment {
    variables = {
      USERS_TABLE_NAME = var.users_table_name,
      AWS_REGION       = var.aws_region,
      AWS_ENDPOINT     = var.aws_endpoint
    }
  }
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


resource "aws_dynamodb_table" "users_table" {
  name         = var.users_table_name
  hash_key     = "userId"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "phoneNumber"
    type = "N"
  }


  global_secondary_index {
    name            = "email-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "email"
      key_type       = "HASH"
    }
  }

  global_secondary_index {
    name            = "PhoneNumber-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "phoneNumber"
      key_type       = "HASH"
    }
  }

}
