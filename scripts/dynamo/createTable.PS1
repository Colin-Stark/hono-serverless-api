aws dynamodb create-table `
    --table-name Users `
    --attribute-definitions `
        AttributeName=userId,AttributeType=S `
    --key-schema `
        AttributeName=userId,KeyType=HASH `
    --billing-mode PAY_PER_REQUEST