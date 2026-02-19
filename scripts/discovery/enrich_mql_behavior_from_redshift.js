#!/usr/bin/env node
/**
 * Enrich MQL test candidates with behavior from Redshift.
 *
 * Strategy:
 * - Start from our existing HubSpot-enriched MQL contact list (JSON produced by
 *   scripts/discovery/enrich_all_mql_contacts_with_hubspot.js).
 * - Use HubSpot contact id to map -> Redshift user id via public.nav2016_user.hubspot_contact_id
 * - Pull most recent browsing events from:
 *    - public.navigator_pageviews (visited_at, url_host, url_path, referrer, utm)
 *    - public.navigator_actions (added_at, action_name, meta_url/url_path)
 * - Pull email events from:
 *    - public.mailgun_events (opened/clicked/delivered)
 *    - public.events_portal_email_events (delivered/opened etc)
 *
 * Output:
 * - Writes JSON to .local/discovery/redshift_behavior/<timestamp>_<targetOrg>.json
 *
 * Notes:
 * - Uses psql (libpq) and relies on ~/.pgpass for credentials.
 */

/* eslint-disable no-console */
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const DEFAULT_PSQL = "/opt/homebrew/opt/libpq/bin/psql";
const DEFAULT_CONN =
  "host=erepublic.c5gqkbl2bpv4.us-west-1.redshift.amazonaws.com port=5439 dbname=analytics user=redshift_service_all sslmode=require";

function parseArgs(argv) {
  const args = {
    targetOrg: "mql-sandbox",
    input: null,
    maxContacts: 20,
    pageviewsLimit: 25,
    actionsLimit: 25,
    mailgunLimit: 25,
    eventPortalEmailLimit: 25
  };
  for (let i = 2; i < argv.length; i++) {
    const t = argv[i];
    if (!t.startsWith("--")) continue;
    const k = t.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) args[k] = true;
    else {
      args[k] = next;
      i++;
    }
  }
  if (args["target-org"]) args.targetOrg = String(args["target-org"]).trim();
  if (args.input) args.input = String(args.input);
  if (args["max-contacts"] != null)
    args.maxContacts = Number(args["max-contacts"]);
  if (args["pageviews-limit"] != null)
    args.pageviewsLimit = Number(args["pageviews-limit"]);
  if (args["actions-limit"] != null)
    args.actionsLimit = Number(args["actions-limit"]);
  if (args["mailgun-limit"] != null)
    args.mailgunLimit = Number(args["mailgun-limit"]);
  if (args["event-portal-email-limit"] != null)
    args.eventPortalEmailLimit = Number(args["event-portal-email-limit"]);
  return args;
}

function nowStamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(
    d.getHours()
  )}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function sqlLiteral(s) {
  if (s === null || s === undefined) return "null";
  return `'${String(s).replaceAll("'", "''")}'`;
}

function runPsql({ psqlPath, conn, sql, statementTimeoutMs = 15000 }) {
  const cmd = psqlPath || DEFAULT_PSQL;
  const args = [
    "-X", // no ~/.psqlrc side effects
    "-v",
    "ON_ERROR_STOP=1",
    "-A",
    "-t",
    "-F",
    "\t",
    conn || DEFAULT_CONN,
    "-c",
    `set statement_timeout to ${Math.max(1000, Math.floor(statementTimeoutMs))}; ${sql}`
  ];
  return execFileSync(cmd, args, {
    encoding: "utf8",
    env: { ...process.env, PGCONNECT_TIMEOUT: "10" },
    stdio: ["ignore", "pipe", "pipe"]
  });
}

function parseTsvRows(tsv, cols) {
  const lines = String(tsv || "")
    .split(/\r?\n/)
    .map((l) => l.trimEnd())
    .filter((l) => l.length > 0)
    // psql prints command status rows even with -t, e.g. "SET"
    .filter((l) => !["SET", "BEGIN", "COMMIT"].includes(l.trim()));
  return lines.map((l) => {
    const parts = l.split("\t");
    const o = {};
    for (let i = 0; i < cols.length; i++) o[cols[i]] = parts[i] ?? null;
    return o;
  });
}

