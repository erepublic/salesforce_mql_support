# salesforce_mql_support

Salesforce MQL implementation project with a Sandbox-first deployment workflow.

## Salesforce CLI setup

See `documentation/SALESFORCE_CLI_SETUP.md` for:

- Salesforce org authentication (Sandbox and Production)
- Metadata retrieve/deploy commands
- Validation and production rollout workflow
- Recommended day-to-day Git + Salesforce process

## Common commands

```bash
# install local tooling
npm install

# authenticate orgs
npm run sf:auth:sandbox
npm run sf:auth:prod

# sync and deploy
npm run sf:retrieve
npm run sf:deploy:sandbox
npm run sf:validate:prod
npm run sf:quick:prod -- <VALIDATION_JOB_ID>
```

## Project structure

- `force-app/` - Salesforce source format metadata
- `manifest/package.xml` - metadata manifest for retrieve operations
- `documentation/` - project and process documentation
