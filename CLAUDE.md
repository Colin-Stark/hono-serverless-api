# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`hono-serverless-floci` is a small, production-minded Hono API running on AWS Lambda behind an API Gateway HTTP API v2. It is TypeScript (strict), bundled with esbuild into a single `dist/index.mjs`, zipped to `function.zip`, and deployed with `aws lambda update-function-code`. The same code can run locally against the Floci AWS emulator.

Six routes live in one file, `src/index.ts`, exported as `handler` via `@hono/aws-lambda`:
- `GET /` — plain-text health/hello
- `GET /hello/:name` — JSON greeting from the path param
- `POST /echo` — echoes `message` from the JSON body
- `GET /whoami` — exposes Lambda runtime context
- `GET /users/:userId` — reads a user from DynamoDB
- `POST /users` — creates a user in DynamoDB

API Gateway is intentionally dumb: a single `ANY /{proxy+}` route forwards every request to one Lambda (the "Lambdalith" pattern); Hono does the real routing in testable code.

The app also logs cold-start duration (module load to first request) as structured JSON on the first invocation of each cold start, and talks to DynamoDB via the `USERS_TABLE_NAME` environment variable.

## Commands

All commands run in PowerShell — the `zip` step and the infra scripts use PowerShell (`Compress-Archive`). Node 22 + pnpm required.

| Command | What it does |
|---|---|
| `pnpm install` | Install dependencies |
| `pnpm typecheck` | `tsc` in `noEmit` strict mode — the type safety gate; run before building |
| `pnpm build` | esbuild bundles `src/index.ts` (and deps) into `dist/index.mjs`, ESM, target node22 |
| `pnpm zip` | PowerShell `Compress-Archive` of `dist/index.mjs` into `function.zip` (archive root, so `index.handler` resolves) |
| `pnpm package` | typecheck → build → zip |
| `pnpm deploy` | package → `aws lambda update-function-code --function-name hono-api --zip-file fileb://function.zip` |

There is **no lint or test runner configured** in `package.json`, and no test files exist yet. Tests are meant to use Hono's in-process `app.request("/path")` (no AWS needed) plus a direct `handler(event, context)` invocation for the adapter contract — see the README roadmap. If you add a runner, run a single test file with its CLI filter, e.g. `npx vitest run src/foo.test.ts`.

### Local development (Floci)

Never run against a real cloud account — use Floci instead (see the parent `floci/AGENTS.md`). State is disposable: `floci stop` then `floci start` gives a clean cloud.

PowerShell — load the emulator endpoint before running anything:

```powershell
$env:AWS_ENDPOINT_URL="http://localhost:4566"
$env:AWS_ACCESS_KEY_ID="test"
$env:AWS_SECRET_ACCESS_KEY="test"
$env:AWS_DEFAULT_REGION="us-east-1"
$env:USERS_TABLE_NAME="Users"
```

Then `floci start` (AWS) to bring up the emulator, `pnpm package`, create the DynamoDB table once with `./scripts/dynamo/createTable.PS1`, and either create the function/API once with the PowerShell scripts or just `pnpm deploy` to update an existing function.

### First-time deployment

```powershell
# 0. Point the AWS CLI at Floci (PowerShell)
$env:AWS_ENDPOINT_URL="http://localhost:4566"
$env:AWS_ACCESS_KEY_ID="test"; $env:AWS_SECRET_ACCESS_KEY="test"; $env:AWS_DEFAULT_REGION="us-east-1"
$env:USERS_TABLE_NAME="Users"

# 1. Build the artifact
pnpm package

# 2. Create the DynamoDB table (first time only)
./scripts/dynamo/createTable.PS1

# 3. Create the Lambda function (first time only)
./scripts/createFunction.ps1

# 4. Create the HTTP API, integration, route and stage (first time only)
./scripts/apigatewayv2/createApiGateway.ps1

# 5. Every change afterwards
pnpm deploy
```

## Architecture

**Request flow** (four translations):

1. HTTP → Lambda event JSON (API Gateway, `AWS_PROXY` with payload format 2.0)
2. Lambda event → Web `Request` (`@hono/aws-lambda` adapter)
3. Hono app: `Request` → `Response` (your routes in `src/index.ts`)
4. Web `Response` → Lambda result JSON (adapter), then → HTTP response (API Gateway)

`handle(app)` inspects the event shape (API Gateway v1/v2, ALB, VPC Lattice), builds a standard `Request`, and calls `app.fetch(request, { event, lambdaContext })`. That second argument becomes Hono **Bindings**, so handlers use portable `c.req` for business logic and `c.env.event` / `c.env.lambdaContext` when they need AWS details (see the `/whoami` route).

**App** (`src/index.ts`): one `Hono<{ Bindings }>` instance with `logger()` middleware plus a cold-start logging middleware, and six routes:
- `GET /` — plain-text health/hello
- `GET /hello/:name` — JSON greeting from the path param
- `POST /echo` — echoes `message` from the JSON body
- `GET /whoami` — exposes Lambda runtime context (`functionName`, `awsRequestId`, `memoryLimitInMB`, etc.)
- `GET /users/:userId` — reads a user from DynamoDB (`GetItemCommand`), 404 when not found
- `POST /users` — creates a user in DynamoDB (`PutItemCommand`), validates required fields (`userId`, `name`, `email`)

**DynamoDB**: a `DynamoDBClient` is created at module scope using `AWS_ENDPOINT` and `AWS_REGION` from the environment, so it points at Floci locally and real AWS in production. The table name comes from `USERS_TABLE_NAME`.

**Build pipeline** (`package.json` scripts): `tsc --noEmit` (strict typecheck) → esbuild bundle (ESM, node22, single file, deps inlined) → PowerShell zip → `aws lambda update-function-code`. Typecheck and build are separate because esbuild strips types without checking them; `tsc` runs first so bad code never ships.

**Infrastructure scripts** (PowerShell, not at repo root despite the README's references):
- `scripts/createFunction.ps1` — `aws lambda create-function` (`nodejs22.x`, 256 MB, 15 s timeout, handler `index.handler`, placeholder role `arn:aws:iam::000000000000:role/lambda-role`)
- `scripts/apigatewayv2/createApiGateway.ps1` — creates the HTTP API, the `AWS_PROXY`/v2.0 integration, the `ANY /{proxy+}` route, and the `$default` stage (auto-deploy)
- `scripts/dynamo/createTable.PS1` — `aws dynamodb create-table` for the `Users` table (HASH key `userId`, PAY_PER_REQUEST billing)

**Infrastructure as Code** (Terraform): `main.tf`, `variable.tf`, `output.tf` in the repo root. `.gitignore` excludes `*.tfstate`, `*.tfvars`, `.terraform/` and plan files — never commit state or secrets.

**Known quirks** (from the README, worth remembering before editing):
- `create-api --target` already quick-creates a default integration/route/stage; the script then creates them again, which conflicts on real AWS.
- `ANY /{proxy+}` does not match the bare `/` path on a real HTTP API; add a second `ANY /` route or use `$default` as the true catch-all.
- On real AWS the Lambda needs a resource policy allowing `apigateway.amazonaws.com` to invoke it; local emulators often skip this.
- `000000000000` and `role/lambda-role` are emulator placeholders; use real values and a least-privilege role on AWS.
- `pnpm zip` uses PowerShell; on macOS/Linux replace it with `zip -j function.zip dist/index.mjs`.
- Build and `tsconfig.json` both expect `src/index.ts`.
- The DynamoDB client reads `AWS_ENDPOINT` (not `AWS_ENDPOINT_URL`) and `AWS_REGION` at module scope; set both when running locally against Floci.
