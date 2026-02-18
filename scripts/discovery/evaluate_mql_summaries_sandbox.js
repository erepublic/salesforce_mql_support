#!/usr/bin/env node
/**
 * Evaluate stored sandbox MQL summaries against a lightweight rubric.
 *
 * Source of truth: MQL__c.Engagement_AI_Summary__c (sandbox org).
 *
 * This script intentionally uses the Salesforce CLI (`sf`) for auth/queries.
 *
 * Usage:
 *   node scripts/discovery/evaluate_mql_summaries_sandbox.js --target-org mql-sandbox --since-days 365 --limit 200 --top 20
 */
/* eslint-disable no-console */

const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

function parseArgs(argv) {
  const args = {};
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
  return args;
}

function runSfJson(sfArgs) {
  const out = execFileSync("sf", [...sfArgs, "--json"], {
    encoding: "utf8",
    maxBuffer: 50 * 1024 * 1024
  });
  // sf can emit warning text before JSON; strip leading junk.
  const i = out.indexOf("{");
  const j = out.lastIndexOf("}");
  const raw = i >= 0 && j >= i ? out.slice(i, j + 1) : out;
  const parsed = JSON.parse(raw);
  if (parsed.status !== 0) throw new Error(parsed?.message || "sf CLI error");
  return parsed.result;
}

function queryRecords({ targetOrg, soql }) {
  const res = runSfJson([
    "data",
    "query",
    "--query",
    soql,
    "--target-org",
    targetOrg
  ]);
  return res?.records || [];
}

function safeInClause(ids) {
  const clean = (ids || []).filter(Boolean);
  if (!clean.length) return "(null)";
  const quoted = clean.map((id) => `'${String(id).replaceAll("'", "\\'")}'`);
  return `(${quoted.join(",")})`;
}

function nowStamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(
    d.getHours()
  )}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function stripTags(html) {
  return String(html || "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function sectionRange(html, heading) {
  const h = `<p><strong>${heading}</strong></p>`;
  const idx = html.indexOf(h);
  if (idx === -1) return null;
  const start = idx + h.length;
  // Treat Links as a real boundary so we don't mis-attribute its <li>s to
  // Suggested Next Step.
  const headings = [
    "Why Sales Should Care",
    "Score Interpretation",
    "Most Recent Engagement",
    "Suggested Next Step",
    "Links"
  ]
    .map((x) => `<p><strong>${x}</strong></p>`)
    .filter((x) => x !== h);
  let end = html.length;
  for (const next of headings) {
    const j = html.indexOf(next, start);
    if (j !== -1) end = Math.min(end, j);
  }
  return { start, end };
}

function listItemsInSection(html, heading) {
  const range = sectionRange(html, heading);
  if (!range) return [];
  const slice = html.slice(range.start, range.end);
  const items = [];
  const re = /<li>([\s\S]*?)<\/li>/gi;
  let m;
  while ((m = re.exec(slice))) items.push(stripTags(m[1]));
  return items.filter(Boolean);
}

function hasRequiredHeadings(html) {
  const required = [
    "Why Sales Should Care",
    "Score Interpretation",
    "Most Recent Engagement",
    "Suggested Next Step"
  ];
  return required.every((h) => html.includes(`<p><strong>${h}</strong></p>`));
}

function findLeaks(html) {
  const s = String(html || "");
  const leaks = [];
  if (/\bHubSpot_/i.test(s)) leaks.push("hubspot_token");
  if (/__c\b/.test(s) || /__r\b/.test(s)) leaks.push("sf_field_token");
  if (/\bOpportunityContactRole\b/.test(s)) leaks.push("sf_object_token");
  // Visible ID-ish tokens (exclude href content by removing it first).
  const hrefStripped = s.replace(/href\s*=\s*(['"])[\s\S]*?\1/gi, 'href=""');
  if (/\b(?:003|00Q|00T|006|a0X)[A-Za-z0-9]{12,15}\b/.test(hrefStripped))
    leaks.push("visible_sf_id");
  return leaks;
}

function countAnchors(html) {
  const s = String(html || "");
  const m = s.match(/<a\b/gi);
  return m ? m.length : 0;
}

function evaluateSummary(html) {
  const s = String(html || "");
  const out = {
    empty: !s.trim(),
    hasRequiredHeadings: hasRequiredHeadings(s),
    leaks: findLeaks(s),
    totalChars: s.length,
    anchorCount: countAnchors(s),
    sections: {}
  };

  const headings = [
    "Why Sales Should Care",
    "Score Interpretation",
    "Most Recent Engagement",
    "Suggested Next Step"
  ];
  for (const h of headings) {
    const items = listItemsInSection(s, h);
    out.sections[h] = { liCount: items.length };
    if (h === "Most Recent Engagement") {
      const dateOk = items.filter((x) =>
        /^\d{4}-\d{2}-\d{2}\s*-/.test(x)
      ).length;
      out.sections[h].datePrefixOkCount = dateOk;
    }
  }

  return out;
}

function summarizeEvaluations(rows) {
  const totals = {
    total: rows.length,
    nonEmpty: 0,
    headingsOk: 0,
    anyLeaks: 0,
    anyAnchors: 0,
    // Conciseness / formatting signals (rubric proxies)
    capBreaches: {
      whySalesTooMany: 0,
      scoreInterpTooMany: 0,
      engagementTooMany: 0,
      nextStepTooMany: 0,
      engagementMissingDatePrefix: 0,
      whySalesTooFew: 0,
      engagementTooFew: 0,
      nextStepTooFew: 0
    }
  };
  const byLeak = {};
  const sectionStats = {
    whySales: { min: Infinity, max: 0, sum: 0 },
    scoreInterp: { min: Infinity, max: 0, sum: 0 },
    engagement: { min: Infinity, max: 0, sum: 0 },
    nextStep: { min: Infinity, max: 0, sum: 0 }
  };

  const caps = {
    whySales: { min: 3, max: 5, heading: "Why Sales Should Care" },
    scoreInterp: { min: 3, max: 4, heading: "Score Interpretation" },
    engagement: { min: 7, max: 12, heading: "Most Recent Engagement" },
    nextStep: { min: 1, max: 2, heading: "Suggested Next Step" }
  };

  for (const r of rows) {
    if (!r.eval.empty) totals.nonEmpty += 1;
    if (r.eval.hasRequiredHeadings) totals.headingsOk += 1;
    if (r.eval.leaks.length) totals.anyLeaks += 1;
    if (r.eval.anchorCount > 0) totals.anyAnchors += 1;
    for (const l of r.eval.leaks) byLeak[l] = (byLeak[l] || 0) + 1;

    // Caps / section formatting checks (only when non-empty and has headings).
    if (!r.eval.empty && r.eval.hasRequiredHeadings) {
      const whyCnt = Number(
        r.eval.sections?.[caps.whySales.heading]?.liCount || 0
      );
      const scoreCnt = Number(
        r.eval.sections?.[caps.scoreInterp.heading]?.liCount || 0
      );
      const engCnt = Number(
        r.eval.sections?.[caps.engagement.heading]?.liCount || 0
      );
      const nextCnt = Number(
        r.eval.sections?.[caps.nextStep.heading]?.liCount || 0
      );

      function bumpStats(stats, n) {
        stats.min = Math.min(stats.min, n);
        stats.max = Math.max(stats.max, n);
        stats.sum += n;
      }

      bumpStats(sectionStats.whySales, whyCnt);
      bumpStats(sectionStats.scoreInterp, scoreCnt);
      bumpStats(sectionStats.engagement, engCnt);
      bumpStats(sectionStats.nextStep, nextCnt);

      if (whyCnt > caps.whySales.max) totals.capBreaches.whySalesTooMany += 1;
      if (whyCnt < caps.whySales.min) totals.capBreaches.whySalesTooFew += 1;
      if (scoreCnt > caps.scoreInterp.max)
        totals.capBreaches.scoreInterpTooMany += 1;
      if (engCnt > caps.engagement.max)
        totals.capBreaches.engagementTooMany += 1;
      if (engCnt < caps.engagement.min)
        totals.capBreaches.engagementTooFew += 1;
      if (nextCnt > caps.nextStep.max) totals.capBreaches.nextStepTooMany += 1;
      if (nextCnt < caps.nextStep.min) totals.capBreaches.nextStepTooFew += 1;

      const dateOkCount = Number(
        r.eval.sections?.[caps.engagement.heading]?.datePrefixOkCount || 0
      );
      if (engCnt > 0 && dateOkCount < engCnt)
        totals.capBreaches.engagementMissingDatePrefix += 1;
    }
  }

  function finalizeStats(stats) {
    const count = totals.headingsOk || 0;
    if (!Number.isFinite(stats.min)) stats.min = 0;
    const avg = count ? Math.round((stats.sum / count) * 10) / 10 : 0;
    return { min: stats.min, max: stats.max, avg };
  }

  return {
    totals,
    byLeak,
    sectionStats: {
      whySales: finalizeStats(sectionStats.whySales),
      scoreInterp: finalizeStats(sectionStats.scoreInterp),
      engagement: finalizeStats(sectionStats.engagement),
      nextStep: finalizeStats(sectionStats.nextStep)
    },
    caps
  };
}

async function main() {
  const args = parseArgs(process.argv);
  const targetOrg = args["target-org"] || "mql-sandbox";
  const sinceDays = Math.max(
    1,
    Math.min(365, Number(args["since-days"] || 365))
  );
  const limit = Math.max(10, Math.min(500, Number(args.limit || 200)));
  const top = Math.max(5, Math.min(100, Number(args.top || 25)));
  const jsonOnly = args["json-only"] === true;

  // Reuse the existing ranking script to pick "signal-rich" MQLs.
  const rankedRaw = execFileSync(
    "node",
    [
      path.join("scripts", "discovery", "find_good_mql_samples.js"),
      "--target-org",
      targetOrg,
      "--since-days",
      String(sinceDays),
      "--limit",
      String(limit),
      "--top",
      String(top),
      "--json-only"
    ],
    { encoding: "utf8", maxBuffer: 10 * 1024 * 1024 }
  );
  const ranked = JSON.parse(String(rankedRaw || "{}"));
  const ids = (ranked?.results || []).map((r) => r.mqlId).filter(Boolean);
  if (!ids.length) {
    const payload = {
      metadata: {
        targetOrg,
        sinceDays,
        limit,
        top,
        generatedAt: new Date().toISOString()
      },
      totals: { total: 0 }
    };
    if (jsonOnly) process.stdout.write(JSON.stringify(payload));
    else console.log(JSON.stringify(payload, null, 2));
    return;
  }

  const soql =
    "SELECT Id, CreatedDate, LastModifiedDate, Lead_Source__c, MQL_Status__c, Product__c, Opportunity__c, Engagement_AI_Summary__c " +
    `FROM MQL__c WHERE Id IN ${safeInClause(ids)} ORDER BY CreatedDate DESC LIMIT ${Math.min(
      ids.length,
      2000
    )}`;
  const mqls = queryRecords({ targetOrg, soql });
  const mqlById = new Map(mqls.map((m) => [m.Id, m]));

  const evaluated = ids.map((id) => {
    const m = mqlById.get(id) || {};
    const html = m.Engagement_AI_Summary__c || "";
    return {
      mqlId: id,
      createdDate: m.CreatedDate || null,
      leadSource: m.Lead_Source__c || null,
      status: m.MQL_Status__c || null,
      productId: m.Product__c || null,
      opportunityId: m.Opportunity__c || null,
      eval: evaluateSummary(html)
    };
  });

  const agg = summarizeEvaluations(evaluated);
  const payload = {
    metadata: {
      generatedAt: new Date().toISOString(),
      targetOrg,
      sinceDays,
      limit,
      top
    },
    totals: agg.totals,
    byLeak: agg.byLeak,
    sectionStats: agg.sectionStats,
    caps: agg.caps,
    // Keep details bounded; include worst offenders for debugging.
    worst: {
      empty: evaluated.filter((r) => r.eval.empty).slice(0, 10),
      missingHeadings: evaluated
        .filter((r) => !r.eval.empty && !r.eval.hasRequiredHeadings)
        .slice(0, 10),
      leaking: evaluated.filter((r) => r.eval.leaks.length).slice(0, 10),
      capBreaches: {
        nextStepTooMany: evaluated
          .filter(
            (r) =>
              !r.eval.empty &&
              r.eval.hasRequiredHeadings &&
              Number(r.eval.sections?.["Suggested Next Step"]?.liCount || 0) > 2
          )
          .slice(0, 10),
        engagementMissingDatePrefix: evaluated
          .filter((r) => {
            if (r.eval.empty || !r.eval.hasRequiredHeadings) return false;
            const engCnt = Number(
              r.eval.sections?.["Most Recent Engagement"]?.liCount || 0
            );
            const okCnt = Number(
              r.eval.sections?.["Most Recent Engagement"]?.datePrefixOkCount ||
                0
            );
            return engCnt > 0 && okCnt < engCnt;
          })
          .slice(0, 10),
        engagementTooFew: evaluated
          .filter(
            (r) =>
              !r.eval.empty &&
              r.eval.hasRequiredHeadings &&
              Number(
                r.eval.sections?.["Most Recent Engagement"]?.liCount || 0
              ) < 7
          )
          .slice(0, 10)
      }
    }
  };

  const outDir = path.resolve(
    process.cwd(),
    ".local",
    "reports",
    "mql_summary_eval"
  );
  ensureDir(outDir);
  const outPath = path.join(outDir, `${nowStamp()}_${targetOrg}.json`);
  fs.writeFileSync(outPath, JSON.stringify(payload, null, 2));

  if (jsonOnly) {
    process.stdout.write(JSON.stringify({ ...payload, outputPath: outPath }));
    return;
  }

  console.log(JSON.stringify({ ...payload, outputPath: outPath }, null, 2));
}

main().catch((e) => {
  console.error(e?.message || e);
  process.exit(1);
});
