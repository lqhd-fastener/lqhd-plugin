# LQHD Finder — Foreign Trade Customer Development Expert Team

A **Team-type** expert package following the WorkBuddy expert package specification (v2.0), designed for foreign trade customer development scenarios. Eight roles collaborate to complete the overseas customer development loop: lead mining → background investigation and customer profiling → personalized development letter outreach → workbench ingestion with data-quality audits → follow-up cadence waves with bounce governance → customer development intelligence reports. It also supports processing two types of xlsx files exported by TeYi Consulting — **company lists** (multiple companies + corporate public email addresses: background checks, notifications, sending development letters to public emails, and **inserting into the workbench**) and **contact lists** (one company + multiple contacts: **pulling company data from the workbench**, inserting contacts, and generating letters tailored to each individual by job title). The execution agents are chained into a pipeline via `lqhd-mcp-server`.

## Basic Information

| Item | Value |
|----|----|
| Identifier (name) | `lqhd-customers-finder` |
| Type | Team (Expert Team) |
| Industry Category | `07-SalesCommerce` (Sales & Commerce) |
| Lead Agent | `lqhd-finder-team-lead` |
| Version | 1.0.0 |
| Author | Martin Liu <mutian_xiangcai@outlook.com> |

## Team Composition

| Role | Agent ID | Responsibilities |
|------|----------|------|
| Customer Development Director (Lead) | `lqhd-finder-team-lead` | Task orchestration, information relay, and result compilation |
| Outreach Writer | `lqhd-mail-agent` | Write personalized development letters, multilingual versions, and follow-up sequences |
| Regional Client Explorer | `lqhd-flush-agent` | Search for and refresh overseas buyer leads by industry/region/size |
| Client Background Reporter | `lqhd-report-agent` | Customer background checks, profile building, priority scoring, and client background / regional sourcing reports |
| TeYi Company List Execution Officer | `lqhd-teyi-company-list-agent` | Process TeYi xlsx **company lists** (multiple companies + corporate public emails): background-check each company, notify whether they qualify, send development letters to public emails, and insert company data into lqhd-mcp-server |
| TeYi Contact List Execution Officer | `lqhd-teyi-contact-list-agent` | Process TeYi xlsx **contact lists** (one company + multiple contacts): pull company records and public email lists from lqhd-mcp-server, insert contacts, write letters tailored to each individual by job title, and send emails (when requested) |
| Workbench Data Officer | `lqhd-workbench-agent` | Ingest country client reports and campaign results into the workbench with idempotency, enrich state/coordinates, set up new countries end-to-end (config/boundaries/region names/ports), register reports and run read-only data audits |
| Follow-up Cadence Manager | `lqhd-followup-agent` | Query per-customer email history, decide who is due for the next touch (D0 → D+2 → 4.x), draft stage-appropriate follow-ups, send after probing, register sends, govern bounces/verification and advance devStatus on replies |

## Built-in Skills

- `lqhd-customer-searching`: Overseas customer lead search
- `lqhd-background-investigation`: Overseas buyer background investigation
- `lqhd-user-profile`: **User Company Profile** — Generate a profile of "the user's own company (our side)" based on user prompts, company introduction, product catalog, and official website; written to `profile/profile.md` in the **user's current working directory** and synced to the workbench backend (AppData `user-profile`) — downstream reads are backend-first (`get-app-data`), local file as fallback
- `lqhd-mail-delivery`: **Email Sending and Bounce Handling** — Read configuration from `config/mail.json` in the working directory (if missing, automatically create the directory and write a sample configuration; sending is blocked until real information is filled in), probe SMTP before sending, send, and then check for bounces after sending and analyze the causes to provide solutions
- `lqhd-mail-template`: **Email Template Generation** — Generate reusable email templates based on user prompts and save them to the workbench backend (AppData `email-templates`, via upsert-app-data MCP tool); templates are fetched from the backend via get-app-data. Variables `%公司%` / `%联系人%` / `%国家%` only (`{{ }}` forbidden)
- `lqhd-workbench-sync`: **Workbench Data Sync & Quality** — Idempotent ingestion of reports/results into the workbench (CSV-ready tables, dedup by normalized company key, score<45 → excluded+competitor), state/coordinate enrichment, new-country setup (config/boundaries/region names/ports via MCP app-data), report registration, read-only data audits, and cached outreach-conversation reads (get-mail-conversations serves from a MySQL cache with a 10-minute cooldown; `refresh: true` forces a mail-server pull)
- `lqhd-outreach-hygiene`: **Outreach Data Hygiene** — Recipient filtering rules (never mail system mailboxes / internal employees / guessed addresses), pre-send SMTP RCPT probing without sending, post-send bounce scanning (`multipart/report` must be parsed by walking `text/plain` parts) and status sync (EmailRecord BOUNCED + contact verification), IMAP sent-mail verification by recipient+subject

