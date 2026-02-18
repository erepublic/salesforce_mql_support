module.exports = {
  testEnvironment: "node",
  testMatch: [
    "<rootDir>/infra/terraform/mql/lambda_src/**/__tests__/**/*.test.js"
  ],
  moduleNameMapper: {
    "^@aws-sdk/client-secrets-manager$":
      "<rootDir>/infra/terraform/mql/lambda_src/__tests__/aws_secrets_manager_stub.js"
  }
};
