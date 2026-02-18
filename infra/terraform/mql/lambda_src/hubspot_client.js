async function fetchWithTimeout(url, options, timeoutMs) {
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(t);
  }
}

function safeJsonParse(s) {
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
}

function getHubspotToken(hsSecret) {
  if (!hsSecret || typeof hsSecret !== "object") return null;
  return (
    hsSecret?.token ||
    hsSecret?.accessToken ||
    hsSecret?.privateAppToken ||
    hsSecret?.HUBSPOT_PRIVATE_APP_TOKEN ||
    hsSecret?.HUBSPOT_ACCESS_TOKEN ||
    hsSecret?.HUBSPOT_TOKEN ||
    null
  );
}

function getHubspotBaseUrl(hsSecret) {
  if (!hsSecret || typeof hsSecret !== "object")
    return "https://api.hubapi.com";
  return (
    String(hsSecret?.baseUrl || hsSecret?.HUBSPOT_BASE_URL || "").trim() ||
    "https://api.hubapi.com"
  );
}

async function hsFetchJson({ token, baseUrl, path, method, body, timeoutMs }) {
  const url = `${String(baseUrl || "https://api.hubapi.com").replace(/\/+$/, "")}${path}`;
  const resp = await fetchWithTimeout(
    url,
    {
      method: method || "GET",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json"
      },
      body: body ? JSON.stringify(body) : undefined
    },
    Number(timeoutMs || 3500)
  );
  const text = await resp.text();
  const json = safeJsonParse(text);
  if (!resp.ok) {
    const msg = json?.message || json?.status || `HTTP ${resp.status}`;
    const err = new Error(`HubSpot error: ${msg}`);
    err.status = resp.status;
    err.body = text?.slice(0, 2000);
    return { ok: false, error: err };
  }
  return { ok: true, json: json || null };
}

async function searchContactIdByEmail({ token, baseUrl, email, timeoutMs }) {
  if (!email) return null;
  const res = await hsFetchJson({
    token,
    baseUrl,
    timeoutMs,
    path: "/crm/v3/objects/contacts/search",
    method: "POST",
    body: {
      filterGroups: [
        { filters: [{ propertyName: "email", operator: "EQ", value: email }] }
      ],
      limit: 1
    }
  });
  if (!res.ok) return null;
  return res.json?.results?.[0]?.id ? String(res.json.results[0].id) : null;
}

async function getContactProperties({
  token,
  baseUrl,
  hsContactId,
  properties,
  timeoutMs
}) {
  if (!hsContactId) return null;
  const params = new URLSearchParams();
  for (const p of properties || []) params.append("properties", p);
  params.set("archived", "false");
  const path = `/crm/v3/objects/contacts/${encodeURIComponent(hsContactId)}?${params.toString()}`;
  const res = await hsFetchJson({
    token,
    baseUrl,
    path,
    method: "GET",
    timeoutMs
  });
  if (!res.ok) return null;
  return res.json?.properties || null;
}

module.exports = {
  getHubspotToken,
  getHubspotBaseUrl,
  searchContactIdByEmail,
  getContactProperties
};
