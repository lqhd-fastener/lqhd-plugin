#!/usr/bin/env python3
"""LQHD mail delivery CLI.

All commands read email configuration from <cwd>/config/mail.json by default.
If config/mail.json (or its config/ directory) does not exist, it is auto-created
with sample placeholder values; sending is blocked until real credentials are filled in.
Subcommands:
  probe         Probe the SMTP send-server (connect + login), no email is sent.
  send          Send an email (or a batch from a JSON file) through the configured SMTP.
  check-bounce  Check the IMAP receive-server for bounce messages, analyze causes
                and suggest solutions; can correlate with a local send log.

The auth-code is never printed.
"""

import argparse
import email
import json
import os
import smtplib
import imaplib
import sys
from datetime import datetime, timedelta
from email.message import EmailMessage
from email.header import decode_header, make_header
from email.utils import formatdate, parseaddr

DEFAULT_CONFIG = os.path.join("config", "mail.json")

# Sample config written when the runtime working directory has no config/mail.json.
# Values are placeholders — the user must replace them with real credentials.
SAMPLE_CONFIG = {
    "main": {
        "account": "you@example.com",
        "auth-code": "YOUR_SMTP_AUTH_CODE",
        "cc": "cc@example.com",
        "feedback": "reply@example.com",
    },
    "server": {
        "receive-server": {"address": "mail.example.com", "port": 993, "ssl": True},
        "send-server": {"address": "mail.example.com", "port": 465, "ssl": True},
    },
}

AUTO_CREATE_NOTICE = (
    "A sample config was auto-created because none existed at this path. "
    "It contains placeholder values — fill in your real account, auth-code and "
    "server addresses (send-server / receive-server) before sending."
)


# ----------------------------- config -----------------------------

def resolve_config_path(explicit):
    """Config path: explicit arg, else <cwd>/config/mail.json (runtime work dir)."""
    if explicit:
        return os.path.abspath(explicit)
    return os.path.abspath(DEFAULT_CONFIG)


