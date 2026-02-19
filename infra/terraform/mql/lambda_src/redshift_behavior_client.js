const { Client } = require("pg");

function safeInt(v) {
  const n = Number(v);
  return Number.isFinite(n) ? Math.floor(n) : null;
}

function toIsoMaybeRedshift(ts) {
  // Redshift often returns "YYYY-MM-DD HH:MM:SS[.fff]" without timezone.
  if (!ts) return null;
  const s = String(ts).trim();
  if (/^\d{4}-\d{2}-\d{2}T/.test(s)) return s;
  const m = s.match(/^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2}(?:\.\d+)?)$/);
  if (m) return `${m[1]}T${m[2]}Z`;
  const t = Date.parse(s);
  return Number.isFinite(t) ? new Date(t).toISOString() : null;
}

function isRecentIso(iso, days) {
  const t = Date.parse(iso);
  if (!Number.isFinite(t)) return false;
  const windowDays = Number.isFinite(Number(days)) ? Number(days) : 30;
  const cutoff = Date.now() - windowDays * 24 * 60 * 60 * 1000;
  return t >= cutoff;
}

function summarizeTopCounts(values, topN) {
  const m = new Map();
  for (const v of values || []) {
    if (!v) continue;
    m.set(v, (m.get(v) || 0) + 1);
  }
  return Array.from(m.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, Math.max(1, Math.min(10, topN || 5)))
    .map(([value, count]) => ({ value, count }));
}

function getAnalyticsDbConfig({ secret, env }) {
  const s = secret && typeof secret === "object" ? secret : {};
  const e = env && typeof env === "object" ? env : process.env;

  // Allow either the prefixed env-var style or simpler keys in the secret.
  const host = s.ANALYTICS_DB_HOST || s.host || e.ANALYTICS_DB_HOST || null;
  const port =
    safeInt(s.ANALYTICS_DB_PORT || s.port || e.ANALYTICS_DB_PORT) || 5439;
  const database =
    s.ANALYTICS_DB_DATABASE || s.database || e.ANALYTICS_DB_DATABASE || null;
  const user =
    s.ANALYTICS_DB_USERNAME ||
    s.username ||
    s.user ||
    e.ANALYTICS_DB_USERNAME ||
    null;
  const password =
    s.ANALYTICS_DB_PASSWORD || s.password || e.ANALYTICS_DB_PASSWORD || null;

  if (!host || !database || !user || !password) return null;

  return {
    host,
    port,
    database,
    user,
    password,
    ssl: { rejectUnauthorized: false }
  };
}

async function withClient(cfg, fn) {
  const client = new Client({
    host: cfg.host,
    port: cfg.port,
    database: cfg.database,
    user: cfg.user,
    password: cfg.password,
    ssl: cfg.ssl,
    // In-Lambda cold starts + network handshakes can exceed 2.5s; keep bounded
    // but less brittle for connectivity tests.
    connectionTimeoutMillis: 8000,
    statement_timeout: 20000,
    query_timeout: 20000
  });
  await client.connect();
  try {
    // Make sure long-running scans fail fast.
    await client.query("set statement_timeout to 20000;");
    return await fn(client);
  } finally {
    try {
      await client.end();
    } catch {
      // ignore
    }
  }
}