## Core Workflow (Workflow A: Develop Customers by Country)

Prerequisite: `profile/profile.md` in the user's current working directory must be a valid user company profile (otherwise, run Phase 0 first to generate it).

```
Phase 0  User Company Profile — Generate our profile from prompts/company introduction/product catalog/official website, write to the user's current working directory profile/profile.md
   ↓
Step 1  Input Country — Confirm the target country (and supplementary conditions such as industry/size)
   ↓
Step 2  Find Customers in That Country Based on the User Profile — lqhd-flush-agent outputs the customer lead list
   ↓
Step 3  Customer Scoring — lqhd-report-agent: match score (100-point scale, cooperation probability score) + credibility (p1/p2/p3)
   ↓
Step 4  Write Development Letters — lqhd-mail-agent: fixed four-paragraph format
   ↓
Step 5  Inject into Workbench — Lead agent calls MCP `lqhd-mcp-server` to inject leads/scores/development letters/profiles
```

### Customer Scoring Criteria

| Dimension | Meaning |
|------|------|
| Match Score (0–100) | Based on a comparison between the user profile and the customer profile, a probability score estimating the likelihood of cooperation; the higher, the better the fit |
| Credibility p1/p2/p3 | Reliability of the customer's information: p1 high (cross-verified from multiple sources) / p2 medium (partially verified) / p3 low (single source or questionable) |

> The two dimensions are independent: a high match score does not imply high credibility. Prioritize development letters for customers with "high match + p1/p2".

### Fixed Format for Development Letters

Strictly four paragraphs: `Opening → Paragraph 1 (what we know about them) → Paragraph 2 (our matching products) → Closing`.

