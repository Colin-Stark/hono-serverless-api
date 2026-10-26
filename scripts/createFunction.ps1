aws lambda create-function `
  --function-name hono-api `
  --runtime nodejs22.x `
  --role arn:aws:iam::000000000000:role/lambda-role `
  --handler index.handler `
  --timeout 15 `
  --memory-size 256 `
  --zip-file fileb://function.zip