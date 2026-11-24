# LQHD Finder — 外贸客户开发专家团

一个遵循 WorkBuddy 专家包规范（v2.0）的 **Team 型** 专家包，面向外贸客户开发场景。由 6 位角色协作完成海外客户开发闭环：线索挖掘 → 背景调查与客户画像 → 个性化开发信触达 → 客户开发情报报告；并支持处理特易咨询导出的两类 xlsx——**公司列表**（多家公司+企业公开邮箱：背调、通知、发公开邮箱开发信、**插入工作台**）与**联系人列表**（同一家公司+多联系人：**从工作台拉取公司资料**、插入联系人、按职位生成千人千面定制信），两类执行官通过 `lqhd-mcp-server` 串联成流水线。

## 基本信息

| 项 | 值 |
|----|----|
| 标识（name） | `lqhd-customers-finder` |
| 类型 | Team（专家团） |
| 行业分类 | `07-SalesCommerce`（销售商务） |
| 主理人 Agent | `lqhd-finder-team-lead` |
| 版本 | 1.0.0 |
| 作者 | Martin Liu <mutian_xiangcai@outlook.com> |

## 团队构成

| 角色 | Agent ID | 职责 |
|------|----------|------|
| 客户开发总监（主理人） | `lqhd-finder-team-lead` | 任务编排、信息中转、成果汇编 |
| 线索挖掘官 | `lqhd-flush-agent` | 按行业/地区/规模检索并刷新海外买家线索 |
| 邮件触达官 | `lqhd-mail-agent` | 撰写个性化开发信、多语言版本与跟进序列 |
| 情报分析官 | `lqhd-report-agent` | 客户背调、画像构建、优先级评分与情报报告 |
| 特易公司列表执行官 | `lqhd-teyi-company-list-agent` | 处理特易 xlsx **公司列表**（多公司+企业公开邮箱）：逐公司背调、通知是否符合、发公开邮箱开发信、把公司数据插入 lqhd-mcp-server |
| 特易联系人列表执行官 | `lqhd-teyi-contact-list-agent` | 处理特易 xlsx **联系人列表**（单公司+多联系人）：从 lqhd-mcp-server 拉取公司记录与公开邮箱列表、插入联系人、按职位写千人千面定制信、（要求时）发信 |

## 内置技能（Skills）

- `lqhd-customer-searching`：海外客户线索检索
- `lqhd-background-investigation`：海外买家背景调查
- `lqhd-user-profile`：**用户企业画像** — 依据用户提示词、企业简介、产品目录、官网生成"用户自己企业（我方）"的画像，写入**用户当前工作目录**的 `profile/profile.md`，作为全流程共享基础信息
- `lqhd-mail-delivery`：**邮件发送与退信处理** — 从工作目录 `config/mail.json` 读配置（缺失则自动建目录并写入示例配置，填真实信息后方可发送），发送前探测 SMTP、发送、发送后查退信并分析原因给方案
- `lqhd-mail-template`：**邮件模板生成** — 依据用户提示生成可复用邮件模板，写入用户当前工作目录的 `config/mail-template.md`（无 `config/` 目录先创建）

## 核心流程（Workflow A：按国家开发客户）

前置：用户当前工作目录的 `profile/profile.md` 须为有效用户企业画像（否则先执行 Phase 0 生成）。

```
Phase 0  用户企业画像 — 依据提示词/企业简介/产品目录/官网生成我方画像，写入用户当前工作目录 profile/profile.md
   ↓
步骤 1  输入国家 — 确认目标国家（及行业/规模等补充条件）
   ↓
步骤 2  依据用户画像寻找该国客户 — lqhd-flush-agent 输出客户线索清单
   ↓
步骤 3  客户评分 — lqhd-report-agent：匹配度（百分制，可合作概率分）+ 可信度（p1/p2/p3）
   ↓
步骤 4  撰写开发信 — lqhd-mail-agent：四段式固定格式
   ↓
步骤 5  注入工作台 — 主理人调用 MCP `lqhd-mcp-server` 注入线索/评分/开发信/画像
```

### 客户评分口径

| 维度 | 含义 |
|------|------|
| 匹配度（0–100） | 依据用户画像与客户画像对比，评估可合作的概率分；越高越契合 |
| 可信度 p1/p2/p3 | 客户信息可靠程度：p1 高（多源交叉验证）/ p2 中（部分验证）/ p3 低（单一或存疑） |

> 两个维度独立：高匹配 ≠ 高可信。开发信优先给"高匹配 + p1/p2"客户。