async function fetchAnalyticsBehavior({
  config,
  contactEmail,
  hubspotContactId,
  limits
}) {
  const cfg = config || null;
  const email = contactEmail ? String(contactEmail).trim() : null;
  const hsId = hubspotContactId ? String(hubspotContactId).trim() : null;
  const lim = limits && typeof limits === "object" ? limits : {};

  if (!cfg) return null;
  if (!email && !hsId) return null;

  const pageviewsLimit = Math.max(
    0,
    Math.min(40, safeInt(lim.pageviewsLimit) || 12)
  );
  const actionsLimit = Math.max(
    0,
    Math.min(40, safeInt(lim.actionsLimit) || 10)
  );
  const emailEventsLimit = Math.max(
    0,
    Math.min(60, safeInt(lim.emailEventsLimit) || 12)
  );

  return await withClient(cfg, async (client) => {
    // Resolve a Navigator user id when possible.
    let navUser = null;
    if (hsId) {
      const r = await client.query(
        "select id, email, last_login_at from public.nav2016_user where hubspot_contact_id = $1 limit 1;",
        [hsId]
      );
      navUser = r.rows?.[0] || null;
    }
    if (!navUser && email) {
      const r = await client.query(
        "select id, email, last_login_at from public.nav2016_user where lower(email)=lower($1) limit 1;",
        [email]
      );
      navUser = r.rows?.[0] || null;
    }

    const navUserId = navUser?.id ? Number(navUser.id) : null;

    let pageviews = [];
    let actions = [];
    if (navUserId && pageviewsLimit > 0) {
      const r = await client.query(
        `select visited_at, url_host, url_path, referrer, meta_utm_source, meta_utm_medium, meta_utm_campaign
         from public.navigator_pageviews
         where user_id = $1
         order by visited_at desc
         limit ${pageviewsLimit};`,
        [navUserId]
      );
      pageviews = (r.rows || []).map((row) => ({
        occurredAt: toIsoMaybeRedshift(row.visited_at),
        host: row.url_host || null,
        path: row.url_path || null,
        referrer: row.referrer || null,
        utm: {
          source: row.meta_utm_source || null,
          medium: row.meta_utm_medium || null,
          campaign: row.meta_utm_campaign || null
        }
      }));
    }

    if (navUserId && actionsLimit > 0) {
      const r = await client.query(
        `select added_at, action_name, action_value, meta_url, url_path, referrer
         from public.navigator_actions
         where user_id = $1
         order by added_at desc
         limit ${actionsLimit};`,
        [navUserId]
      );
      actions = (r.rows || []).map((row) => ({
        occurredAt: toIsoMaybeRedshift(row.added_at),
        action: row.action_name || null,
        value: row.action_value || null,
        url: row.meta_url || null,
        path: row.url_path || null,
        referrer: row.referrer || null
      }));
    }

    let mailgunEvents = [];
    let eventPortalEmailEvents = [];
    if (email && emailEventsLimit > 0) {
      const r1 = await client.query(
        `select "time" as occurred_at, event
         from public.mailgun_events
         where lower(email)=lower($1)
         order by "time" desc
         limit ${emailEventsLimit};`,
        [email]
      );
      mailgunEvents = (r1.rows || []).map((row) => ({
        occurredAt: toIsoMaybeRedshift(row.occurred_at),
        event: row.event || null
      }));

      const r2 = await client.query(
        `select event_at as occurred_at, event
         from public.events_portal_email_events
         where lower(email)=lower($1)
         order by event_at desc
         limit ${emailEventsLimit};`,
        [email]
      );
      eventPortalEmailEvents = (r2.rows || []).map((row) => ({
        occurredAt: toIsoMaybeRedshift(row.occurred_at),
        event: row.event || null
      }));
    }

    const topPaths = summarizeTopCounts(
      pageviews.map((p) => p.path).filter(Boolean),
      8
    );
    const topHosts = summarizeTopCounts(
      pageviews.map((p) => p.host).filter(Boolean),
      5
    );
    const topActions = summarizeTopCounts(
      actions.map((a) => a.action).filter(Boolean),
      8
    );

    const webMostRecent =
      pageviews[0]?.occurredAt || actions[0]?.occurredAt || null;
    const emailMostRecent =
      mailgunEvents[0]?.occurredAt ||
      eventPortalEmailEvents[0]?.occurredAt ||
      null;

    return {
      // Do not include user IDs or system names (sales_prompt_utils will embed this into the model input).
      webActivity: {
        hasSignals: Boolean(webMostRecent),
        // "Recent" should reflect *current* buying signals, not historical browsing.
        recentSignals: webMostRecent ? isRecentIso(webMostRecent, 30) : false,
        mostRecentAt: webMostRecent,
        topHosts,
        topPaths,
        recentPageviews: pageviews.slice(0, 8),
        recentActions: actions.slice(0, 8)
      },
      emailEngagement: {
        hasSignals: Boolean(emailMostRecent),
        recentSignals: emailMostRecent
          ? isRecentIso(emailMostRecent, 30)
          : false,
        mostRecentAt: emailMostRecent,
        mailgunTopEvents: summarizeTopCounts(
          mailgunEvents.map((e) => e.event).filter(Boolean),
          6
        ),
        eventPortalTopEvents: summarizeTopCounts(
          eventPortalEmailEvents.map((e) => e.event).filter(Boolean),
          6
        ),
        recentMailEvents: mailgunEvents.slice(0, 10),
        recentEventPortalEmailEvents: eventPortalEmailEvents.slice(0, 10)
      }
    };
  });
}

module.exports = {
  getAnalyticsDbConfig,
  fetchAnalyticsBehavior
};
