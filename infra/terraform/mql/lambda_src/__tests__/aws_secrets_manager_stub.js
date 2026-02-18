class SecretsManagerClient {
  constructor() {}
  async send() {
    throw new Error("SecretsManagerClient stub: not implemented in unit tests");
  }
}

class GetSecretValueCommand {
  constructor() {}
}

module.exports = { SecretsManagerClient, GetSecretValueCommand };