> Note: "User Company Profile" (our side, derived from the user's materials) and "Buyer Profile" (the overseas customer, derived from background checks) are two different concepts, produced by `lqhd-user-profile` and `lqhd-background-investigation` respectively.

### Report Output (Two Types)

Both types of reports are written to the **user's current working directory**; the directory is created automatically if it does not exist:

| Report Type | Output Path | Naming Rule |
|---------|---------|---------|
| Individual customer background check report | `countries/<国家>/<公司名>公司报告.md` | `<国家>` = two-letter ISO code (e.g. `US`, `DE`; `MULTI` when undetermined); filename uses the company's real name, e.g. `countries/US/Altius Manufacturing公司报告.md`; subsequent reports for the same customer overwrite and update it. Legacy `customers/<id>-company-report.md` files are read-only history |
| Country-aggregated intelligence report | `reports/<country-code>/` | Use the ISO two-letter uppercase country code (US/DE/FR/GB); filenames should preferably include the topic and date; multiple generations for the same country retain history |

### TeYi Spreadsheet Processing (Identify the Type First, Then Route Accordingly)

The xlsx files exported by TeYi Consulting have identical fields (36 columns), but their content falls into two types. The **lead agent first reads the sheet to determine the type** before routing, and the two execution agents are chained via `lqhd-mcp-server`:

| Sheet Type | Determination Basis | Execution Officer |
|---------|---------|--------|
| **Company List** | Multiple rows = multiple different companies; the "Contact" column is mostly N/A; emails are corporate public email addresses | TeYi Company List Execution Officer `lqhd-teyi-company-list-agent` |
| **Contact List** | All rows belong to the same company; different rows are different contacts (name + job title) | TeYi Contact List Execution Officer `lqhd-teyi-contact-list-agent` |

**Type A · Company List Execution Officer** (`lqhd-teyi-company-list-agent`):
1. Read and identify the sheet (multiple companies + public emails), deduplicate by domain/company name
2. Background-check each company: call `lqhd-background-investigation` to verify the entity/operations/trade/reputation/risks
3. **Notify the user whether they qualify**: based on the user company profile, give "qualified / partially qualified / not qualified", a match score (0–100), and risk warnings; notify regardless of the outcome, and flag unqualified cases prominently so the user decides whether to send
4. Send development letters to corporate public emails: general business tone in the four-paragraph format; when the user requests sending, call `lqhd-mail-delivery` to probe before sending, then check and analyze bounces
5. **Insert into the workbench**: insert the company data (information/domain/country/background check/match score/public email/development letter) into `lqhd-mcp-server` for the contact execution officer to pull

**Type B · Contact List Execution Officer** (`lqhd-teyi-contact-list-agent`):
1. Read and identify the sheet (one company + multiple contacts), categorizing contacts into four types: real-name / generic email / no email / questionable
2. **Pull from the workbench**: by company identifier, pull the company record and public email list (including previous background check conclusions and match results) from `lqhd-mcp-server`; if the pull fails, state so truthfully, fall back to minimal use of the sheet's fields, and never fabricate background check data
3. **Insert contacts**: insert all contacts into `lqhd-mcp-server`, linking them to the corresponding company record
4. **Letters tailored to each individual**: customize by job title — decision-makers get strategic ROI, store managers get end-point sell-through, sales staff get selling points and quotation support, and finance staff get costs and terms; one letter per real-name contact (`email-<contact>.md`), one shared letter for generic emails (`email-general.md`), and contacts without emails flagged separately; four-paragraph letters written to `<working-directory>/customers/<company-id>/`
5. Send emails (when the user requests): call `lqhd-mail-delivery` to probe before sending, avoid duplicate sends to public emails, and check and analyze bounces

> Pipeline dependency: only after Type A has inserted companies into the database can Type B pull the company records. The MCP tool names for both execution officers are identified from the actual runtime schema rather than hardcoded; failure to insert or pull must be stated truthfully and never fabricated. Internal employee emails (creator/follow-up person) are not sent to, not inserted into the database, and not written into reports.

Collaboration follows the normative iron rule: the lead agent creates the team → dispatches members → members return their output via SendMessage → the lead agent relays and compiles; members do not communicate directly with one another.

## MCP Service

The MCP service `lqhd-mcp-server` is declared in the plugin root `.mcp.json` and referenced by `dependencies.mcpServers` in `plugin.json`. It serves five purposes:

1. **Main workflow Step 5**: the lead agent injects leads/scores/development letters/profiles into the workbench
2. **TeYi Company List Execution Officer**: **inserts** background-checked company data into the workbench
3. **TeYi Contact List Execution Officer**: **pulls** company records and public email lists by company, and **inserts** contacts into the workbench (chained with the Company List Execution Officer)
4. **Workbench Data Officer**: **idempotent batch ingestion** of country reports, state/coordinate enrichment, new-country setup (config/boundaries/region names/ports via app-data), report registration and read-only audits
5. **Follow-up Cadence Manager**: **pulls** per-customer email history for cadence decisions, **registers** sends and bounce statuses, and advances devStatus

- `lqhd-mcp-server` is a **placeholder service** to be auto-imported locally later; the current `.mcp.json` uses the placeholder address `http://localhost:3000`
- Tool names to call are determined by the schema actually exposed at runtime (identifying write/query tools by purpose), not hardcoded
- When MCP is not connected / tools are missing / no records are found, state so truthfully and display the complete results; never fabricate a successful injection or pull

## Email Sending and Bounce Handling

When actually sending development letters, the `lqhd-mail-delivery` skill performs the task, following these steps:

1. **Configuration reading**: the email configuration must be read from `config/mail.json` in the user's current working directory (refer to the `skills/lqhd-mail-delivery/references/mail.json` template for the format); hardcoding is prohibited. Fields include `main` (account/auth-code/cc/feedback), `server.send-server`, and `server.receive-server`. Among these, `feedback` is the reply email (Reply-To), not the bounce email. **If the working directory has no `config/` directory or no `config/mail.json`, the script automatically creates the directory and writes a sample configuration (placeholder values); the probe will fail and sending will be blocked — simply fill in the real account/auth-code/server address as prompted and rerun.**
2. **Pre-sending probe**: use `send-server` to perform an SMTP connection + login probe; send only if the probe passes.
3. **Sending**: send via SMTP, with `feedback` as Reply-To and `cc` for CC, and record a sending log.
4. **Post-sending bounce check**: two approaches — (1) the SMTP response at send time (immediate bounces); (2) reading mail directly via IMAP using `receive-server` (delayed bounces).
5. **Bounce analysis and solutions**: classify each bounce (email does not exist / invalid domain / mailbox full / policy rejection / marked as spam / temporary bounce, etc.) and provide a solution. See `skills/lqhd-mail-delivery/references/bounce-codes.md` for details.

> The configuration file `config/mail.json` is a **runtime configuration under the user's working directory** (not inside the plugin package); the plugin package only keeps the format template `skills/lqhd-mail-delivery/references/mail.json` (placeholder values).

## Email Template Generation

Performed by the `lqhd-mail-template` skill: based on user prompts (purpose, target customers, product selling points, language, tone), generate reusable email templates and save them to the **workbench backend** (`AppData` key `email-templates`, via the `upsert-app-data` MCP tool, mode `merge` by template id). Templates use a four-paragraph structure with the three supported variables `%公司%` / `%联系人%` / `%国家%` (the workbench mail editor auto-substitutes them; `{{ }}` placeholders are forbidden); they are fetched back from the backend via `get-app-data` for `lqhd-mail-agent` to apply, or picked in the workbench mail editor's template picker.

## Directory Structure

```
lqhd-plugin/
├── .codebuddy-plugin/
│   └── plugin.json          # Expert package metadata and display information
├── .mcp.json                # MCP dependency declaration (lqhd-mcp-server, placeholder address)
├── settings.json            # Lead agent binding (agent = lqhd-finder-team-lead)
├── agents/                  # Agent definitions for the lead + 7 members
├── skills/                  # 7 built-in skills (including mail-delivery, mail-template, workbench-sync, outreach-hygiene and scripts/)
│   └── lqhd-mail-delivery/
│       └── references/
│           └── mail.json    # Email configuration format template (placeholder values, for reference when configuring the working directory)
├── avatars/                 # Avatars for the team and each role
└── README.md
```

> Note: the following are all **runtime files under the user's working directory** and are not part of the plugin package's own structure:
> - `profile/profile.md` (user company profile)
> - `config/mail.json` (email configuration; the plugin package only keeps a format template at `skills/lqhd-mail-delivery/references/mail.json`, and the script automatically generates it in the working directory if missing)
> - `config/mail-template.md` (email template, generated by the mail-template skill)
> - `customers/<customer-id>-company-report.md` (individual customer background check report)
> - `reports/<country-code>/` (customer development reports archived by country)

## Usage

> **面向业务同事的完整中文使用手册（零代码、纯对话例句）见 [使用手册.md](./使用手册.md)。**
> 建议第一次使用前先读一遍，尤其是「第一次用之前的 5 分钟准备」一节。

After selecting this expert team in the WorkBuddy Expert Center, you can directly describe your foreign trade customer development needs, for example:

- Based on the company introduction and product catalog I provide, generate our company's profile.
- Help me develop customers in Germany: find customers, score them, write development letters, and inject them into the workbench.
- Find a batch of housewares importers in France and grade them by match score and credibility.
- Write a four-paragraph development letter for the key customers found above.
- This TeYi sheet contains multiple companies + corporate public emails: background-check each one, notify whether they qualify, send development letters, and insert them into the workbench.
- This TeYi sheet contains one company + multiple contacts: after pulling company data from the workbench, write a letter tailored to each individual contact by job title, and insert the contacts into the database.
- Ingest this country report into the workbench, then audit the data quality.
- Run the next follow-up wave for our US customers, handle bounces and advance statuses.
