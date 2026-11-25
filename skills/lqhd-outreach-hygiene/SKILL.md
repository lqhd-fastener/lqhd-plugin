---
name: lqhd-outreach-hygiene
description: Outreach data hygiene for foreign trade email campaigns — recipient filtering rules, pre-send SMTP RCPT probing without sending, post-send bounce scanning and status sync (EmailRecord BOUNCED + contact verification), and IMAP sent-mail verification. Use when the user asks to check email validity, probe mailboxes before sending, scan/handle bounces, sync verification status, or decide who should (not) receive outreach.
---

# Outreach Hygiene: Verification, Bounce Governance & Recipient Filtering

Owns the **quality and governance** of outreach data across its lifecycle: before sending (who may receive mail, which addresses actually exist), at send time (avoid duplicates), and after sending (bounce scanning, status sync). It complements `lqhd-mail-delivery` (which performs the actual probe → send → bounce-check cycle): this skill defines the rules and the bookkeeping; the delivery skill executes the transport.

> Golden rule: **a green "verified" flag from a data source is not proof an address exists** — only an SMTP RCPT probe or a real send/bounce outcome is. Every governance action must be recorded back into the workbench, not just reported.

## 1. Recipient Filtering Rules (Who Never Gets Mail)

Before any campaign, filter the candidate list:

| Rule | Handling |
|------|----------|
| System / transactional mailboxes (orders@, cachedsales@, webmaster@, noreply@, postmaster@) | Never send; never ingest as outreach recipients |
| Marketing / info desks with unclear role | Skip unless no better address exists for the company; note the limitation |
| Internal employee fields (creator / follow-up owner) | Never send, never ingest, never write into reports |
| Missing email | Do not guess addresses; flag "missing email, to be supplied" |
| Same domain, multiple similar person names (e.g. Nantha/Nihar/Nihas) | Likely spelling variants of one person — deduplicate before probing/sending |
| Already contacted at same customer + stage + recipient | The workbench rejects duplicates; do not force-send without explicit user approval |

## 2. Pre-Send SMTP RCPT Probing (Without Sending)

For candidate addresses of one campaign:

1. Open an SMTP connection to the configured send server and issue `RCPT TO` for each candidate — this checks existence **without sending anything**.
2. Interpret responses conservatively: Google Workspace returns an explicit `550 5.1.1` for non-existent accounts (definitive invalid). Greylisting or temporary 4xx responses are **unknown**, not invalid — do not mark them bad.
3. Sync results back: addresses probed as invalid get their contact verification updated (e.g. `Invalid (SMTP 550 5.1.1)`) via the workbench batch-update-contacts tool, and are skipped by later outreach.
4. Report per-address verdicts (valid / invalid / unknown) with the raw SMTP codes.

## 3. Post-Send Bounce Scanning & Status Sync

1. **Timing**: scan the INBOX for bounces starting about 1 minute after sending; sender contains 退信 / mailer-daemon / postmaster.
2. **Parsing pitfall**: a DSN arrives as `multipart/report` — do NOT use a single `get_content()` call; **walk the MIME tree and read the `text/plain` parts**, otherwise bounces are silently missed.
3. For each bounce: identify the original recipient (from the DSN or the Sent-log correlation), extract the SMTP reason, and sync two records back via MCP tools:
   - The corresponding **EmailRecord** → status `BOUNCED`, `note` carries the SMTP reason;
   - The corresponding **Contact.verification** → e.g. `Invalid (退信 550 5.1.1)`; later outreach skips it.
4. Classify causes (nonexistent address / invalid domain / full mailbox / policy rejection / spam-flagged / temporary) and give a remedy per class — see the bounce code reference in `lqhd-mail-delivery/references/bounce-codes.md`.

## 4. Sent-Mail Verification (IMAP)

Sending servers may rewrite the `Message-ID`. To verify what actually left:

1. After sending, read the Sent folder via IMAP and match by **recipient + subject** (not by the client-side Message-ID).
2. Write the server's actual `Message-ID` back into the corresponding `EmailRecord` via the mark-email tool — this is the reliable key for later threading and bounce correlation.

## 5. Status & Stage Conventions

- `EmailRecord` is the single source of truth for "did we ever mail this customer": unique per customer + stage + recipient.
- Stage codes follow the campaign cadence: `D0` (first touch), `D+2`, `4.1 / 4.2 / 4.3`, `follow-up` variants; route-specific suffixes (e.g. `D0-route`) are allowed.
- Registering a send with status SENT automatically advances the customer `devStatus` NEW → CONTACTED; replies found later are advanced to REPLIED by the follow-up process — never roll these back manually without the user's say-so.

## Output Contract

Return to the team lead (verbatim): filtering decisions (counts per rule), per-address probe verdicts with SMTP codes, bounce scan results with causes and remedies, verification-sync counts, and any record updates performed. Every failure is stated honestly; never fabricate probe or bounce results.
