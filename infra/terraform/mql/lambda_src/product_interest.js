function redactInlineText(s) {
  if (!s) return null;
  let out = String(s);
  out = out.replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, "*@redacted");
  out = out.replace(/\+?\d[\d\s().-]{7,}\d/g, "[redacted]");
  return out;
}

function safeParseUrl(raw) {
  if (!raw) return null;
  try {
    return new URL(String(raw));
  } catch {
    return null;
  }
}

function sanitizeUrl(raw) {
  const u = safeParseUrl(raw);
  if (!u) return null;
  // Drop querystring/fragment to avoid carrying PII tokens.
  u.search = "";
  u.hash = "";
  // Normalize hostname casing.
  u.hostname = String(u.hostname || "").toLowerCase();
  const s = u.toString();
  // Keep it bounded.
  return s.length > 240 ? s.slice(0, 240) : s;
}

function extractUrlsFromText(text) {
  const s = String(text || "");
  if (!s.trim()) return [];
  const urls = [];
  // Rough-but-effective: capture http/https URLs up to whitespace/newline.
  const re = /\bhttps?:\/\/[^\s<>"')\]]+/gi;
  let m;
  while ((m = re.exec(s))) {
    const cleaned = sanitizeUrl(m[0]);
    if (cleaned) urls.push(cleaned);
    if (urls.length >= 30) break;
  }
  return Array.from(new Set(urls));
}

function evidenceCategoryForKind(kind) {
  const k = String(kind || "");
  if (k.includes("url")) return "url";
  return "text";
}

function buildEvidenceItem(kind, rawText, { occurredAt } = {}) {
  const text = redactInlineText(rawText);
  if (!text || !String(text).trim()) return null;
  return {
    kind: String(kind || "text"),
    category: evidenceCategoryForKind(kind),
    text: String(text).slice(0, 280),
    occurredAt: occurredAt || null
  };
}

function buildEvidenceFromSalesLeadWebActivity(salesLeads) {
  const list = Array.isArray(salesLeads) ? salesLeads : [];
  const evidence = [];

  for (const sl of list.slice(0, 3)) {
    const occurredAt = sl?.Lead_Date__c || sl?.CreatedDate || null;
    const summary = sl?.Web_Activity_Summary__c || "";
    for (const url of extractUrlsFromText(summary)) {
      const item = buildEvidenceItem("sf_web_activity_url", url, {
        occurredAt
      });
      if (item) evidence.push(item);
    }
  }

  return evidence;
}

function buildEvidenceFromCampaignMembers(campaignMembers) {
  const list = Array.isArray(campaignMembers) ? campaignMembers : [];
  const evidence = [];
  for (const cm of list.slice(0, 30)) {
    const name = cm?.Campaign?.Name || null;
    if (!name) continue;
    const occurredAt = cm?.FirstRespondedDate || cm?.CreatedDate || null;
    const item = buildEvidenceItem("sf_campaign_name", name, { occurredAt });
    if (item) evidence.push(item);
  }
  return evidence;
}

function buildEvidenceFromHubspotContactProps(hsContactProps) {
  const props =
    hsContactProps && typeof hsContactProps === "object" ? hsContactProps : {};
  const evidence = [];

  const urlFields = [
    "hs_analytics_first_url",
    "hs_analytics_last_url",
    "hs_analytics_first_referrer",
    "hs_analytics_last_referrer"
  ];
  for (const f of urlFields) {
    const v = props[f];
    if (!v) continue;
    const cleaned = sanitizeUrl(v) || String(v);
    const item = buildEvidenceItem("hs_url", cleaned);
    if (item) evidence.push(item);
  }

  const textFields = [
    "hs_analytics_first_touch_converting_campaign",
    "hs_analytics_last_touch_converting_campaign",
    "hs_analytics_source",
    "hs_analytics_source_data_1",
    "hs_analytics_source_data_2",
    "utm_campaign",
    "utm_source",
    "utm_medium",
    "first_conversion_event_name",
    "recent_conversion_event_name"
  ];
  for (const f of textFields) {
    const v = props[f];
    if (!v) continue;
    const item = buildEvidenceItem("hs_text_signal", v);
    if (item) evidence.push(item);
  }

  return evidence;
}

function scoreToConfidence(score) {
  const s = Number(score || 0);
  if (s >= 14) return "High";
  if (s >= 7) return "Moderate";
  return "Light";
}

function inferProductInterest({ rulesConfig, evidence }) {
  const cfg = rulesConfig && typeof rulesConfig === "object" ? rulesConfig : {};
  const rules = Array.isArray(cfg.rules) ? cfg.rules : [];
  const maxProducts = Number(cfg.maxProducts || 4);
  const maxEvidencePerProduct = Number(cfg.maxEvidencePerProduct || 3);

  const byId = new Map();

  function addHit(rule, ev) {
    const id = String(rule.productId || rule.productName || "Unknown");
    const name = String(rule.productName || rule.productId || id);
    const weight = Number(rule.weight || 0);
    if (!byId.has(id))
      byId.set(id, {
        productId: id,
        productName: name,
        score: 0,
        evidence: []
      });

    const agg = byId.get(id);
    agg.score += weight;
    if (agg.evidence.length < maxEvidencePerProduct) {
      const tag = ev.category === "url" ? "URL" : "Signal";
      const s = `${tag}: ${ev.text}`;
      if (!agg.evidence.includes(s)) agg.evidence.push(s);
    }
  }

  for (const ev of Array.isArray(evidence) ? evidence : []) {
    const text = String(ev?.text || "");
    if (!text) continue;
    const category = ev?.category || evidenceCategoryForKind(ev?.kind);

    for (const rule of rules) {
      const cats = Array.isArray(rule?.evidenceCategories)
        ? rule.evidenceCategories
        : ["text", "url"];
      if (!cats.includes(category)) continue;

      const reRaw = rule?.regex;
      if (!reRaw) continue;
      let re;
      try {
        re = new RegExp(String(reRaw), "i");
      } catch {
        continue;
      }
      if (!re.test(text)) continue;
      addHit(rule, { ...ev, category });
    }
  }

  const ranked = Array.from(byId.values())
    .sort((a, b) => b.score - a.score)
    .slice(0, Math.max(0, maxProducts));

  const topProducts = ranked.map((p) => ({
    name: p.productName,
    confidence: scoreToConfidence(p.score),
    evidence: p.evidence
  }));

  return {
    topProducts,
    hasEvidence: topProducts.length > 0
  };
}

module.exports = {
  extractUrlsFromText,
  sanitizeUrl,
  buildEvidenceFromSalesLeadWebActivity,
  buildEvidenceFromCampaignMembers,
  buildEvidenceFromHubspotContactProps,
  inferProductInterest,
  scoreToConfidence
};
