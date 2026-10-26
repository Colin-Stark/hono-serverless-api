$apiId = aws apigatewayv2 create-api `
  --name hono-api `
  --protocol-type HTTP `
  --target arn:aws:lambda:us-east-1:000000000000:function:hono-api `
  --query 'ApiId' `
  --output text

  $integrationId = aws apigatewayv2 create-integration `
  --api-id $apiId `
  --integration-type AWS_PROXY `
  --integration-uri arn:aws:lambda:us-east-1:000000000000:function:hono-api `
  --payload-format-version 2.0 `
  --query 'IntegrationId' `
  --output text

aws apigatewayv2 create-route `
  --api-id $apiId `
  --route-key "ANY /{proxy+}" `
  --target "integrations/$integrationId" `
  --output text

aws apigatewayv2 create-stage `
  --api-id $apiId `
  --stage-name '$default' `
  --auto-deploy `
  --output text