### 开发信固定格式

严格四段式：`开头 → 第一段（对对方的了解）→ 第二段（我方匹配的产品）→ 结尾`。

> 说明："用户企业画像"（我方，来自用户材料）与"买家画像"（海外客户，来自背调）是两个不同概念，分别由 `lqhd-user-profile` 和 `lqhd-background-investigation` 产出。

### 报告落盘（两类）

两类报告均写入**用户当前工作目录**，目录不存在时自动创建：

| 报告类型 | 落盘路径 | 命名规则 |
|---------|---------|---------|
| 单独客户背调报告 | `customers/<客户标识>-company-report.md` | 客户公司名转小写、空格/特殊字符换连字符，如 "US Company" → `us-company-report.md`；同一客户覆盖更新 |
| 按国家汇总的情报报告 | `reports/<国家简称>/` | 国家简称用 ISO 两位大写代码（US/DE/FR/GB），文件名建议含主题与日期，同一国家多次生成保留历史 |

### 特易表格处理（先识别类型，再分流）

特易咨询导出的 xlsx 字段完全相同（36 列），但内容分两种，**主理人先读表判定类型**再分流，两位执行官通过 `lqhd-mcp-server` 串联：

| 表格类型 | 判定依据 | 执行官 |
|---------|---------|--------|
| **公司列表** | 多行=多个不同公司；"联系人"多为 N/A；邮箱是企业公开邮箱 | 特易公司列表执行官 `lqhd-teyi-company-list-agent` |
| **联系人列表** | 所有行是同一家公司；多行是不同联系人（姓名+职位） | 特易联系人列表执行官 `lqhd-teyi-contact-list-agent` |

**类型 A · 公司列表执行官**（`lqhd-teyi-company-list-agent`）：
1. 读表识别（多公司+公开邮箱），按域名/公司名去重
2. 逐公司背调：调用 `lqhd-background-investigation`，核实主体/经营/贸易/信誉/风险
3. **通知用户是否符合**：依据用户企业画像给出"符合 / 部分符合 / 不符合"、匹配度（0–100）与风险提示，无论结果如何都通知，不符合醒目提示由用户定夺发送
4. 发企业公开邮箱开发信：四段式通用商务语气；用户要求发送时调用 `lqhd-mail-delivery` 探测后发送、查退信分析
5. **插入工作台**：把公司数据（信息/域名/国家/背调/匹配度/公开邮箱/开发信）插入 `lqhd-mcp-server`，供联系人执行官拉取

**类型 B · 联系人列表执行官**（`lqhd-teyi-contact-list-agent`）：
1. 读表识别（单公司+多联系人），联系人分实名/通用邮箱/无邮箱/存疑四类
2. **从工作台拉取**：按公司标识从 `lqhd-mcp-server` 拉取该公司记录与公开邮箱列表（含此前背调结论、匹配结果）；拉取失败如实说明、只用表格字段最小化兜底、不臆造背调数据
3. **插入联系人**：把全部联系人插入 `lqhd-mcp-server`，关联到对应公司记录
4. **千人千面定制信**：按职位定制——决策层讲战略 ROI、店长讲终端动销、销售讲卖点与报价支持、财务讲成本与条款；实名一人一封（`email-<联系人>.md`），通用邮箱共用一份（`email-general.md`），无邮箱单独标注；四段式落盘 `<工作目录>/customers/<公司标识>/`
5. 发信（用户要求时）：调用 `lqhd-mail-delivery` 探测后发送，避免与公开邮箱重复发送、查退信分析

> 流水线依赖：类型 A 先把公司入库，类型 B 才能拉到公司记录。两位执行官的 MCP 工具名按运行时实际 schema 识别、不硬编码；未入库/未拉取成功必须如实说明，绝不编造。内部员工邮箱（创建人/跟进人）不发信、不入库、不写进报告。

协作遵循规范铁律：主理人创建团队 → 调度成员 → 成员产出经 SendMessage 回传 → 主理人中转汇编，成员之间不直连。

## MCP 服务

MCP 服务 `lqhd-mcp-server` 在插件根目录 `.mcp.json` 中声明，并由 `plugin.json` 的 `dependencies.mcpServers` 引用。有三类用途：

1. **主流程步骤 5**：主理人把线索/评分/开发信/画像注入工作台
2. **特易公司列表执行官**：把背调后的公司数据**插入**工作台
3. **特易联系人列表执行官**：按公司**拉取**公司记录与公开邮箱列表、把联系人**插入**工作台（与公司列表执行官串联）

