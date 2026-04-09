# MQL Follow-Ups

## Email / Summary UX Improvements

- Reorder the MQL summary so reps see the factual engagement first:
  - `Most Recent Engagement`
  - `Suggested Next Step`
  - `Why Sales Should Care`
  - `Score Interpretation`
- Shorten the email output overall:
  - cap `Why Sales Should Care` to 1-2 bullets in email output
  - cap `Suggested Next Step` to 1 practical bullet when possible
  - keep `Most Recent Engagement` focused on the strongest 3-5 items
- Make account-level commentary conditional:
  - suppress or compress "existing customer / active account" commentary for accounts that are already well-known and actively managed
  - keep fuller AI commentary for net-new, dormant, or low-context accounts

## Engagement Specificity Fixes

- Never show raw Salesforce IDs in seller-facing engagement bullets.
- Detect Salesforce-style record IDs in web activity paths, supplemental evidence, and action values before rendering labels.
- If the system can resolve the record name, use the resolved human-readable label.
- If the system cannot resolve the record name, do not surface the raw ID; prefer either:
  - dropping the bullet entirely, or
  - using a generic fallback only when it is still useful
- Treat unresolved internal IDs as a data-quality / enrichment failure, not as acceptable rep-facing output.

## Event Portal Specificity

- Enrich event-portal actions with the exact event name before the summary is generated.
- Replace generic wording like `Clicked Sponsor Link and Logged In` with event-specific wording whenever the event can be determined.
- If the event cannot be determined, avoid generic rep-facing text that implies specificity when it does not exist.

## Implementation Strategy

- Fix specificity upstream in deterministic normalization code first, not only in the model prompt.
- Improve the engagement bullet builders in `infra/terraform/mql/lambda_src/sales_prompt_utils.js`.
- Keep the LLM focused on summarizing already-clean evidence rather than repairing vague or technical inputs.
- Add explicit guardrails so unresolved IDs / internal codes are either enriched or suppressed before they reach the output.

## Testing / Validation

- Add regression tests proving raw Salesforce IDs never appear in seller-facing engagement highlights.
- Add regression tests for event portal actions that require event-name enrichment.
- Add tests for engagement ordering / brevity once the section-order change is made.
- Re-generate the known bad MQLs and review the resulting `Engagement_AI_Summary__c` output directly in sandbox.

## Safe Regeneration Guardrails

- Do not update `Initial_MQL_Alert_Send__c` while testing summary regeneration.
- Use the summary regeneration path only:
  - `MqlSummarizerAdmin.regenerateFromFlow(...)`, or
  - `MqlSummarizerCallout.triggerSummarizationForce(...)`
- Re-generate only the specific problem MQL records needed for validation.
- Validate outputs by querying `Engagement_AI_Summary__c`; do not trigger fresh sales alert emails.
