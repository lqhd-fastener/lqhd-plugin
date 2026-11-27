---
name: lqhd-user-profile
description: Build a structured profile of the USER'S OWN company (the seller/supplier) from the user's prompt, company introduction, product catalog and official website. Capture company identity, products, strengths, target markets and value propositions for downstream customer development. Use when the user wants to generate or complete their own company profile.
---

# User Company Profile Building

Based on materials provided by the user — such as prompts, company introduction, product catalog, and official website — generate a structured company profile for **the user's own company (our side / the supplier)**. This profile is used for subsequent customer development: it lets lead discovery, outreach email writing, customer background investigation, and other stages clearly understand "who we are, what we sell, where our strengths lie, and whom we are looking for."

> Note: This skill generates a profile of **the user's own company**, not a profile of an overseas buyer/customer. Buyer profiles are handled by `lqhd-background-investigation` and team analysis.

## When to Use

- The user requests to generate or complete a company profile for "our company / our side / our own company"
- The user provides a company introduction, product catalog, official website link, etc., and wants them consolidated into a structured profile
- The team needs to clarify its own positioning and selling points before formally developing customers

## Input Materials

Collect based on availability; use whatever the user provides, and mark missing items as "to be supplemented":

| Source | Information That Can Be Extracted |
|------|-----------|
| User prompt | Company positioning, target markets, main business, specially emphasized selling points |
| Company introduction | Company name, founding date, nature (factory/trader), scale, certifications and qualifications |
| Product catalog | Product categories, flagship products, specifications, price range, OEM/ODM capabilities |
| Official website | Product lines, brands, market coverage, contact information, case studies, news and updates |

## Profile Dimensions

| Dimension | Content |
|------|------|
| Company Identity | Company name, founding date, location, company nature (factory/trader/brand owner), scale |
| Main Business | Main categories, core products, key points of the product catalog |
| Core Strengths | Production capacity, R&D, certifications, price/quality advantages, customization and delivery capabilities |
| Target Markets | Existing markets, markets targeted for expansion, key countries/regions |
| Target Customers | Types of customers the user hopes to develop (importers/wholesalers/brand owners/retailers, etc.) |
| Brand and Channels | Brand name, official website, B2B platform stores, social media |
| Value Proposition | One-sentence core selling point, differentiating advantages, keywords usable in outreach emails |
| Items to Supplement | Information not provided in the materials and requiring further confirmation from the user |

## Workflow

1. **Collect materials**: Read the user prompt, company introduction, product catalog, official website content, and other materials
2. **Extract information**: Extract item by item according to the profile dimensions, noting the source of each piece of information
3. **Complete the dimensions**: Mark missing dimensions as "to be supplemented"; do not fabricate company facts
4. **Distill selling points**: Summarize core value propositions and differentiating advantages into keywords usable in outreach emails
5. **Structured output**: Generate the profile according to the template below
6. **Save to disk**: Write the generated profile to `profile/profile.md` under the **user's current working directory** (the root of the workspace where the user is using this plugin, not the plugin installation directory); if the `profile/` directory does not exist, create it before writing the file
7. **Sync to the workbench backend (mandatory)**: After the local file is written, push the same content to the workbench via the MCP `upsert-app-data` tool — `key: "user-profile"`, `value: { "text": "<the full profile Markdown>" }`, `mode: "replace"`. Then read it back with `get-app-data` (`key: "user-profile"`, `raw: true`) to confirm the write. If the MCP service is unreachable, state so honestly and tell the user the profile exists only locally for now

## Output Template

```markdown
# User Company Profile: [Company Name]

## I. Company Identity
- Company Name:
- Founding Date:
- Location:
- Company Nature: Factory / Trader / Brand Owner
- Scale:
- Information Source: Prompt / Company Introduction / Official Website / Product Catalog

## II. Main Business and Products
- Main Categories:
- Core Products:
- Key Product Catalog Points:
- OEM/ODM Capabilities:

## III. Core Strengths
- Production Capacity / R&D:
- Certifications and Qualifications:
- Price / Quality Advantages:
- Customization and Delivery Capabilities:

## IV. Target Markets and Customers
- Existing Markets:
- Markets Targeted for Expansion:
- Target Customer Types:

## V. Brand and Channels
- Brand Name:
- Official Website:
- B2B Platforms / Social Media:

## VI. Value Proposition
- One-sentence Core Selling Point:
- Differentiating Advantages:
- Keywords for Outreach Emails:

## VII. Items to Supplement
[Information not provided in the materials and requiring confirmation from the user]
```

## Output File

- After generation, the profile must be written to `profile/profile.md` under the **user's current working directory** (i.e., the root of the workspace where the user is using this plugin, usually their project root directory; **not** the installation directory of this plugin)
- Write path = `<user's current working directory>/profile/profile.md`, where `profile/` in the path is relative to the current working directory
- If there is no `profile/` in the current working directory, first create the directory with mkdir, then write `profile.md`
- On repeated generation, overwrite and update the file to keep the content as the latest profile
- **The workbench backend (`AppData` key `user-profile`) must be kept in sync** — local file and backend always hold the same latest content. Downstream consumers (mail-agent, follow-up-agent, team analysis) should read the profile **backend-first** via `get-app-data` (`key: "user-profile"`), falling back to the local `profile/profile.md` only when the MCP service is unreachable

## Notes

- Extract information only from materials provided by the user; never fabricate companies, products, or qualification facts
- Mark information that cannot be confirmed from the materials as "to be supplemented"; when an inference is needed, mark it as "inference" and explain the basis
- Distinguish "facts" (from materials) from "distillation" (summaries based on materials)
- Note the retrieval date when external materials such as the official website involve real-time information
