import {Hono} from "hono";
import {logger} from "hono/logger";
import {handle} from "@hono/aws-lambda";

import type {
    LambdaEvent, LambdaContext
} from "@hono/aws-lambda";

import {
    DynamoDBClient,
    GetItemCommand,
    PutItemCommand,
} from "@aws-sdk/client-dynamodb";

import {
    marshall,
    unmarshall,
} from "@aws-sdk/util-dynamodb";

/**
 * The bindings for the Hono app.
 * These are the types for the event and context objects that will be available in the Hono app.
 */
type Bindings = {
    event: LambdaEvent;
    lambdaContext: LambdaContext;
}

/**
 * The body of the echo request.
 * This is the type for the request body that will be sent to the echo endpoint.
 */
type EchoBody = {
    message: string;
}

type user = {
    userId: string;
    name: string;
    email: string;
    phoneNumber: number;
    address: string;
}


/**
 * The Hono app that will handle the requests.
 * This app will handle the requests to the echo endpoint and return the appropriate response.
 */
const app = new Hono<{Bindings: Bindings}>();

// Log every request to stdout/stderr. The Node.js Lambda runtime captures
// stdout/stderr and sends it to CloudWatch Logs (/aws/lambda/<function-name>)
// on real AWS, along with Lambda's own REPORT lines.
app.use(logger());

/**
 * Timestamp captured when this module first loads. On a cold start this is the
 * moment the Lambda execution environment begins initializing, so the elapsed
 * time until the first request is the function's startup (cold start) time.
 */
const startupStart = Date.now();
let startupLogged = false;

// Log the cold-start duration on the first request. `startupStart` is captured
// at module scope, so this runs once per cold start; warm invocations skip it.
// The Node.js Lambda runtime captures stdout and sends it to CloudWatch Logs.
app.use(async (c, next) => {
	if (!startupLogged) {
		startupLogged = true;
		console.log(
			JSON.stringify({
				event: "cold-start",
				durationMs: Date.now() - startupStart,
			})
		);
	}
	await next();
});


const dynamoDBClient = new DynamoDBClient({
    endpoint: process.env.AWS_ENDPOINT,
    region: process.env.AWS_REGION 
});

const usersTableName = process.env.USERS_TABLE_NAME;

/**
 * 
 * GET /users/:userId
 * This endpoint will return the user with the given userId.
 * If the user does not exist, it will return a 404 error.
 */
app.get("/users/:userId", async (c) => {
    const userId = c.req.param("userId");

    const result = await dynamoDBClient.send(new GetItemCommand({
        TableName: usersTableName,
        Key: marshall({ userId }),
    }));

    if (!result.Item) {
        return c.json({ error: "User not found" }, 404);
    }

    console.log("Retrieved user:", result);
    console.log("Retrieved user data:", result.Item);

    const item = unmarshall(result.Item);
    const user = item as user;

    return c.json(user);

});


/**
 * POST /users
 * This endpoint will create a new user with the given data.
 * It will return the created user.
 */
app.post("/users", async (c) => {
    let user: user;
    try {
        user = await c.req.json<user>();
    } catch {
        return c.json({ error: "Invalid JSON body" }, 400);
    }
    if (!user.userId || !user.name || !user.email) {
        return c.json({ error: "Missing required fields: userId, name, email" }, 400);
    }
    if (!usersTableName) {
        return c.json({ error: "Server configuration error: USERS_TABLE_NAME not set" }, 500);
    }
    const result = await dynamoDBClient.send(new PutItemCommand({
        TableName: usersTableName,
        Item: marshall(user),
    }));
    console.log("Created user:", result);
    return c.json(user);
});






/**
 * The root endpoint that will return a simple text response.
 * This endpoint will return a text response with the message "Hello from Hono on AWS Lambda!".
 * @example
 * Request: GET /
 * Response: Hello from Hono on AWS Lambda!
 */
app.get("/", (c) => {
    return c.text("Hello from Hono on AWS Lambda!");
});

/**
 * The hello endpoint that will return a greeting message with the name sent in the request parameter.
 * This endpoint will return a JSON response with the greeting message.
 * @example
 * Request: GET /hello/John
 * Response: { "message": "Hello John!" }
 */
app.get("/hello/:name", (c) =>  
    c.json({
        message: `Hello ${c.req.param("name")}!`,
    }) 
);

/**
 * The echo endpoint that will return the message sent in the request body.
 * This endpoint will return a JSON response with the message sent in the request body.
 * @example
 * Request: POST /echo
 * Body: { "message": "Hello, World!" }
 * Response: { "message": "Hello, World!" }
 */
app.post("/echo", async (c) => {
    let body: EchoBody;
    try {
        body = await c.req.json<EchoBody>();
    } catch {
        return c.json({ error: "Invalid JSON body" }, 400);
    }
    return c.json({
        message: body.message,
    });
});


/**
 * The whoami endpoint that will return information about the current lambda function.
 * This endpoint will return a JSON response with information about the current lambda function.
 * @example
 * Request: GET /whoami
 * Response: { "function": "my-function", "requestId": "12345", "version": "1.0.0", "memoryLimitInMB": 128, "awsRequestId": "12345", "invokedFunctionArn": "arn:aws:lambda:us-east-1:123456789012:function:my-function" }
 */
app.get("/whoami", (c) => {
    return c.json({
        function: c.env.lambdaContext.functionName,
        requestId: c.env.lambdaContext.awsRequestId,
        version: c.env.lambdaContext.functionVersion,
        memoryLimitInMB: c.env.lambdaContext.memoryLimitInMB,
        awsRequestId: c.env.lambdaContext.awsRequestId,
        invokedFunctionArn: c.env.lambdaContext.invokedFunctionArn,
    });
});

export const handler = handle(app);