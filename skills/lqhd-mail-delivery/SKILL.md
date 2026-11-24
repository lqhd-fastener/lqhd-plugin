---
name: lqhd-mail-delivery
description: Send foreign trade outreach emails and handle bounces. Always read SMTP/IMAP settings from <current working directory>/config/mail.json. Probes the SMTP send-server before sending, sends via SMTP, then checks bounces via SMTP responses and IMAP inbox and analyzes causes with solutions. Use when the user wants to actually send emails, probe the mailbox, or check/analyze bounces.
---

# 邮件发送与退信处理

负责实际发送外贸开发信，以及发送前的邮箱探测、发送后的退信检查与退信原因分析。与 `lqhd-mail-agent`（只负责撰写开发信）配合：先在 mail-agent 写信，再用本技能发送。

> 铁律：**任何发送动作之前，必须从用户当前工作目录下的 `config/mail.json` 读取邮箱配置**，禁止硬编码邮箱、授权码或服务器地址。若工作目录下无 `config/` 目录或 `config/mail.json` 文件，脚本会**自动创建目录并写入示例配置**（占位值），此时必须提示用户填写真实账号、授权码与服务器地址后才能发送。

## 配置文件

路径：`<用户当前工作目录>/config/mail.json`（不是插件安装目录）。格式参照本技能的 `references/mail.json` 模板：

```json
{
  "main": {
    "account": "发件邮箱",
    "auth-code": "授权码",
    "cc": "抄送邮箱（可选）",
    "feedback": "回复邮箱 Reply-To（可选）"
  },
  "server": {
    "receive-server": { "address": "IMAP地址", "port": 993, "ssl": true },
    "send-server":    { "address": "SMTP地址", "port": 465, "ssl": true }
  }
}
```

- `feedback` 是**回复邮箱**（Reply-To），不是退信邮箱
- 脚本命令需从用户工作目录运行，默认读取 `./config/mail.json`；也可用 `--config` 显式指定
- **自动初始化**：文件/目录不存在时，脚本自动创建 `config/mail.json` 并填入上述示例值，输出中带 `config_auto_created: true` 与 `notice`。示例值为占位符，探测必然失败、发送被阻止；把提示转达给用户，待其填好真实信息后重跑即可

## 何时使用

- 用户要求"发送"开发信（而不只是写）
- 用户要求探测邮箱 / 测试 SMTP 是否可用
- 用户要求检查是否有退信、分析退信原因、给出解决方案

## 工作流程

### 1. 发送前探测（必做）
```
python3 <plugin>/skills/lqhd-mail-delivery/scripts/mail_delivery.py --config <cwd>/config/mail.json probe
```
- 探测内容：连接 `send-server` 并登录（`account` + `auth-code`），验证 SMTP 连通与授权可用
- 结果 `status: ok` 才能发送；`fail` 时停止发送，按 `detail` 提示用户检查配置
- 绝不打印授权码

### 2. 发送
单封：
```
python3 .../mail_delivery.py --config <cwd>/config/mail.json send \
  --to "客户邮箱" --subject "标题" --body-file "正文.txt" --log "<cwd>/profile/send_log.jsonl"
```
批量（JSON：`[{"to":..,"subject":..,"body":..}, ...]`）：
```
python3 .../mail_delivery.py --config <cwd>/config/mail.json send \
  --batch "<cwd>/profile/batch.json" --log "<cwd>/profile/send_log.jsonl"
```
- `send` 默认自动先做探测（可用 `--skip-probe` 跳过，不建议）
- 用 `feedback` 作为 Reply-To，`cc` 作为抄送
- SMTP 即时拒绝（RCPT refused）会在结果里标 `status: refused`
- 用 `--log` 记录发送日志，供退信关联

### 3. 发送后退信检查
```
python3 .../mail_delivery.py --config <cwd>/config/mail.json check-bounce \
  --send-log "<cwd>/profile/send_log.jsonl" --since-days 7
```
退信检查采用两条途径：
1. **SMTP 响应**：发送时 `refused` / `error` 的结果（即时退信），见发送日志
2. **直接读信**：IMAP 登录 `receive-server`，读取 `INBOX`，识别 DSN/退信邮件（延迟退信）

### 4. 退信原因分析与解决方案
脚本对每封退信输出 `category`（原因分类）与 `solution`（解决方案），并关联 `matched_sent`（是否对应已发送邮件）。常见分类见 `references/bounce-codes.md`。

向用户汇报时按"退信清单 + 原因分类 + 解决方案"组织，并给出后续动作建议（重试 / 换联系人 / 换渠道 / 优化内容）。

## 输出约定

- 三个子命令均输出 JSON，便于程序化读取
- 退出码：`probe` 0=ok/2=fail；`send` 0=成功/3=探测失败中止；异常=1

## 注意事项

- 必须从工作目录 `config/mail.json` 读取配置；缺失时脚本自动建目录与示例文件，但示例值不可用于发送，需用户填真实信息后重试
- 发送失败不重试超过必要次数，避免被判垃圾邮件
- 保护邮箱账号与授权码，不写入日志、不打印
- 遵守反垃圾邮件法规与目标地区数据合规要求