- `lqhd-mcp-server` 是**占位符服务**，本机后续自动导入；当前 `.mcp.json` 为占位地址 `http://localhost:3000`
- 调用工具名以运行时实际暴露的 schema 为准（按用途识别写入/查询类工具），不硬编码
- MCP 未连接 / 工具缺失 / 查不到记录时，如实说明并展示完整结果，不编造注入或拉取成功

## 邮件发送与退信处理

实际发送开发信时，由 `lqhd-mail-delivery` skill 执行，遵循：

1. **配置读取**：必须从用户当前工作目录的 `config/mail.json` 读取邮箱配置（格式参照 `skills/lqhd-mail-delivery/references/mail.json` 模板），禁止硬编码。字段含 `main`（account/auth-code/cc/feedback）、`server.send-server`、`server.receive-server`。其中 `feedback` 是回复邮箱（Reply-To），不是退信邮箱。**若工作目录下无 `config/` 目录或 `config/mail.json`，脚本自动创建目录并写入示例配置（占位值），探测会失败、发送被阻止；按提示填入真实账号/授权码/服务器地址后重跑即可。**
2. **发送前探测**：用 `send-server` 做 SMTP 连接 + 登录探测，探测通过才发送。
3. **发送**：通过 SMTP 发送，`feedback` 作 Reply-To、`cc` 作抄送，并记录发送日志。
4. **发送后退信检查**：两条途径 —— ① 发送时的 SMTP 响应（即时退信）；② 用 `receive-server` IMAP 直接读信（延迟退信）。
5. **退信分析与方案**：对每封退信归类（邮箱不存在/域名无效/邮箱满/策略拒收/判垃圾邮件/临时退信等）并给出解决方案。详见 `skills/lqhd-mail-delivery/references/bounce-codes.md`。

> 配置文件 `config/mail.json` 是**用户工作目录下的运行时配置**（不在插件包内）；插件包内仅保留格式模板 `skills/lqhd-mail-delivery/references/mail.json`（占位值）。

## 邮件模板生成

由 `lqhd-mail-template` skill 执行：依据用户提示（用途、目标客户、产品卖点、语言、语气）生成可复用的邮件模板，写入**用户当前工作目录**的 `config/mail-template.md`（无 `config/` 目录先创建）。模板采用四段式结构并带 `{{占位符}}` 与占位符说明，供 `lqhd-mail-agent` 套用或用户手动使用；与针对具体客户的个性化开发信不同。

## 目录结构

```
lqhd-plugin/
├── .codebuddy-plugin/
│   └── plugin.json          # 专家包元数据与展示信息
├── .mcp.json                # MCP 依赖声明（lqhd-mcp-server，占位地址）
├── settings.json            # 主理人绑定（agent = lqhd-finder-team-lead）
├── agents/                  # 主理人 + 5 位成员的 Agent 定义
├── skills/                  # 5 个内置技能（含 mail-delivery、mail-template 及 scripts/）
│   └── lqhd-mail-delivery/
│       └── references/
│           └── mail.json    # 邮箱配置格式模板（占位值，供工作目录配置参考）
├── avatars/                 # 团队与各角色头像
└── README.md
```

> 注意：以下均为**用户工作目录下的运行时文件**，不属于插件包自身结构：
> - `profile/profile.md`（用户企业画像）
> - `config/mail.json`（邮箱配置，插件包内只在 `skills/lqhd-mail-delivery/references/mail.json` 留了格式模板，缺失时脚本自动在工作目录生成）
> - `config/mail-template.md`（邮件模板，由 mail-template skill 生成）
> - `customers/<客户标识>-company-report.md`（单独客户背调报告）
> - `reports/<国家简称>/`（按国家归档的客户开发报告）

## 使用方法

在 WorkBuddy 专家中心选择本专家团后，可直接描述外贸客户开发需求，例如：

- 根据我提供的企业简介和产品目录，生成我们公司的企业画像。
- 帮我在德国开发客户：找客户、评分、写开发信并注入工作台。
- 在法国找一批家居用品进口商，按匹配度和可信度分级。
- 给上面找出的重点客户写一封四段式开发信。
- 这份特易表是多家公司+企业公开邮箱：逐家背调、通知是否符合、发开发信并入库工作台。
- 这份特易表是一家公司+多个联系人：从工作台拉公司资料后，按联系人职位分别写千人千面开发信，并把联系人入库。
