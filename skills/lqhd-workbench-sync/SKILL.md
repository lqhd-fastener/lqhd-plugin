---
name: lqhd-workbench-sync
description: Ingest client development results into the LQHD workbench (lqhd-mcp-server) with idempotency and data-quality guarantees. Covers country/client report ingestion, state and coordinate enrichment, new-country setup (config, boundaries, region names, ports) and read-only database audits. Use when the user asks to insert/upload/ingest reports or leads into the workbench, set up a new country, fix state/coordinates, or audit/check workbench data quality.
---

# Workbench Data Sync & Quality

Responsible for the **data side** of the LQHD client development loop: ingesting leads, scores and reports into the workbench (`lqhd-mcp-server`), enriching them (state, coordinates), setting up new countries end-to-end, and running read-only audits to guarantee data quality. It works together with `lqhd-report-agent` (which produces the reports) and `lqhd-mail-delivery` (which handles the sending side); this skill never sends emails.

> Golden rules: **idempotency first** (re-running an ingestion must never create duplicates), **honest reporting** (a failed insert/pull is reported as a failure, never fabricated), and **write through MCP tools** (do not hand-write SQL or one-off scripts when a tool exists).

## 1. Know the Workbench Toolset

`lqhd-mcp-server` exposes ~18 tools. Identify exact names from the runtime schema; by purpose they are:

| Purpose | Tools (runtime names may differ slightly) |
|---------|-------------------------------------------|
| Read / audit | get-customer-by-id, query-customers, list-customers, query-contacts, query-emails, audit-database |
| Create / update one | create-customer, update-customer, create-contact, batch-create-contacts, batch-update-contacts |
| Batch ingestion (main workhorse) | batch-upsert-customers, batch-update-customers |
| Country & static data | upsert-country, upsert-app-data |
| Reports & email records | register-report, mark-email, send-email |

Key contracts:

- **Customer external key**: `indexCode` (format LQHD-xxxx). Customer reference parameters accept the index code or numeric ID.
- **Idempotency key**: normalized company name (`companyKey`, uppercase + Unicode alphanumeric). Re-ingesting the same company updates instead of duplicating.
- `Country.reportDate` is a **String** ('YYYY-MM-DD'), not a datetime.

## 2. Ingest a Country Client Report

Input: a country lead/background report (Markdown) containing a **CSV-ready lead table** (a fenced csv code block with one row per client).

1. **Parse the CSV-ready table first** (it is clean: no `**` bold markers). Only fall back to the report's ranking section if the CSV block is missing — and in that case strip `**` markers from company names and tiers before ingesting.
2. Validate before writing: six scoring sub-scores must add up to the total score; CSV column counts must be consistent per row.
3. Call the batch-upsert tool (e.g. `batch-upsert-customers`): it should pre-check dedup keys and country completeness, auto-create a missing country, register the report, upsert clients idempotently, and optionally attach coordinates.
4. Idempotency rules: already-existing clients get score/tier fields updated only — never overwrite `devStatus`, `indexCode`, emails or email records.
5. **Exclusion rule**: clients with score < 45 are marked `tier=排除` (excluded) and `competitor=true`; their websites land in the "competitor/watch" filter rather than the prospect pool.
6. Call the report-registration tool (e.g. `register-report`) to record the report and its client associations.

## 3. Enrich After Ingestion (State & Coordinates)

1. **State normalization**: only countries with a configured ADM1 mapping get standardized `state` codes automatically. New countries often end up with `state=null` for the whole batch — check after every ingestion.
2. For unmapped states, use the batch-update tool (e.g. `batch-update-customers`) with the report's Region column to fill `state` (standardized code, e.g. `CA-ON`) and `stateRaw` (original text, e.g. `Ontario`). Use fill-empty-only mode to avoid overwriting verified values; strip stray `**` from company names while at it.
   - Without a valid `state`, CRM province filtering and map highlighting silently fail — treat this as part of ingestion, not an optional extra.
3. **Coordinates**: map pins need `latitude/longitude`. Reports rarely include them; prepare a `company name -> {lat, lng}` mapping and pass it through the batch tooling (or update per client).

## 4. Set Up a New Country End-to-End

Full flow (all via MCP tools, no image rebuild, no static JS files):

```
1. upsert-country        → create/fix the country (Chinese name, true geographic center, zoom;
                           large countries like BR/AU/US use zoom 4)
                           · Passing only the code auto-repairs a broken config
                           · regionLabel must be the first-level admin division name
                             (state/province/region), NOT the country name
2. upsert-app-data       → write boundaries:<CC> (boundary polygons), region-names
                           (Chinese admin-division names) and ports — refresh the page
                           and they take effect; static data/*.js files are fallbacks only
3. batch-upsert-customers → ingest clients (Section 2)
4. batch-update-customers → fill state/stateRaw and coordinates (Section 3)
5. audit-database        → read-only health check (Section 5)
6. register-report       → register the report and associations
```

## 5. Audit Criteria (Read-Only Health Check)

Run the audit tool (e.g. `audit-database`) after ingestion and report findings honestly:

- `zoom === 6` is **not** an anomaly by itself (most countries legitimately use it) — do not report it as an error.
- Boundaries / region-names / ports must be judged by **content being non-empty**, not merely by the key existing (key-with-empty-value is the common failure).
- Check `state` coverage per country; flag whole-batch nulls.
- Flag duplicate `companyKey`s (should be impossible via idempotent upsert) and clients with emails but zero email records when a campaign was expected.

## 6. Email Records (Registration Only)

- Register sends with the mark-email tool: it records `EmailRecord` (unique per customer + stage + recipient), writes back the server `messageId`, can flip status to BOUNCED (with the SMTP reason in `note`), and automatically advances a customer's `devStatus` from NEW to CONTACTED.
- Never fabricate a send. If a send is requested, hand over to `lqhd-mail-delivery` (probe → send → bounce check), then register here.

## Output Contract

Return to the team lead (verbatim): per-table row counts ingested/updated/skipped, countries created or fixed, state/coordinate fill counts, audit findings with severity, and report registration confirmation. State every failure honestly; never fabricate success.
