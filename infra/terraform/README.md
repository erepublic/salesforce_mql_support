# Terraform Infrastructure

This folder contains Terraform for AWS infrastructure used by the MQL summarizer integration.

Key design points:

- Single AWS account, separate resources per environment (`sandbox` and `production`).
- Remote state backend is S3 + DynamoDB lock table (created by the bootstrap stack).
- API Gateway uses API key auth (Salesforce must send `x-api-key`).

## 1) Bootstrap (remote state backend)

Location: `infra/terraform/bootstrap/`

Purpose:

- Creates the S3 bucket to store Terraform state
- Creates the DynamoDB table used for state locking

Typical workflow:

```bash
cd infra/terraform/bootstrap
terraform init
terraform apply
```

Capture the outputs:

- `state_bucket_name`
- `lock_table_name`
- `region`

## 2) Main MQL stack

Location: `infra/terraform/mql/`

This stack creates:

- Two Lambdas: `mql-summarizer-sandbox` and `mql-summarizer-production`
- API Gateway REST APIs (one per env) with `POST /<env>/summarize`
- API keys (one per env) and usage plans
- DynamoDB idempotency tables (one per env)
- SQS DLQs (one per env)
- CloudWatch log groups + alarms
- Secrets Manager secret containers (values should be set out-of-band)

### Configure backend

Terraform backend config is intentionally provided at init time (backend blocks cannot use variables).

Example:

```bash
cd infra/terraform/mql
terraform init \
  -backend-config="bucket=<STATE_BUCKET_NAME>" \
  -backend-config="key=mql/terraform.tfstate" \
  -backend-config="region=<REGION>" \
  -backend-config="dynamodb_table=<LOCK_TABLE_NAME>" \
  -backend-config="encrypt=true"
```

### Provide required variables

The stack requires API key values (sensitive):

- `api_key_value_sandbox`
- `api_key_value_production`

Example (shell env):

```bash
export TF_VAR_api_key_value_sandbox="...random..."
export TF_VAR_api_key_value_production="...random..."
```

Then:

```bash
terraform plan
terraform apply
```

### Lambda packaging

By default, Terraform packages a stub handler from:

- `infra/terraform/mql/lambda_stub/`

When the real Lambda code exists, set:

- `lambda_src_dir_sandbox`
- `lambda_src_dir_production`

to point at the environment-specific build output directories.

## 3) Salesforce callout updates

After `terraform apply`, read outputs:

- `sandbox_invoke_url`
- `production_invoke_url`

Salesforce must call the correct URL and include the API key header:

- `x-api-key: <env api key value>`

Note: the existing `TicketSummarizerCallout.cls` uses `Authorization: Bearer ...` as a placeholder; API Gateway API keys use `x-api-key`.
