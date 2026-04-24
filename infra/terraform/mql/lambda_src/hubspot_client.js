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
  propertiesWithHistory,
  timeoutMs
}) {
  const record = await getContactRecord({
    token,
    baseUrl,
    hsContactId,
    properties,
    propertiesWithHistory,
    timeoutMs
  });
  return record?.properties || null;
}

async function getContactRecord({
  token,
  baseUrl,
  hsContactId,
  properties,
  propertiesWithHistory,
  timeoutMs
}) {
  if (!hsContactId) return null;
  const params = new URLSearchParams();
  for (const p of properties || []) params.append("properties", p);
  for (const p of propertiesWithHistory || [])
    params.append("propertiesWithHistory", p);
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
  return res.json || null;
}

async function fetchRecentEmailEvents({
  token,
  baseUrl,
  email,
  eventType,
  sinceIso,
  limit,
  timeoutMs
}) {
  if (!email) return [];
  const params = new URLSearchParams();
  params.set("recipient", email);
  if (eventType) params.set("eventType", String(eventType));
  if (sinceIso) {
    const sinceMs = Date.parse(sinceIso);
    if (Number.isFinite(sinceMs)) {
      params.set("startTimestamp", String(sinceMs));
    }
  }
  const cap = Math.min(Math.max(Number(limit) || 50, 1), 300);
  params.set("limit", String(Math.min(cap, 100)));

  const results = [];
  let offset = null;
  for (let page = 0; page < 3; page++) {
    const pageParams = new URLSearchParams(params);
    if (offset) pageParams.set("offset", offset);
    const path = `/email/public/v1/events?${pageParams.toString()}`;
    const res = await hsFetchJson({
      token,
      baseUrl,
      path,
      method: "GET",
      timeoutMs
    });
    if (!res.ok) break;
    const events = Array.isArray(res.json?.events) ? res.json.events : [];
    for (const event of events) {
      results.push(event);
      if (results.length >= cap) break;
    }
    if (results.length >= cap) break;
    if (res.json?.hasMore && res.json?.offset) {
      offset = String(res.json.offset);
    } else {
      break;
    }
  }
  return results;
}

async function fetchMarketingEmails({ token, baseUrl, emailIds, timeoutMs }) {
  // The Email Events API returns an `emailCampaignId` that identifies a legacy
  // email send (not a row in the Marketing Email Tool CRM object), so subject
  // lookup must go through `/email/public/v1/campaigns/{id}` rather than the
  // `/marketing/v3/emails/batch/read` endpoint (which does not exist and 404s).
  // Fetch each id one-at-a-time with bounded concurrency.
  const ids = Array.from(
    new Set(
      (Array.isArray(emailIds) ? emailIds : [])
        .map((id) => String(id || "").trim())
        .filter(Boolean)
    )
  );
  if (!ids.length) return new Map();
  const out = new Map();
  const concurrency = 4;
  for (let i = 0; i < ids.length; i += concurrency) {
    const chunk = ids.slice(i, i + concurrency);
    const results = await Promise.all(
      chunk.map((id) =>
        hsFetchJson({
          token,
          baseUrl,
          path: `/email/public/v1/campaigns/${encodeURIComponent(id)}`,
          method: "GET",
          timeoutMs
        })
          .then((res) => ({ id, res }))
          .catch(() => ({ id, res: { ok: false } }))
      )
    );
    for (const { id, res } of results) {
      if (!res?.ok || !res.json) continue;
      const row = res.json;
      const subject =
        typeof row?.subject === "string" && row.subject.trim()
          ? row.subject.trim()
          : null;
      const name =
        typeof row?.name === "string" && row.name.trim()
          ? row.name.trim()
          : null;
      if (!subject && !name) continue;
      out.set(id, { id, name, subject });
    }
  }
  return out;
}

module.exports = {
  getHubspotToken,
  getHubspotBaseUrl,
  searchContactIdByEmail,
  getContactProperties,
  getContactRecord,
  fetchRecentEmailEvents,
  fetchMarketingEmails
};
