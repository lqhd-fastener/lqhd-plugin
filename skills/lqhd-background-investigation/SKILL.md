---
name: lqhd-background-investigation
description: Conduct background investigation on potential overseas trade customers. Verify company legitimacy, business status, product fit and market reputation from public sources, and flag risks. Use when the user asks to check, verify or investigate a foreign buyer or customer before outreach.
---

# Customer Background Investigation

Conduct background investigations on potential overseas trade customers, verifying their authenticity, business status, and cooperation risks, so as to provide credible evidence for subsequent customer profiling and outreach emails.

## When to Use

- The user requests a background check, verification, or investigation of a specific overseas customer/buyer
- The lead agent or a team member needs to validate the credibility of a lead during the workflow
- Assessing whether a customer is worth investing resources in before outreach

## Investigation Dimensions

| Dimension | Items to Verify | Primary Sources |
|------|---------|---------|
| Company Entity | Registered name, founding date, location, legal entity | Corporate registry information, official website |
| Business Status | Core products, scale, revenue/employee magnitude, business activity | Official website, industry directories, B2B platforms |
| Trade Records | Import/export records, procurement categories and frequency | Customs/trade data (if available) |
| Market Reputation | Reviews, disputes, negative news, certifications and qualifications | Public news, industry review platforms |
| Risk Signals | Inconsistent information, abnormal complaints, records of dishonesty | Cross-source comparison |

## Workflow

1. **Identify the target**: Confirm the company name, country/region, and known leads of the entity to be investigated
2. **Multi-dimensional search**: Search public information item by item across the dimensions in the table above, recording sources
3. **Cross-verification**: Corroborate key fields with at least two sources
4. **Flag risks**: Clearly mark inconsistent, missing, or negative information
5. **Structured output**: Output according to the template, distinguishing facts from inferences
6. **Save to disk**: Write the report under the **user's current working directory** following the unified archiving convention `<working directory>/countries/<country>/<company>公司报告.md` (see the next section for details)

## Output File (Individual Customer Background Report)

All company background reports use one unified archiving convention under the **user's current working directory** (the root of the workspace where the user is using this plugin, not the plugin installation directory):

- Path: `<user's current working directory>/countries/<国家>/<公司名>公司报告.md`
  - `<国家>` is the two-letter ISO country code in uppercase (e.g. `US`, `DE`, `AU`), consistent with the workbench lead-report folders; if the country cannot be determined, use `MULTI`
  - `<公司名>公司报告.md` uses the company's real name, e.g. `countries/US/Altius Manufacturing公司报告.md`; strip filesystem-hostile characters (`/ \ : * ? " < > |`) from the name
- If the `countries/<国家>/` directory does not exist, create it before writing
- Each report corresponds to one customer; when the same customer is investigated again, overwrite to keep the latest version — if the user wants history preserved, suffix the filename with the date (`...公司报告-2026-11-27.md`)
- **Legacy path deprecated**: older reports may exist at `customers/<id>-company-report.md`; treat that location as read-only history — never write new reports there
- This is a background report for an **individual customer**; the country-aggregated customer development intelligence report (lead report) is separately archived by the report-agent — the two are different

## Output Template

```markdown
# Customer Background Investigation: [Company Name]

## Basic Information
| Field | Content | Source | Credibility |
|------|------|------|-------|
| Company Name | ... | ... | High/Medium/To be verified |
| Founding Date | ... | ... | ... |
| Country/Region | ... | ... | ... |
| Core Products | ... | ... | ... |
| Scale | ... | ... | ... |

## Business and Trade Status
[Key points]

## Market Reputation and Risks
- Positive signals: ...
- Risk signals: ...

## Conclusion
- Credibility assessment: High / Medium / Low
- Recommendation: Proceed / Proceed with caution / Defer
```

## Notes

- Use only publicly available information, and comply with data compliance and privacy requirements in the target region
- Strictly distinguish "facts" from "inferences"; inferences must be labeled as such
- Mark fields that cannot be verified as "to be verified"; never fabricate companies, contacts, or trade data
- Indicate the source and retrieval date for each piece of information wherever possible
