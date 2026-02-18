# MQL Process Coherent Specification

Last updated: 2026-02-10  
Prepared from: email threads, Salesforce tickets, and local system spec PDF

## 1) Purpose

This document consolidates the evolving MQL requirements into one implementation-focused specification that can be used by Salesforce Ops, Marketing Ops, and Development as the current reference point.

It resolves scattered decisions across email and ticket threads by separating:

- **Current agreed behavior** (what should be implemented now)
- **Recent changes** (what changed over time and why)
- **Open questions** (items still needing product/business decisions)

## 2) Scope and System Boundaries

- **Primary systems:** Salesforce, HubSpot, e.Republic CMS, Events Portal
- **Core business object:** `MQL` (with conversion and lifecycle linkage to Contact and Opportunity)
- **Primary intent:** Move from direct hand-raiser Opportunity creation to a contact-based MQL qualification flow, while preserving sales visibility and fast routing

## 3) Current State (Authoritative Baseline)

This section reflects the most complete current design from the sandbox system specs and late-cycle implementation tickets.

### 3.1 MQL Creation Triggers

MQL creation can be triggered by:

- Contact `Set_to_MQL__c` changing to `True`
- Prior lead-opportunity-like intake paths (Navigator/Insider forms, Events Portal requests) now routed through MQL logic

Qualification gate:

- Contact `Private_Sector_Non_Qual__c = False`
- Account `Private_Sector_Non_Qual__c = False`

### 3.2 Create Decision Matrix

Create both MQL + Opportunity when:

- Contact and Account are qualified, and
- Contact is **not** on any open Opportunity via OCR

Create MQL only when:

- `Set_to_MQL__c = True`, or
- Contact and Account are qualified, but Contact is already on an open Opportunity

Create Opportunity only when:

- Contact or Account is non-qualified

### 3.3 MQL Field Mapping and Population

Lead Opportunity to MQL mappings include:

- `Name -> MQL_Name__c`
- `CampaignId -> Campaign__c`
- `OwnerId -> OwnerId`
- `LeadSource -> Lead_Source__c`
- `Lead_Source_Detail__c -> Lead_Source_Detail__c`
- `Lead_Detail_1..4__c -> Lead_Detail_1..4__c`
- `Lead_Notes__c -> Lead_Notes__c`

Other required/derived values:

- `MQL_Date__c = Today`
- `Contact__c` lookup required
- `Product__c` set from trigger context
  - Threshold path uses `Lead Opportunity - MQL Threshold` product
- `Engagement_AI_Summary__c` mapped from Contact when threshold-triggered
- `Lead_Source__c = "Fit and Behavior Threshold Reached"` for threshold-triggered MQLs

If MQL and Opportunity are created together:

- `MQL_Status__c = Converted`
- `Conversion_Date__c = Today`
- `Conversion_Type__c = Created Opportunity`
- `Opportunity__c` linked
- `Converted_By__c = Automation`

### 3.4 Lifecycle Automation

Implemented/defined flow behavior:

- Set to MQL logic checks qualification, recent behavior, open-opportunity status, and recent MQL/recycle state
- MQL naming automation with truncation rules to stay <= 120 chars
- Owner reassignment based on account ownership logic and internal-account exceptions
- New MQL alert/update flow updates Contact MQL Date and lifecycle state
- Opportunity stage-change flow sets lifecycle:
  - Open stage -> `Active Opportunity`
  - Closed stage with no other open opp -> `Recycled`, set recycle date, reset behavior score to 0
- Opportunity Contact Role create/delete flows mirror lifecycle changes with the same recycle/reset behavior

### 3.5 User Actions (Screen Flows / Buttons)

- **Quick Lead (Global):** create Contact if needed; suggest MQL vs Opportunity; allow single/multi product
- **MQL actions:** Convert (1:1 to Opp), Reject (bulk same reason), Add to Opportunity
- **Contact Us action:** convert to MQL, Opportunity, or both based on qualification and active opp status

## 4) Scoring and Data Requirements

### 4.1 Scoring Model Direction

Business consensus moved toward dual-track scoring synced from HubSpot:

- Behavior score
- Contact fit score
- Company fit score

Additional engagement score and threshold fields were created for Salesforce visibility.

### 4.2 Scoring Data Inputs (Agreed Required Inputs)

Confirmed/iterated requirements included:

