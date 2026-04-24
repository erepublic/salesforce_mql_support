# MQL Flow Ownership Map

This document translates the flowchart into a repo-ownership view: which parts are maintained in this repository, which are upstream external systems, and which are partial Salesforce-side handoffs.

## High-level conclusion

This repo appears to own the Salesforce-centered decision engine and most of the downstream MQL workflow. It does not appear to own the broader marketing capture stack or the full upstream HubSpot, CMS, or portal applications.

## Ownership legend

- `Maintained in repo`: Salesforce metadata, Apex, Flows, objects, and automation defined here
- `Partial / handoff in repo`: Salesforce-side intake, conversion, or integration touchpoints that connect to external systems
- `External / upstream system`: marketing platforms, portals, CMS, and score generation systems that feed Salesforce

## Flow stages

### 1. Lead Capture

**External / upstream system**

- Web forms, ads, webinars, nurture, website engagement, and portal activity
- Most marketing capture and event generation

**Partial / handoff in repo**

- Contact Us and hand-raiser intake paths land in Salesforce
- Some Salesforce-side posting and conversion handoff exists

**Maintained in repo**

- Salesforce receives and stores intake records tied to later MQL processing

### 2. Qualification Engine

**External / upstream system**

- Behavior and fit score generation appears to come from HubSpot and connected systems

**Maintained in repo**

- Salesforce decision engine
- Threshold checks and qualification gates
- `Set_to_MQL__c` activation and MQL creation logic

### 3. MQL Creation and Routing

**External / upstream system**

- Upstream systems may provide source details and campaign context

**Maintained in repo**

- `MQL__c` object and field mapping
- Status assignment, opportunity linking, naming, owner routing, and alerts
- Hand-raiser and threshold-triggered creation paths

### 4. Sales Decision

**External / upstream system**

- Sales activity itself happens outside the repo

**Maintained in repo**

- Quick MQL screen flows
- Convert, reject, and add-to-opportunity flows
- Salesforce-side opportunity and contact role automation

### 5. Post-MQL Outcomes

**External / upstream system**

- Business outcomes and reporting consumption happen outside the codebase

**Maintained in repo**

- Lifecycle stage updates like `Active Opportunity` and `Recycled`
- Opportunity-stage-driven MQL and Contact automation
- Downstream status maintenance on Salesforce records

## Important boundary

The repo uses scoring fields heavily, but the actual scoring model and most marketing event production appear to live outside this repo.

## Evidence behind the mapping

- `force-app/main/default/classes/ContactSetToMqlTriggerHandler.cls`
  - Drives threshold and hand-raiser MQL creation
- `force-app/main/default/flows/Account_RT_AS_Set_Contacts_to_MQL.flow-meta.xml`
  - Converts scoring state into Salesforce qualification actions
- `force-app/main/default/flows/MQL_SF_Quick_MQL_Record.flow-meta.xml`
  - Supports sales-facing quick MQL actions
- `force-app/main/default/flows/MQL_SF_Convert_Reject_or_Add_to_Opportunity.flow-meta.xml`
  - Supports convert, reject, and add-to-opportunity decisions
- `force-app/main/default/flows/Opportunity_RT_AS_Update_MQL_Lifecycle_on_Stage_Change.flow-meta.xml`
  - Handles downstream lifecycle transitions
- `force-app/main/default/flows/Contact_Us_SF_Convert_to_MQL.flow-meta.xml`
  - Shows Salesforce-side conversion logic for Contact Us intake
- `force-app/main/default/objects/MQL__c/MQL__c.object-meta.xml`
  - Defines the core MQL business object
- `documentation/MQL_COHERENT_SPEC.md`
  - Documents system boundaries and the intended end-to-end process

## Short version

If you compare the original diagram to the repo, the best summary is:

- Most of the **green middle column** is maintained here
- Most of **steps 3 through 5** are maintained here
- Only limited Salesforce-side touchpoints of **step 1** appear here
- The broader **marketing capture and scoring systems** are mostly external
