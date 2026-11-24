---
name: lqhd-mail-delivery
description: Send foreign trade outreach emails and handle bounces. Always read SMTP/IMAP settings from <current working directory>/config/mail.json. Probes the SMTP send-server before sending, sends via SMTP, then checks bounces via SMTP responses and IMAP inbox and analyzes causes with solutions. Use when the user wants to actually send emails, probe the mailbox, or check/analyze bounces.
---

# Email Sending and Bounce Handling

Responsible for actually sending foreign trade outreach emails, as well as pre-send mailbox probing, post-send bounce checks, and bounce cause analysis. It works together with `lqhd-mail-agent` (which only writes outreach emails): first write the email with mail-agent, then send it with this skill.

> Golden rule: **Before any send action, the mailbox configuration must be read from `config/mail.json` in the user's current working directory**; hardcoding mailboxes, authorization codes, or server addresses is prohibited. If there is no `config/` directory or `config/mail.json` file in the working directory, the script will **automatically create the directory and write a sample configuration** (with placeholder values); in that case, the user must be prompted to fill in the real account, authorization code, and server address before sending.

## Configuration File

Path: `<user's current working directory>/config/mail.json` (not the plugin installation directory). Format follows the `references/mail.json` template of this skill:

```json
{
  "main": {
    "account": "sender email",
    "auth-code": "authorization code",
    "cc": "CC email (optional)",
    "feedback": "Reply-To email (optional)"
  },
  "server": {
    "receive-server": { "address": "IMAP address", "port": 993, "ssl": true },
    "send-server":    { "address": "SMTP address", "port": 465, "ssl": true }
  }
}
```

- `feedback` is the **Reply-To email**, not the bounce email
- The script command must be run from the user's working directory and reads `./config/mail.json` by default; `--config` can also be used to specify it explicitly
- **Automatic initialization**: If the file/directory does not exist, the script automatically creates `config/mail.json` and fills in the sample values above; the output includes `config_auto_created: true` and a `notice`. The sample values are placeholders, so probing will inevitably fail and sending will be blocked; relay the notice to the user, and have them fill in the real information and rerun

## When to Use

- The user requests to "send" an outreach email (not just write it)
- The user requests to probe the mailbox / test whether SMTP is available
- The user requests to check for bounces, analyze bounce causes, or provide solutions

## Workflow

### 1. Pre-send Probe (Mandatory)
```
python3 <plugin>/skills/lqhd-mail-delivery/scripts/mail_delivery.py --config <cwd>/config/mail.json probe
```
- What the probe does: connects to `send-server` and logs in (`account` + `auth-code`), verifying SMTP connectivity and that the authorization works
- Sending is allowed only if the result is `status: ok`; if `fail`, stop sending and prompt the user to check the configuration based on `detail`
- Never print the authorization code

### 2. Sending
Single email:
```
python3 .../mail_delivery.py --config <cwd>/config/mail.json send \
  --to "customer email" --subject "subject" --body-file "body.txt" --log "<cwd>/profile/send_log.jsonl"
```
Batch (JSON: `[{"to":..,"subject":..,"body":..}, ...]`):
```
python3 .../mail_delivery.py --config <cwd>/config/mail.json send \
  --batch "<cwd>/profile/batch.json" --log "<cwd>/profile/send_log.jsonl"
```
- `send` automatically performs a probe first by default (can be skipped with `--skip-probe`, not recommended)
- Use `feedback` as the Reply-To and `cc` for CC
- Immediate SMTP rejection (RCPT refused) is marked as `status: refused` in the result
- Use `--log` to record the send log for bounce correlation

### 3. Post-send Bounce Check
```
python3 .../mail_delivery.py --config <cwd>/config/mail.json check-bounce \
  --send-log "<cwd>/profile/send_log.jsonl" --since-days 7
```
The bounce check uses two approaches:
1. **SMTP responses**: results of `refused` / `error` at send time (immediate bounces), see the send log
2. **Direct mailbox read**: log in to `receive-server` via IMAP, read `INBOX`, and identify DSN/bounce emails (delayed bounces)

### 4. Bounce Cause Analysis and Solutions
For each bounce, the script outputs a `category` (cause classification) and a `solution` (remedy), and correlates `matched_sent` (whether it corresponds to a sent email). See `references/bounce-codes.md` for common categories.

When reporting to the user, organize it as "bounce list + cause classification + solutions", and give follow-up action recommendations (retry / switch contact / switch channel / optimize content).

## Output Conventions

- All three subcommands output JSON for easy programmatic consumption
- Exit codes: `probe` 0=ok/2=fail; `send` 0=success/3=aborted due to probe failure; exception=1

## Notes

- Configuration must be read from the working directory's `config/mail.json`; if missing, the script automatically creates the directory and a sample file, but the sample values cannot be used for sending — the user must fill in real information and retry
- Do not retry a failed send more than necessary, to avoid being flagged as spam
- Protect the mailbox account and authorization code; do not write them to logs or print them
- Comply with anti-spam regulations and data compliance requirements in the target region