def ensure_config(path):
    """Create <cwd>/config/mail.json (and config/) with sample values if missing.

    Returns True when a new file was created, False when it already existed.
    """
    if os.path.exists(path):
        return False
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(SAMPLE_CONFIG, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    return True


def load_config(path):
    created = ensure_config(path)
    with open(path, "r", encoding="utf-8") as fh:
        raw = json.load(fh)

    main = raw.get("main", {}) or {}
    server = raw.get("server", {}) or {}
    send = server.get("send-server", {}) or {}
    receive = server.get("receive-server", {}) or {}

    cfg = {
        "_auto_created": created,
        "account": main.get("account"),
        "auth_code": main.get("auth-code"),
        "cc": main.get("cc"),
        "feedback": main.get("feedback"),
        "smtp": {
            "address": send.get("address"),
            "port": int(send.get("port") or 0),
            "ssl": bool(send.get("ssl", True)),
        },
        "imap": {
            "address": receive.get("address"),
            "port": int(receive.get("port") or 0),
            "ssl": bool(receive.get("ssl", True)),
        },
    }
    missing = [k for k in ("account", "auth_code") if not cfg[k]]
    if not cfg["smtp"]["address"] or not cfg["smtp"]["port"]:
        missing.append("server.send-server.address/port")
    if missing:
        raise ValueError("Incomplete email config, missing: %s" % ", ".join(missing))
    return cfg


def smtp_port(cfg):
    return cfg["smtp"]["port"] or (465 if cfg["smtp"]["ssl"] else 587)


def imap_port(cfg):
    return cfg["imap"]["port"] or (993 if cfg["imap"]["ssl"] else 143)


def smtp_connect(cfg):
    s = cfg["smtp"]
    port = smtp_port(cfg)
    if s["ssl"]:
        client = smtplib.SMTP_SSL(s["address"], port, timeout=30)
        client.ehlo()
    else:
        client = smtplib.SMTP(s["address"], port, timeout=30)
        client.ehlo()
        try:
            client.starttls()
            client.ehlo()
        except smtplib.SMTPException:
            pass
    return client


def imap_connect(cfg):
    s = cfg["imap"]
    port = imap_port(cfg)
    if s["ssl"]:
        client = imaplib.IMAP4_SSL(s["address"], port, timeout=30)
    else:
        client = imaplib.IMAP4(s["address"], port, timeout=30)
        try:
            client.starttls()
        except imaplib.IMAP4.error:
            pass
    return client


# ----------------------------- probe ------------------------------

def cmd_probe(args):
    cfg = load_config(resolve_config_path(args.config))
    s = cfg["smtp"]
    result = {
        "action": "probe",
        "config": resolve_config_path(args.config),
        "smtp": "%s:%d" % (s["address"], smtp_port(cfg)),
        "ssl": s["ssl"],
        "account": cfg["account"],
    }
    if cfg["_auto_created"]:
        result["config_auto_created"] = True
        result["notice"] = AUTO_CREATE_NOTICE
    try:
        client = smtp_connect(cfg)
        try:
            code, resp = client.login(cfg["account"], cfg["auth_code"])
            result["login_code"] = code
            result["login_message"] = safe_decode(resp)
            result["status"] = "ok" if code == 235 else "warning"
            result["detail"] = "SMTP connect and login succeeded. Safe to send."
        finally:
            try:
                client.quit()
            except Exception:
                pass
    except Exception as exc:
        result["status"] = "fail"
        result["error"] = "%s: %s" % (type(exc).__name__, exc)
        result["detail"] = (
            "SMTP probe failed. Check config/mail.json send-server address/port/ssl "
            "and account/auth-code. Do NOT send emails until probe passes."
        )
    print_json(result)
    return 0 if result["status"] == "ok" else 2


# ------------------------------ send ------------------------------

def safe_decode(value):
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return str(value)


def build_message(cfg, item):
    msg = EmailMessage()
    msg["From"] = item.get("from") or cfg["account"]
    msg["To"] = item["to"]
    cc = item.get("cc", cfg.get("cc"))
    if cc:
        msg["Cc"] = cc
    feedback = item.get("feedback", cfg.get("feedback"))
    if feedback:
        msg["Reply-To"] = feedback
    msg["Subject"] = item.get("subject", "(no subject)")
    msg["Date"] = formatdate(localtime=True)
    msg.set_content(item.get("body", ""))
    return msg


def load_send_items(args):
    """Return list of {to, subject, body, ...}."""
    if args.batch:
        with open(args.batch, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        items = data.get("emails", data) if isinstance(data, dict) else data
        if not isinstance(items, list):
            raise ValueError("Batch JSON must be a list or an object with 'emails' list")
        return items
    if not args.to:
        raise ValueError("send requires --to (or --batch <file>)")
    body = args.body
    if args.body_file:
        with open(args.body_file, "r", encoding="utf-8") as fh:
            body = fh.read()
    return [{"to": args.to, "subject": args.subject or "(no subject)", "body": body or ""}]


def cmd_send(args):
    cfg = load_config(resolve_config_path(args.config))

    # A freshly auto-created config holds placeholder credentials — never send with it.
    if cfg["_auto_created"]:
        print_json({
            "action": "send", "status": "aborted",
            "config": resolve_config_path(args.config),
            "reason": "Config was auto-created with sample values. Fill in real credentials first.",
            "notice": AUTO_CREATE_NOTICE,
        })
        return 3

    if not args.skip_probe:
        probe = {"action": "probe", "smtp": "%s:%d" % (cfg["smtp"]["address"], smtp_port(cfg))}
        try:
            client = smtp_connect(cfg)
            try:
                code, resp = client.login(cfg["account"], cfg["auth_code"])
                probe["login_code"] = code
                probe["status"] = "ok" if code == 235 else "warning"
            finally:
                try:
                    client.quit()
                except Exception:
                    pass
        except Exception as exc:
            probe["status"] = "fail"
            probe["error"] = "%s: %s" % (type(exc).__name__, exc)
        if probe["status"] == "fail":
            print_json({"action": "send", "status": "aborted",
                        "reason": "SMTP probe failed, email not sent.", "probe": probe})
            return 3

    items = load_send_items(args)
    log_path = os.path.abspath(args.log) if args.log else None
    results = []

    client = smtp_connect(cfg)
    try:
        code, resp = client.login(cfg["account"], cfg["auth_code"])
        for item in items:
            rec = {"to": item["to"], "subject": item.get("subject", "")}
            try:
                msg = build_message(cfg, item)
                refused = client.send_message(msg)
                # send_message returns dict of refused recipients; SMTP RCPT rejections
                # raise SMTPRecipientsRefused, handled below.
                if refused:
                    rec["status"] = "refused"
                    rec["refused"] = {k: safe_decode(v) for k, v in refused.items()}
                else:
                    rec["status"] = "accepted"
                    rec["detail"] = "SMTP accepted the message (queued). " \
                                    "Check for delayed bounces with check-bounce."
            except smtplib.SMTPRecipientsRefused as exc:
                rec["status"] = "refused"
                rec["refused"] = {k: safe_decode(v) for k, v in exc.recipients.items()}
            except smtplib.SMTPResponseException as exc:
                rec["status"] = "error"
                rec["smtp_code"] = exc.smtp_code
                rec["error"] = safe_decode(exc.smtp_error)
            except Exception as exc:
                rec["status"] = "error"
                rec["error"] = "%s: %s" % (type(exc).__name__, exc)
            rec["time"] = datetime.now().isoformat(timespec="seconds")
            results.append(rec)
    finally:
        try:
            client.quit()
        except Exception:
            pass

    summary = {
        "action": "send",
        "config": resolve_config_path(args.config),
        "account": cfg["account"],
        "total": len(results),
        "accepted": sum(1 for r in results if r["status"] == "accepted"),
        "refused": sum(1 for r in results if r["status"] == "refused"),
        "error": sum(1 for r in results if r["status"] == "error"),
        "results": results,
    }
    if cfg["_auto_created"]:
        summary["config_auto_created"] = True
        summary["notice"] = AUTO_CREATE_NOTICE
    if log_path:
        with open(log_path, "a", encoding="utf-8") as fh:
            for rec in results:
                line = dict(rec)
                line["action"] = "send"
                line["time"] = rec.get("time")
                fh.write(json.dumps(line, ensure_ascii=False) + "\n")
        summary["log_file"] = log_path
    print_json(summary)
    return 0


# -------------------------- bounce analysis -----------------------

BOUNCE_SUBJECT_KEYS = [
    "delivery status notification", "delivery failure", "undelivered mail",
    "returned mail", "mail delivery", "failure notice", "退信", "投递失败",
]
BOUNCE_SENDER_KEYS = ["mailer-daemon", "postmaster", "mail delivery subsystem"]


def decode_str(value):
    try:
        return str(make_header(decode_header(value or "")))
    except Exception:
        return safe_decode(value)


def is_bounce(msg):
    sender = decode_str(msg.get("From", "")).lower()
    subject = decode_str(msg.get("Subject", "")).lower()
    ctype = msg.get_content_type()
    if any(k in sender for k in BOUNCE_SENDER_KEYS):
        return True
    if ctype == "multipart/report" or "delivery-status" in ctype:
        return True
    if any(k in subject for k in BOUNCE_SUBJECT_KEYS):
        return True
    return False


def extract_dsn(msg):
    """Extract delivery-status fields from a DSN bounce."""
    info = {"status": "", "recipient": "", "diagnostic": "", "action": ""}
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "message/delivery-status":
                payload = part.get_payload()
                if isinstance(payload, list):
                    for sub in payload:
                        for key in ("Status", "Final-Recipient", "Diagnostic-Code", "Action"):
                            v = sub.get(key)
                            if v:
                                info[{"Status": "status", "Final-Recipient": "recipient",
                                      "Diagnostic-Code": "diagnostic", "Action": "action"}[key]] = safe_decode(v)
            elif part.get_content_type() == "text/plain":
                try:
                    text = part.get_payload(decode=True).decode("utf-8", errors="replace")
                except Exception:
                    text = ""
                if not info["diagnostic"]:
                    info["diagnostic"] = text.strip()[:400]
    return info


def analyze_bounce(reason):
    """Map a bounce reason to (category, solution)."""
    text = (reason or "").lower()
    rules = [
        (["5.1.1", "user unknown", "no such user", "550", "邮箱不存在", "unknown recipient"],
         "收件人邮箱不存在",
         "核对客户邮箱拼写；通过官网/领英等渠道重新确认联系人；换用其他联系人邮箱。"),
        (["5.1.2", "5.2.1", "domain not found", "host not found", "域名不存在"],
         "收件人域名不存在",
         "检查域名拼写是否正确；确认客户公司是否更换域名；剔除该线索。"),
        (["5.2.2", "552", "mailbox full", "quota exceeded", "收件箱满"],
         "收件人邮箱已满",
         "隔几天后重试一次；若仍退信，改用其他联系人或电话/社媒渠道。"),
        (["5.7.1", "554", "rejected", "policy", "blocked", "被拒绝", "拒收"],
         "被对方服务器策略拒绝",
         "检查发件内容是否含垃圾邮件特征（过多链接/附件/营销词）；确认发件 IP 声誉；"
         "配置 SPF/DKIM/DMARC；降低发送频率。"),
        (["spam", "junk", "垃圾邮件", "content filter", "message rejected as spam"],
         "被判定为垃圾邮件",
         "简化正文、去掉可疑链接与附件、避免过度营销用语；使用 feedback 回复邮箱；"
         "预热发件账号；分批低频发送。"),
        (["relay", "relay access denied", "中继"],
         "中继权限被拒",
         "检查 config/mail.json 的账号与授权码是否正确、send-server 配置是否正确。"),
        (["4.1", "4.2", "4.4", "4.7", "temporary", "try again later", "deferred", "临时"],
         "临时性退信",
         "多为对方服务器临时故障或限流；稍后（数小时）重试，暂不修改邮箱。"),
        (["5.0", "5.3", "5.4", "5.5", "5.6"],
         "永久性投递失败（其他）",
         "结合诊断信息核实收件地址与内容；必要时更换联系人或渠道。"),
    ]
    for keys, category, solution in rules:
        if any(k in text for k in keys):
            return category, solution
    return "未知退信原因", "人工查看退信原文诊断信息，核对收件地址与邮件内容后再决定重试或换渠道。"


def cmd_check_bounce(args):
    cfg = load_config(resolve_config_path(args.config))
    sent_log = {}
    if args.send_log and os.path.exists(args.send_log):
        with open(args.send_log, "r", encoding="utf-8") as fh:
            for line in fh:
                try:
                    rec = json.loads(line)
                    if rec.get("to"):
                        sent_log[rec["to"].strip().lower()] = rec
                except Exception:
                    continue

    since = datetime.now() - timedelta(days=args.since_days)
    bounces = []
    client = imap_connect(cfg)
    try:
        code, resp = client.login(cfg["account"], cfg["auth_code"])
        if code != "OK":
            raise RuntimeError("IMAP login failed: %s" % safe_decode(resp))
        mailbox = args.mailbox or "INBOX"
        typ, data = client.select(mailbox)
        if typ != "OK":
            raise RuntimeError("Cannot select mailbox %s" % mailbox)
        criteria = ["ALL"]
        if args.unseen_only:
            criteria = ["UNSEEN"]
        typ, ids = client.search(None, *criteria)
        msg_ids = ids[0].split() if ids and ids[0] else []
        for mid in msg_ids[-args.limit:]:
            typ, raw = client.fetch(mid, "(RFC822)")
            if typ != "OK" or not raw or not raw[0]:
                continue
            msg = email.message_from_bytes(raw[0][1])
            if not is_bounce(msg):
                continue
            dsn = extract_dsn(msg)
            reason = " ".join(filter(None, [dsn["status"], dsn["diagnostic"]]))
            if not reason:
                reason = decode_str(msg.get("Subject", ""))
            category, solution = analyze_bounce(reason)
            recipient = dsn["recipient"]
            # Final-Recipient often looks like "rfc822; user@example.com"
            if recipient and ";" in recipient:
                recipient = recipient.split(";", -1)[-1].strip()
            if not recipient:
                to_header = decode_str(msg.get("To", ""))
                recipient = parseaddr(to_header)[1]
            bounces.append({
                "recipient": recipient,
                "status": dsn["status"],
                "reason": reason[:300],
                "category": category,
                "solution": solution,
                "matched_sent": bool(recipient and recipient.lower() in sent_log),
            })
    finally:
        try:
            client.logout()
        except Exception:
            pass

    summary = {
        "action": "check-bounce",
        "config": resolve_config_path(args.config),
        "account": cfg["account"],
        "mailbox": args.mailbox or "INBOX",
        "since_days": args.since_days,
        "bounce_count": len(bounces),
        "bounces": bounces,
        "note": "Bounces checked via IMAP read. SMTP-time refusals appear in the send log "
                "(run send with --log). Analyze each category above and apply the solution.",
    }
    if cfg["_auto_created"]:
        summary["config_auto_created"] = True
        summary["notice"] = AUTO_CREATE_NOTICE
    print_json(summary)
    return 0


# ------------------------------- CLI ------------------------------

def print_json(obj):
    print(json.dumps(obj, ensure_ascii=False, indent=2))


def build_parser():
    parser = argparse.ArgumentParser(description="LQHD mail delivery (config from <cwd>/config/mail.json)")
    parser.add_argument("--config", help="Path to mail.json (default: <cwd>/config/mail.json)")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("probe", help="Probe SMTP connect + login").set_defaults(func=cmd_probe)

    p_send = sub.add_parser("send", help="Send email(s) after SMTP probe")
    p_send.add_argument("--to", help="Recipient email")
    p_send.add_argument("--subject", default="(no subject)")
    p_send.add_argument("--body")
    p_send.add_argument("--body-file", help="Read body from a UTF-8 file")
    p_send.add_argument("--batch", help="JSON file with a list of {to,subject,body,...}")
    p_send.add_argument("--log", help="Append send results to a JSONL log for bounce correlation")
    p_send.add_argument("--skip-probe", action="store_true", help="Skip the pre-send SMTP probe")
    p_send.set_defaults(func=cmd_send)

    p_b = sub.add_parser("check-bounce", help="Read bounces via IMAP and analyze causes")
    p_b.add_argument("--mailbox", default="INBOX")
    p_b.add_argument("--since-days", type=int, default=7)
    p_b.add_argument("--limit", type=int, default=100)
    p_b.add_argument("--unseen-only", action="store_true")
    p_b.add_argument("--send-log", help="JSONL send log to correlate bounces with sent emails")
    p_b.set_defaults(func=cmd_check_bounce)
    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    try:
        return args.func(args)
    except Exception as exc:
        print_json({"status": "error", "error": "%s: %s" % (type(exc).__name__, exc)})
        return 1


if __name__ == "__main__":
    sys.exit(main())
