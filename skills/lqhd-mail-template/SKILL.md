---
name: lqhd-mail-template
description: Generate a reusable foreign trade email template from the user's instructions and save it to <current working directory>/config/mail-template.md. Use when the user wants to create or update an email template, outreach template, follow-up template or a reusable email skeleton for customer development.
---

# Email Template Generation

Based on the user's prompt, generate a **reusable foreign trade email template** and write it to `config/mail-template.md` in the user's current working directory. Unlike `lqhd-mail-agent` (which writes personalized outreach emails for specific customers), this skill produces a general-purpose template with placeholders that can be reused repeatedly.

## When to Use

- The user requests to "generate an email template / outreach email template / follow-up email template"
- The user wants to establish a reusable email skeleton, into which placeholders can later be replaced per customer
- The user specifies the purpose, tone, language, industry, etc. of the email and requests a template rather than a specific email

## Input Elements

Extract from the user's prompt; handle missing items with reasonable defaults and note them:

| Element | Description | Default |
|------|------|--------|
| Template Purpose | First outreach email / follow-up / quotation / invitation / thank-you, etc. | First outreach email |
| Target Customer | Industry, region, role (importer/procurement manager, etc.) | General overseas buyer |
| Our Products | Flagship products and selling points (prefer referencing the user company profile `profile/profile.md`) | Placeholder to be supplemented |
| Language | Chinese / English / bilingual | English |
| Tone | Formal / friendly / concise | Professional and friendly |
| Key Elements | Hooks, CTA, certificates, case studies, etc. that must be included | As needed |

## Template Structure (Four-Part Format)

The email body template follows the unified four-part fixed format of this expert team, with placeholders written as `{{variable_name}}`:

1. **Opening**: Greeting + one-sentence statement of the purpose of the email
2. **Paragraph 1 — understanding of the recipient**: `{{recipient company/core products/market/recent developments}}`, showing "I know you"
3. **Paragraph 2 — our matching products**: `{{our products/fit/differentiating advantages}}`
4. **Closing**: Low-friction CTA + polite sign-off

## Workflow

1. **Parse requirements**: Extract the above input elements from the user's prompt
2. **Supplement selling points**: If a user company profile exists (`<user's current working directory>/profile/profile.md`), read its products and value propositions to fill in the "our products" section; if no profile exists, use placeholders
3. **Generate template**: Write the body according to the four-part structure, along with a subject-line template and placeholder descriptions
4. **Save to disk**: Write to `<user's current working directory>/config/mail-template.md`; if the `config/` directory does not exist, create it before writing the file

## Output Template

Format of the content written to `config/mail-template.md`:

```markdown
# Email Template: [Purpose] — [Target Customer/Industry]

- Purpose:
- Target Customer:
- Language / Tone:
- Generation Date:

## Subject Line Template
[e.g., {{our company}} — {{product}} for {{recipient market}}]

## Body Template (Four-Part Format)

[Opening: greeting + purpose of the email]

[Paragraph 1: understanding of the recipient — {{recipient company/core products/market/developments}}]

[Paragraph 2: our matching products — {{our products/fit/advantages}}]

[Closing: CTA + polite sign-off]

## Placeholder Descriptions
| Placeholder | Meaning | Example/Source |
|--------|------|-----------|
| {{recipient company}} | Name of the recipient customer's company | From the background investigation report |
| {{our products}} | Flagship products | From the user company profile |
| ... | ... | ... |

## Usage Tips
- After replacing placeholders, verify the facts; do not fabricate customer information
- Avoid spam trigger words and keep the length under control
- Before sending, still follow lqhd-mail-delivery for configuration reading and SMTP probing
```

## Output File

- Path: `<user's current working directory>/config/mail-template.md` (the root of the workspace where the user is using this plugin, not the plugin installation directory)
- If there is no `config/` directory, create it before writing
- On repeated generation, overwrite and update to keep the template current; if the user wants to retain multiple versions, save separately by purpose as `config/mail-template-<purpose>.md`

## Notes

- Generate only from elements mentioned in the user's prompt; use placeholders for missing information, and never fabricate specific companies, products, or case-study facts
- List every placeholder in the template individually in the "Placeholder Descriptions" section for easy replacement later
- The generated template is for later use by `lqhd-mail-agent` or manual use by the user; actual sending still follows the configuration reading and probing workflow of `lqhd-mail-delivery`
