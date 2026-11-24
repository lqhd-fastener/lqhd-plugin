# Bounce Cause Categories and Solutions

The `check-bounce` script automatically categorizes bounces and provides solutions based on bounce diagnostic information (SMTP status codes / DSN Status / diagnostic text). This table explains the classification criteria for verification and manual handling.

| Category | Common Indicators (Status Codes/Keywords) | Meaning | Solution |
|------|--------------------------|------|---------|
| Recipient mailbox does not exist | 5.1.1 / 550 / user unknown / no such user | The email address does not exist | Verify spelling; reconfirm the contact via the official website/LinkedIn; switch to another contact |
| Recipient domain does not exist | 5.1.2 / 5.2.1 / domain not found | The domain is invalid or has been changed | Check domain spelling; confirm whether the company has changed its domain; remove the lead |
| Recipient mailbox is full | 5.2.2 / 552 / mailbox full / quota exceeded | The recipient's inbox is full | Retry once after a few days; if it still fails, switch contact or channel |
| Rejected by server policy | 5.7.1 / 554 / rejected / policy / blocked | The recipient's server refused the message | Check the content for spammy characteristics; verify the sender IP reputation; configure SPF/DKIM/DMARC; reduce sending frequency |
| Classified as spam | spam / junk / content filter / spam mail | The content or sending behavior was judged as spam | Simplify the body, remove links and attachments, avoid marketing keywords; use `feedback` as Reply-To; warm up the account; send in smaller batches at lower frequency |
| Relay access denied | relay access denied | Sending server relay configuration or authentication error | Check the `account`, `auth-code`, and `send-server` settings in `config/mail.json` |
| Temporary bounce | 4.x.x / temporary / try again later / deferred | Temporary failure or rate limiting on the recipient's server | Retry after a few hours; do not change the mailbox for now |
| Permanent delivery failure (other) | 5.0 / 5.3 / 5.4 / 5.5 / 5.6 | Other permanent failures | Verify the address and content against the diagnostic information; switch contact or channel |
| Unknown bounce cause | No match to the above rules | Requires manual judgment | Review the original bounce diagnostic information, then verify the address and content to decide whether to retry or switch channels |

## Status Code Quick Reference

- **2.x.x**: Success
- **4.x.x**: Temporary failure (retryable)
- **5.x.x**: Permanent failure (usually requires correcting the address or content)
- **550**: The most common rejection code; check the diagnostic text for the specific cause
- **DSN Status**: In the form `5.1.1`, where the first digit 4/5 indicates a temporary/permanent failure

## Handling Principles

1. High-value customer with a temporary bounce (4.x.x) → retry at intervals, not too frequently
2. Permanent bounce (5.x.x) → verify the address first, do not blindly resend
3. Suspected spam classification → first optimize the content and sending strategy, then resend
4. Record every handling: the bounced customer, cause category, solution applied, and result
