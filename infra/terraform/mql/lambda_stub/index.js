// Minimal handler so Terraform packaging/plan works before real code lands.
// Real implementation should live outside infra/ and be wired via lambda_src_dir_* vars.
exports.handler = async function handler(event) {
  return {
    statusCode: 200,
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      ok: true,
      message: "mql-summarizer stub",
      received: {
        path: event?.path || null,
        requestId: event?.requestContext?.requestId || null
      }
    })
  };
};
