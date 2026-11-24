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
6. **Save to disk**: Write the report to `customers/<customer-identifier>-company-report.md` under the **user's current working directory** (the root of the workspace where the user is using this plugin, not the plugin installation directory)

## Output File (Individual Customer Background Report)

- Path: `<user's current working directory>/customers/<customer-identifier>-company-report.md`
- The customer identifier is derived from normalizing the customer's company name: lowercase, spaces and special characters replaced with hyphens (e.g., "US Company" → `us-company`), yielding `us-company-report.md`
- If the `customers/` directory does not exist, create it before writing the file
- Each report corresponds to one customer, with filenames distinguished by customer identifier; when the same customer is investigated multiple times, overwrite and update to keep the latest version
- This is a background report for an **individual customer**; the country-aggregated customer development intelligence report is separately archived by the report-agent to `reports/<country-short-name>/` — the two are different

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