function getLatestInputFile({ targetOrg }) {
  const dir = path.resolve(
    process.cwd(),
    ".local",
    "discovery",
    "hubspot_enriched_all_mql_contacts"
  );
  if (!fs.existsSync(dir)) return null;
  const files = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(`_${targetOrg}.json`))
    .map((f) => ({
      f,
      mtimeMs: fs.statSync(path.join(dir, f)).mtimeMs
    }))
    .sort((a, b) => b.mtimeMs - a.mtimeMs);
  if (!files.length) return null;
  return path.join(dir, files[0].f);
}

function buildUrl({ host, path: p, query }) {
  const h = host || "";
  const pp = p || "";
  if (!h && !pp) return null;
  const q = query ? `?${query}` : "";
  return `https://${h}${pp}${q}`;
}

function summarizeTopCounts(values, topN = 5) {
  const m = new Map();
  for (const v of values || []) {
    if (!v) continue;
    m.set(v, (m.get(v) || 0) + 1);
  }
  return Array.from(m.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, topN)
    .map(([value, count]) => ({ value, count }));
}

async function main() {
  const args = parseArgs(process.argv);
  const inputPath =
    args.input || getLatestInputFile({ targetOrg: args.targetOrg });
  if (!inputPath)
    throw new Error("Missing --input and no default input file found.");

  const input = JSON.parse(fs.readFileSync(inputPath, "utf8"));
  const candidates = Array.isArray(input?.results) ? input.results : [];
  const limited = candidates.slice(0, Math.max(1, args.maxContacts));

  const enriched = [];

  for (const c of limited) {
    const email = c?.email || null;
    const hsContactId = c?.hsContactId || c?.hubspot?.hsContactId || null;
    const mqlId = c?.latestMql?.id || null;

    // 1) HubSpot id -> Redshift user id (Navigator).
    let navUser = null;
    if (hsContactId) {
      const userRows = parseTsvRows(
        runPsql({
          sql: `select id, email, last_login_at from public.nav2016_user where hubspot_contact_id = ${sqlLiteral(
            hsContactId
          )} limit 1;`
        }),
        ["id", "email", "last_login_at"]
      );
      navUser = userRows[0] || null;
    }
    // Fallback: map by email if HubSpot id doesn't map (common for non-Navigator HubSpot contacts).
    if (!navUser && email) {
      const userRows = parseTsvRows(
        runPsql({
          sql: `select id, email, last_login_at from public.nav2016_user where lower(email)=lower(${sqlLiteral(
            email
          )}) limit 1;`
        }),
        ["id", "email", "last_login_at"]
      );
      navUser = userRows[0] || null;
    }

    const navUserId = navUser?.id ? Number(navUser.id) : null;

    // 2) Pull browsing behavior.
    let pageviews = [];
    let actions = [];
    if (navUserId) {
      pageviews = parseTsvRows(
        runPsql({
          sql: `select visited_at, url_host, url_path, url_query, referrer, meta_utm_source, meta_utm_medium, meta_utm_campaign
                from public.navigator_pageviews
                where user_id = ${navUserId}
                order by visited_at desc
                limit ${Math.max(1, Math.min(200, args.pageviewsLimit))};`,
          statementTimeoutMs: 20000
        }),
        [
          "visited_at",
          "url_host",
          "url_path",
          "url_query",
          "referrer",
          "utm_source",
          "utm_medium",
          "utm_campaign"
        ]
      ).map((r) => ({
        occurredAt: r.visited_at,
        urlHost: r.url_host,
        urlPath: r.url_path,
        url: buildUrl({ host: r.url_host, path: r.url_path, query: null }),
        referrer: r.referrer,
        utm: {
          source: r.utm_source,
          medium: r.utm_medium,
          campaign: r.utm_campaign
        }
      }));

      actions = parseTsvRows(
        runPsql({
          sql: `select added_at, action_name, action_value, meta_url, url_path, referrer
                from public.navigator_actions
                where user_id = ${navUserId}
                order by added_at desc
                limit ${Math.max(1, Math.min(200, args.actionsLimit))};`,
          statementTimeoutMs: 20000
        }),
        [
          "added_at",
          "action_name",
          "action_value",
          "meta_url",
          "url_path",
          "referrer"
        ]
      ).map((r) => ({
        occurredAt: r.added_at,
        action: r.action_name,
        value: r.action_value,
        url:
          r.meta_url ||
          (r.url_path
            ? `https://www.governmentnavigator.com${r.url_path}`
            : null),
        referrer: r.referrer
      }));
    }

    // 3) Pull email engagement behavior (these tables are keyed by email).
    let mailgunEvents = [];
    let eventPortalEmailEvents = [];
    if (email) {
      mailgunEvents = parseTsvRows(
        runPsql({
          sql: `select "time", event
                from public.mailgun_events
                where lower(email)=lower(${sqlLiteral(email)})
                order by "time" desc
                limit ${Math.max(1, Math.min(200, args.mailgunLimit))};`,
          statementTimeoutMs: 20000
        }),
        ["occurred_at", "event"]
      ).map((r) => ({ occurredAt: r.occurred_at, event: r.event }));

      eventPortalEmailEvents = parseTsvRows(
        runPsql({
          sql: `select event_at, event
                from public.events_portal_email_events
                where lower(email)=lower(${sqlLiteral(email)})
                order by event_at desc
                limit ${Math.max(1, Math.min(200, args.eventPortalEmailLimit))};`,
          statementTimeoutMs: 20000
        }),
        ["occurred_at", "event"]
      ).map((r) => ({ occurredAt: r.occurred_at, event: r.event }));
    }

    const allPaths = pageviews.map((p) => p.urlPath).filter(Boolean);
    const allHosts = pageviews.map((p) => p.urlHost).filter(Boolean);
    const allActionNames = actions.map((a) => a.action).filter(Boolean);

    enriched.push({
      mqlId,
      contactId: c?.contactId || null,
      email,
      hsContactId,
      redshift: {
        navUser: navUser
          ? {
              id: navUserId,
              email: navUser.email || null,
              lastLoginAt: navUser.last_login_at || null
            }
          : null,
        pageviewsSummary: {
          count: pageviews.length,
          mostRecent: pageviews[0]?.occurredAt || null,
          topHosts: summarizeTopCounts(allHosts, 5),
          topPaths: summarizeTopCounts(allPaths, 8)
        },
        actionsSummary: {
          count: actions.length,
          mostRecent: actions[0]?.occurredAt || null,
          topActions: summarizeTopCounts(allActionNames, 8)
        },
        emailSummary: {
          mailgunCount: mailgunEvents.length,
          mailgunMostRecent: mailgunEvents[0]?.occurredAt || null,
          mailgunTopEvents: summarizeTopCounts(
            mailgunEvents.map((e) => e.event),
            6
          ),
          eventPortalEmailCount: eventPortalEmailEvents.length,
          eventPortalMostRecent: eventPortalEmailEvents[0]?.occurredAt || null,
          eventPortalTopEvents: summarizeTopCounts(
            eventPortalEmailEvents.map((e) => e.event),
            6
          )
        },
        samples: {
          pageviews,
          actions,
          mailgunEvents,
          eventPortalEmailEvents
        }
      }
    });
  }

  const outDir = path.resolve(
    process.cwd(),
    ".local",
    "discovery",
    "redshift_behavior"
  );
  ensureDir(outDir);
  const outPath = path.join(outDir, `${nowStamp()}_${args.targetOrg}.json`);
  fs.writeFileSync(
    outPath,
    JSON.stringify(
      {
        metadata: {
          generatedAt: new Date().toISOString(),
          targetOrg: args.targetOrg,
          inputPath: path.relative(process.cwd(), inputPath),
          limits: {
            maxContacts: args.maxContacts,
            pageviewsLimit: args.pageviewsLimit,
            actionsLimit: args.actionsLimit,
            mailgunLimit: args.mailgunLimit,
            eventPortalEmailLimit: args.eventPortalEmailLimit
          },
          redshift: {
            conn: "analytics (redshift) via psql + ~/.pgpass"
          }
        },
        results: enriched
      },
      null,
      2
    )
  );

  console.log(outPath);
  console.log(
    JSON.stringify(
      {
        count: enriched.length,
        withNavUser: enriched.filter((e) => e.redshift?.navUser?.id).length,
        withPageviews: enriched.filter(
          (e) => (e.redshift?.pageviewsSummary?.count || 0) > 0
        ).length,
        withActions: enriched.filter(
          (e) => (e.redshift?.actionsSummary?.count || 0) > 0
        ).length,
        withMailgun: enriched.filter(
          (e) => (e.redshift?.emailSummary?.mailgunCount || 0) > 0
        ).length
      },
      null,
      2
    )
  );
}

main().catch((e) => {
  console.error(e?.message || e);
  process.exit(1);
});
