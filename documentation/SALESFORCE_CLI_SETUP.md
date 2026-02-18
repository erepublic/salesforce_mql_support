# Salesforce CLI Setup and Deployment Workflow

This project is configured for a sandbox-first workflow:

1. Authenticate to Sandbox and Production using Salesforce CLI.
2. Retrieve and edit metadata locally in Git.
3. Deploy and test in Sandbox.
4. Validate in Production.
5. Quick deploy to Production when approved.

## 1) Prerequisites

- Salesforce CLI installed (`sf --version`)
- Access to:
  - Sandbox org
  - Production org
- Browser login rights for both orgs

Salesforce CLI download and docs:

- https://developer.salesforce.com/tools/salesforcecli

## 2) Authenticate your orgs

Run these commands from this repository root.

```bash
# Sandbox (set as default org for day-to-day development)
sf org login web \
  --alias mql-sandbox \
  --instance-url https://test.salesforce.com \
  --set-default

# Production
sf org login web \
  --alias mql-prod \
  --instance-url https://login.salesforce.com
```

Confirm connections:

```bash
sf org list
```

## 3) Pull metadata from Sandbox

Start with manifest-driven retrieval:

```bash
sf project retrieve start \
  --target-org mql-sandbox \
  --manifest manifest/package.xml
```

For targeted retrieval during feature work:

```bash
# Example: pull one custom object and one flow
sf project retrieve start \
  --target-org mql-sandbox \
  --metadata CustomObject:MQL__c \
  --metadata Flow:MQL_Auto_Create
```

## 4) Develop locally and commit

1. Make metadata changes in `force-app/`.
2. Run a deploy to Sandbox (next section).
3. Commit only the metadata you intend to promote.

Recommended branch approach:

- `main`: release-ready state
- `feature/*`: sandbox development branches
- PR merge to `main` after Sandbox validation

## 5) Deploy to Sandbox

```bash
sf project deploy start \
  --target-org mql-sandbox \
  --source-dir force-app \
  --test-level RunLocalTests
```

If deployment fails, inspect details:

```bash
sf project deploy report --use-most-recent
```

## 6) Validate in Production (no changes applied)

Use validate first to generate a deploy job id:

```bash
sf project deploy validate \
  --target-org mql-prod \
  --source-dir force-app \
  --test-level RunLocalTests
```

Capture the resulting job id from command output.

## 7) Quick deploy to Production

After successful validation and approvals:

```bash
sf project deploy quick \
  --target-org mql-prod \
  --job-id <VALIDATION_JOB_ID>
```

## 8) Useful day-to-day commands

```bash
# Show orgs and defaults
sf org list

# Open Sandbox in browser
sf org open --target-org mql-sandbox

# Open Production in browser
sf org open --target-org mql-prod

# Check latest deployment status
sf project deploy report --use-most-recent
```

## 9) Credential and security notes

- CLI auth tokens are stored locally (in `.sf/`), which is ignored by Git.
- Never commit secret files or access tokens.
- Keep Production auth limited to release managers where possible.
