---
name: lqhd-mail-template
description: Generate a reusable foreign trade email template and save it to the LQHD workbench backend (AppData key email-templates) via the upsert-app-data MCP tool; read templates back via get-app-data. Use when the user wants to create, update, list or fetch an email template, outreach template, follow-up template or a reusable email skeleton for customer development.
---

# Email Template Generation (Stored in the Workbench Backend)

Based on the user's prompt, generate a **reusable foreign trade email template** and save it to the **LQHD workbench backend** (`AppData` key `email-templates`) via the MCP `upsert-app-data` tool. Unlike `lqhd-mail-agent` (which writes personalized outreach emails for specific customers), this skill produces a general-purpose template with placeholders that can be reused repeatedly.

> Storage rule: **templates live in the backend, and fetching templates also goes through the backend**. The local `config/mail-template.md` from earlier versions is deprecated as a storage location (may remain as a legacy read-only archive).

## When to Use

- The user requests to "generate an email template / outreach email template / follow-up email template"
- The user wants to establish a reusable email skeleton for repeated use per customer
- The user asks to list, view, modify or delete existing templates
- The user specifies the purpose, tone, language, industry, etc. of the email and requests a template rather than a specific email

## Backend Storage Contract

- Storage key: `email-templates` in the workbench `AppData`, value = array `[{ id, name, subject, body }]`, all four fields non-empty strings
- **Variables**: only `%公司%` / `%联系人%` / `%国家%` are supported — the workbench mail editor auto-substitutes them (selected recipient name, customer company, customer country). `{{ }}` placeholders are **forbidden** and the backend rejects them with 400
- Anything beyond those three variables (product details, hooks, certificates) must be written into the body text directly, or left for `lqhd-mail-agent` to personalize per customer at writing time — not as placeholders
- `id` convention: `tpl-<stage>-<slug>`, e.g. `tpl-d0-strut`, `tpl-d2-followup`, `tpl-41-pricing`; reuse the existing id to overwrite, new id to add
- `name` is human-readable, e.g. `D0 · 支吊架 / T-bolt 通用开发信`

## Operations (all via MCP tools)

| Action | How |
|--------|-----|
| Read / list templates | `get-app-data` with `key: "email-templates"` (add `raw: true` for full content) |
| Add or update one template | `upsert-app-data` with `key: "email-templates"`, `mode: "merge"` (arrays dedupe/append by `id`), value = the single-element array |
| Replace the whole template set | `upsert-app-data` with `key: "email-templates"`, `mode: "replace"` — only when the user explicitly asks to rewrite the full set |
| Verify after write | read back with `get-app-data` and confirm |

If the MCP service is unreachable, state it honestly — do not silently fall back to writing local files as if it were saved.

## Input Elements

Extract from the user's prompt; handle missing items with reasonable defaults and note them:

| Element | Description | Default |
|------|------|--------|
| Template Purpose | First outreach email / follow-up / quotation / invitation / thank-you, etc. | First outreach email |
| Target Customer | Industry, region, role (importer/procurement manager, etc.) | General overseas buyer |
| Our Products | Flagship products and selling points (prefer referencing the user company profile — backend `user-profile` first, local `profile/profile.md` fallback) | Placeholder to be supplemented |
| Language | Chinese / English / bilingual | English |
| Tone | Formal / friendly / concise | Professional and friendly |
| Key Elements | Hooks, CTA, certificates, case studies, etc. that must be included | As needed |

## Template Structure (Four-Part Format)

The email body template follows the unified four-part fixed format of this expert team:

1. **Opening**: Greeting + one-sentence statement of the purpose of the email
2. **Paragraph 1 — understanding of the recipient**: reference the recipient's company/core products/market/recent developments, showing "I know you" (written generically for the template's target customer type; mail-agent personalizes per customer)
3. **Paragraph 2 — our matching products**: our products/fit/differentiating advantages (filled from the user company profile)
4. **Closing**: Low-friction CTA + polite sign-off

Use `%公司%` / `%联系人%` / `%国家%` where the workbench can auto-substitute; everything else is concrete text.

## Template Record Format

Each template is one record in the backend array:

```json
{
  "id": "tpl-d0-strut",
  "name": "D0 · 支吊架 / T-bolt 通用开发信",
  "subject": "High-strength T-bolts for %公司% — supplier introduction",
  "body": "Dear %联系人%,\n\n[Opening: greeting + purpose]\n\n[Paragraph 1: understanding of the recipient's industry/market in %国家%]\n\n[Paragraph 2: our matching products, certifications, capabilities]\n\n[Closing: CTA + polite sign-off]"
}
```

## Workflow

1. **Parse requirements**: Extract the input elements from the user's prompt
2. **Read existing templates**: `get-app-data` (`key: "email-templates"`) to check for an existing template with the same purpose/id — update it instead of duplicating
3. **Supplement selling points**: Read the user company profile (backend `user-profile` first, local `profile/profile.md` fallback) to fill in the "our products" section
4. **Generate template**: Write subject and body in the four-part structure with the three supported variables
5. **Save to backend**: `upsert-app-data` (`key: "email-templates"`, `mode: "merge"`), then read back to verify; report the saved template id(s) to the user

## Usage Tips

- After substitution by mail-agent, verify the facts; do not fabricate customer information
- Avoid spam trigger words and keep the length under control
- Before sending, still follow `lqhd-mail-delivery` for configuration reading and SMTP probing
- The generated template is consumed by `lqhd-mail-agent` (which fetches templates **from the backend** via `get-app-data`) or by the user in the workbench mail editor's template picker

## Notes

- Generate only from elements mentioned in the user's prompt; use the three supported variables or concrete text for missing information, and never fabricate specific companies, products, or case-study facts
- Never use `{{ }}` placeholders — the backend rejects them
- On repeated generation for the same purpose, update the existing record (same `id`) to keep the template set clean