- Event Portal form submissions
- Event Portal logins
- Marketing webinar attendance (workflow-based handling used)
- CMS marketing forms (Navigator/Insider/demo/trial forms)
- Contact Us submissions
- Website and email engagement signals

### 4.3 Important Requirement Changes

- Contact Us was temporarily constrained to `Sales & Advertising`, then later updated to include **all Contact Us topics** in behavioral scoring path.
- Company Fit scoring moved from Contact to Account-level field strategy.
- Event portal "clicked sponsor link" behaviors were clarified as known-contact events (not anonymous-only unknown traffic).

## 5) Integration Contract (Operational Expectations)

### 5.1 HubSpot <-> Salesforce

- HubSpot score and lifecycle-related fields sync into Salesforce Contact/Account fields
- Sync latency is expected to be short for incremental updates, but capacity/rate constraints must be monitored
- Production-first sync approach was used for speed in this project phase

### 5.2 CMS / Portal Event Posting to HubSpot

Implementation covered:

- Contact Us submission posting to HubSpot
- Portal login and form activity posting to designated HubSpot forms
- CMS demo/trial form posting to specific HubSpot forms
- Bug-fix cycle completed with cross-team QA before ticket closure

## 6) Non-Functional and Reporting Considerations

- Sales timing sensitivity: routing delays can impact conversion outcomes
- Data retention is still a broader policy gap and remains organizationally unresolved
- MQL->SQL/progression reporting needs robust stage-traversal logic that does not assume every stage is touched in sequence
- Campaign attribution on MQLs has an active follow-on project phase

## 7) Open Questions (Needs Decision)

1. Final threshold formulas and weighting governance:
   - Which scoring components can Marketing tune directly vs require change control?
2. New Prospects account handling:
   - How to avoid systemic Company Fit penalties for records without full firmographic coverage?
3. AI summary output standard:
   - Final prompt/output format and expected consumer workflow for Sales
4. Attribution source of truth:
   - Primary reporting system for campaign influence (HubSpot, Salesforce, or blended model)
5. Lifecycle SLA definitions:
   - Explicit response-time targets once MQL is activated and assigned

## 8) Chronology of Key Requirement Evolution

- **Aug 2025:** architecture and philosophy discussions (lead vs contact model, data retention concern, integration direction)
- **Aug-Oct 2025:** HubSpot scoring design matures (fit + behavior), required source events expanded, Contact Us and portal behaviors clarified
- **Oct 2025:** Salesforce schema updates for score visibility, AI summary field introduced, integration QA on CMS/portal posting
- **Nov 2025:** Next-phase recommendations and technical spec drafting across object/field/automation scope
- **Jan 2026:** sandbox foundation complete; remaining suppression/unqualified/lifecycle edge cases identified for alignment
- **Feb 2026:** consolidated sandbox MQL system spec published; phase 2 campaign attribution started

## 9) Source Index

### Local project docs

- `documentation/Specs - MQL Creation and Field Mappings.pdf` (Author: Lauren Fahndrich, Last Modified: 2026-02-04)

### Key email threads

- `MQL System Specs & Resources (Sandbox)` (2026-02-04 / 2026-02-05)
- `MQL Status Update` (2026-01-24 onward)
- `Continue MQL Discussion` (2025-08 through 2025-10)
- `MQL Project - Next Phase Recommendations` (2025-11-05)
- BRD comment-notification emails referencing `ER MQL and Lead Process BRD.docx` (Nov 2025)

### Key Salesforce tickets

- `a0wJw00000DiC2nIAF` - Technical Specs: Contact MQL to Opportunity Conversion Flow
- `a0wJw00000FfowHIAR` - Sandbox: MQL Objects and Automation Build
- `a0wJw00000DIDs9IAH` - MQL data requirements needed in HubSpot for lead scores
- `a0wJw00000EutS3IAJ` - Update to MQL data requirements (Contact Us scoring scope update)
- `a0wJw00000Dl2DNIAZ` - Contact object score fields
- `a0wJw00000Dwz8TIAR` - Account object company fit score correction
- `a0wJw00000DbifJIAR` - Build HubSpot engagement score
- `a0wRo000005pZs5IAE` - MQL Project Phase 2 Campaign Attribution

## 10) Recommended Next Actions

1. Approve this as the canonical written baseline for build and QA.
2. Hold a short decision workshop on Section 7 open items.
3. Produce a test matrix from this spec (happy path + lifecycle edge cases + sync latency checks).
4. Create a change-control appendix for future scoring rule edits.
