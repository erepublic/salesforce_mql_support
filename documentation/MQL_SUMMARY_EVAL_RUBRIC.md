# MQL Engagement Summary Evaluation Rubric (Sales-Facing)

Source: `documentation/2025 Marketing Attribution Project.pdf` (Pipeline Creation 2.0)

This rubric is used to evaluate `MQL__c.Engagement_AI_Summary__c` in the sandbox org.
It is intentionally sales-facing and avoids technical or system-specific requirements.

## Primary Communication Goals (From Spec)

1. Increase Sales productivity

- Make the rep's next action obvious, low-effort, and time-aware (especially inbound requests).
- Reduce "hunting" in Salesforce by highlighting the few signals that matter.

2. Provide greater visibility and intelligence to Sales (pre and post MQL)

- Summarize the prospect's most recent engagement and why it matters.
- Surface the likely product(s)/offer(s) of interest when evidence exists.

3. Reinforce Fit + Intent model (qualitative)

- Explain Fit and Intent in plain language; do not require a rep to interpret raw scores.
- Make inbound "contact me" behave like an urgent signal, while still flagging fit concerns.

## Output Format Requirements (Current Implementation Contract)

Required sections (exact headings):

- `Why Sales Should Care`
- `Score Interpretation`
- `Most Recent Engagement`
- `Suggested Next Step`

HTML constraints:

- Must be an HTML fragment (no doctype/html/head/body).
- Simple tags only; no scripts/styles/CSS.
- No Salesforce/HubSpot object names, field names, IDs, or JSON keys in visible text.
- No numeric scores/threshold values; qualitative only (e.g. Strong/Moderate/Light).

## Scoring Checklist (Per Summary)

### A) Structure (Pass/Fail)

- All 4 required headings present.
- Each heading followed by a bullet list (`<ul><li>...`).
- `Most Recent Engagement` bullets are newest-first.
- Each engagement bullet starts with a date `YYYY-MM-DD - ...`.

### B) Sales Value (0-3)

3: Clear "signal -> implication -> angle" in the first section; rep understands why to care quickly.\n
2: Explains signals but misses the implication or value framing in places.\n
1: Mostly restates activity without meaning.\n
0: Generic filler; not tied to buying intent or account context.\n

### C) Fit + Intent Clarity (0-3)

3: Fit and Intent are both interpreted qualitatively and consistently; inbound urgency handled correctly.\n
2: Fit/Intent mentioned but uneven or mixed with vague language.\n
1: Mentions scoring but doesn't help the rep decide how to act.\n
0: Leaks raw field/score details or avoids interpretation.\n

### D) Conciseness (0-3)

3: Minimal repetition; bullets are short; stays within intended caps.\n
2: Slightly verbose but still scannable.\n
1: Repetitive or long bullets; effort to parse.\n
0: Excessively long; likely to be ignored.\n

Suggested caps (targets, not strict):

- Why Sales Should Care: 3-5 bullets
- Score Interpretation: 3-4 bullets
- Most Recent Engagement: 7-12 bullets
- Suggested Next Step: 1-2 bullets

### E) Product / Opportunity Specificity (0-3)

3: If evidence exists, it explicitly names what they're likely evaluating and references open opp context.\n
2: Names products but not clearly tied to why / next step.\n
1: Vague product interest or generic "solutions" language.\n
0: Misses clear signals that exist in the input.\n

### F) Compliance / Safety (Pass/Fail)

- No `__c`, `__r`, `HubSpot_`, `OpportunityContactRole`, or similar system tokens in visible text.
- No record IDs in visible text.
- No unsafe HTML (script/style/meta/link, inline style, event handlers).

## Optional: Related Record Links (If Present)

If the summary includes a link section, it should:

- Link to the Product record (when `MQL__c.Product__c` is present).
- Link to open Opportunity records (when present).
- Never show raw IDs in link text; IDs may only appear inside `href`.
