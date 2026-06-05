<div align="center">

# 🧠 ai-app-dev-skills

### 打造生产级 AI 应用的 Claude Code 终极 Skill 包

[![许可证: MIT](https://img.shields.io/badge/许可证-MIT-yellow.svg)](LICENSE)
[![技能](https://img.shields.io/badge/技能-4-blueviolet.svg)](skills/)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-兼容-blue.svg)](#-兼容性)
[![欢迎 PR](https://img.shields.io/badge/PRs-欢迎-brightgreen.svg)](docs/CONTRIBUTING.md)

**生产级 Skill，覆盖 RAG · 智能体 · 提示工程 · MCP Server —— 插入 Claude Code，直接交付。**

</div>

---

> 🌐 语言：[English](README.md) · **中文**

> 把下面的 `liucx147` 替换为你的 GitHub 组织名（或用户名）后再运行。

```bash
curl -fsSL https://raw.githubusercontent.com/liucx147/ai-app-dev-skills/main/scripts/install.sh | bash
```

---

## 🤔 为什么需要 ai-app-dev-skills？

AI 应用做演示很容易，交付上线却极其困难。从"在我机器上能跑"到"生产可用"之间的鸿沟，需要评估框架、检索调优、智能体护栏和协议规范——这些没人有时间从头学。这个 Skill 包通过 Claude 引导你走完整个交付生命周期——从需求到架构、可运行代码、优化和评估。

| 没有 Skills | 使用 ai-app-dev-skills |
| --- | --- |
| *"帮我做一个 RAG 应用"* → 300 行胶水代码 | *同样的话* → 生产级架构、评估框架、可部署项目 |
| 智能体死循环、烧 token、产生幻觉 | 硬性回合上限、重试策略、人类审批关、可观测性 |
| 提示词靠感觉写，每次结果都不一样 | 25 种工程化模式、版本化提示词、A/B 测试框架 |
| MCP Server 从零摸索协议 | 5 分钟生成符合规范的 Server，含工具/资源/提示注册 |
| "我不知道从哪儿开始" | 6 阶段工作流，配决策树、模板和自检脚本 |

> **停止重复造轮子。开始交付。**

---

## ✨ Skill 包

### 快速索引

<!-- SKILL_INDEX:START -->
<!-- 本节由 `scripts/generate-index.sh` 自动生成，请勿手动编辑。 -->
| Skill | 描述 |
| --- | --- |
| [`agent-architect`](skills/agent-architect/SKILL.md) | 适用场景：搭建 AI 智能体、设计智能体架构、实现工具调用、构建多智能体系统、开发自主工作流，或是为智能体增设记忆模块与规划能力。内容涵盖 ReAct、规划 - 执行（Plan-and-Execute）、LATS、各类多智能体范式以及智能体效果评测。 |
| [`mcp-server-builder`](skills/mcp-server-builder/SKILL.md) |适用于创建 MCP 服务端、实现 MCP 工具、构建 MCP 资源、添加 MCP 提示词，或将 MCP 集成至现有应用。内容涵盖 TypeScript/Python 软件开发工具包、传输层、工具注册及 MCP 最佳实践。 |
| [`prompt-engineering-expert`](skills/prompt-engineering-expert/SKILL.md) |适用于编写系统提示词、设计提示词链路、优化提示词效果、搭建提示词模板、实现结构化输出，或是构建评测数据集。内容包含思维链、少样本学习、合规约束人工智能、提示词版本管理与 A/B 测试。 |
| [`rag-pipeline-builder`](skills/rag-pipeline-builder/SKILL.md) | 适用于搭建、设计或优化检索增强生成系统、向量检索流水线、文档接入流水线、知识库以及检索增强类应用。内容涵盖文本分块、向量数据库与嵌入模型选型、混合检索、重排序及效果评测。 |
<!-- SKILL_INDEX:END -->

---

### 🔄 `rag-pipeline-builder` — 生产级 RAG 系统

设计、构建并优化检索增强生成管道，从分块策略到评估。

**触发词：** `搭建 RAG 系统` · `向量搜索管道` · `文档导入` · `知识库` · `检索增强应用`

- 5 阶段工作流：需求 → 架构 → 代码 → 优化 → 评估
- 9 个向量数据库 × 8 个维度对比（Pinecone、Weaviate、Qdrant、Milvus、Chroma、pgvector、Vespa、LanceDB、Elasticsearch）
- 6 种分块策略（附 Python 代码），混合检索、重排序与 RAGAS 评估
- 生成可运行的项目骨架，含 `.env.example`、README 和自校验脚本

### 🤖 `agent-architect` — AI 智能体系统

设计、原型化并交付不会死循环或破坏数据的智能体系统。

**触发词：** `搭建 AI 智能体` · `设计智能体架构` · `实现工具调用` · `多智能体系统` · `自主工作流`

- 6 阶段工作流：需求 → 模式选择 → 工具设计 → 记忆 → 代码 → 评估
- 7 种智能体模式（ReAct、ReAct+Router、Plan-and-Execute、LATS、Reflexion、Debate、Hierarchical），含 ASCII 决策树
- 10 个生产级工具模板，含显式错误契约、沙箱标志和人类审批关
- 跨框架指导：LangGraph、CrewAI、AutoGen、Semantic Kernel、OpenAI Agents SDK

### ✍️ `prompt-engineering-expert` — 工程化提示词

打造、优化并系统化产出**一致、可量化、安全**的提示词。

**触发词：** `写系统提示词` · `设计提示链` · `优化提示词` · `结构化输出` · `评估数据集`

- 25 种提示词模式（从 Zero-shot 到 Multi-modal），每种含最小模板和"适用场景"说明
- 4 维评估框架：准确性、一致性、安全性、成本——含 A/B 测试框架
- 15 个反模式，每条含"错误示例 / 为何失败 / 修复方案"
- 提示词版本化规范，版本控制的 `prompts/` 目录，一页式评估报告模板

### 🔌 `mcp-server-builder` — MCP Server 与客户端

构建与 Claude Desktop、IDE 以及任何合规客户端协作的 Model Context Protocol Server 和客户端。

**触发词：** `创建 MCP Server` · `实现 MCP 工具` · `构建 MCP 资源` · `添加 MCP 提示` · `集成 MCP`

- 5 阶段工作流：能力梳理 → 协议设计 → 代码 → 测试 → 发布
- 完整协议规范（握手、Tools/Resources/Prompts、传输层、JSON-RPC 帧、安全注解）
- 6 个 TypeScript 和 Python 工作示例（stdio 与 Streamable HTTP）
- Claude Desktop 配置片段、MCP Inspector 测试方案、npm/PyPI 发布清单

---

## 🚀 快速开始

**三步，约 60 秒。**

```bash
# 1. 安装（无需克隆仓库）
curl -fsSL https://raw.githubusercontent.com/liucx147/ai-app-dev-skills/main/scripts/install.sh | bash

# 2. 重启 Claude Code

# 3. 试试某个 Skill
# 打开 Claude Code，输入上面的任一触发词。
```

**或从本地克隆安装**（推荐贡献者使用）：

```bash
git clone https://github.com/liucx147/ai-app-dev-skills
cd ai-app-dev-skills
bash scripts/install.sh                # 软链模式（编辑即时生效）
bash scripts/install.sh --copy        # 复制模式
bash scripts/install.sh --dry-run     # 仅预览
bash scripts/install.sh --target <d>  # 自定义安装目录
```

安装器把每个 Skill 放进 `~/.claude/skills/`。重启 Claude Code，它们就生效了。

---

## 💬 使用示例

### 🟢 搭建 RAG 管道

> **你：** *帮我在内部 Confluence 上搭一个 RAG 系统。*

Claude 加载 `rag-pipeline-builder` 并引导你：
1. **需求** — 5,000 页，PDF 与 HTML 混合，p95 < 2 s，本地部署，GDPR 合规。
2. **架构** — PostgreSQL 栈 → **pgvector**；BGE-M3 Embedding；递归 Markdown 分块 512 tokens；BM25 + 向量混合 + RRF；Cohere Rerank 3；Claude Sonnet 4.6 配合提示缓存。
3. **代码** — 完整 Python 项目：`src/ingest/`、`src/retrieve/`、`src/generate/`、`src/api/`、RAGAS 评估脚本、`.env.example`、README。
4. **优化** — 走查 10 项清单；标记已完成和待办。
5. **评估** — 生成 50 题评估集，运行 RAGAS，输出一页报告。

### 🟢 交付退款处理智能体

> **你：** *我需要一个能处理 200 美元以下退款的智能体，超过需要人工审批。*

Claude 加载 `agent-architect` 并产出：
- **模式：** ReAct + Tool Router（支持平台有 30+ 工具）。
- **工具：** `lookup_order`、`process_refund`（人类审批关，最高 $200）、`send_email`（人类审批关）、`escalate_to_human`。
- **记忆：** 短期会话缓冲区 + 长期向量存储（保存客户偏好）。
- **硬性上限：** `max_turns=25`、`max_cost_per_task=$0.50`、动作循环检测。
- **可观测性：** 接入 Langfuse。

### 🟢 重写一个"凑合能用"的提示词

> **你：** *这个提示词效果不稳定，请优化一下。*

Claude 加载 `prompt-engineering-expert` 并：
1. 锁定模型版本（你之前没锁）。
2. 构造 50 例保留评估集，覆盖正常用例、边缘用例和 5 个已知失败模式。
3. 用 **Structured Output**（模式 11）重写提示词，配显式 JSON Schema。
4. 影子模式 A/B 测试新版本。
5. 上线准确率更高且成本更低的版本。

### 🟢 为内部文档构建 MCP Server

> **你：** *我想做一个 Claude Desktop 集成，让模型能搜内部文档。*

Claude 加载 `mcp-server-builder` 并产出：
- **能力：** 1 个工具（`search_documents`）+ 1 个资源（`docs://{id}`）+ 1 个提示（`summarize-document`）。
- **项目：** TypeScript stdio server；`npm install && npm run dev` 启动。
- **注解：** `readOnlyHint: true`、`idempotentHint: true` —— 真实的安全标签。
- **用 MCP Inspector 测试** — 每个工具、资源、提示端到端验证。
- **Claude Desktop 配置** — 可直接复制的 JSON 片段。

---

## 📁 项目结构

```text
ai-app-dev-skills/
├── README.md
├── README.zh-CN.md
├── LICENSE
├── CLAUDE.md
├── skills/                              # Skill 包
│   ├── rag-pipeline-builder/
│   │   ├── SKILL.md
│   │   ├── references/                  # 分块 · 向量库 · 检索
│   │   └── scripts/validate-rag-pipeline.sh
│   ├── agent-architect/
│   │   ├── SKILL.md
│   │   ├── references/                  # 模式 · 多智能体 · 工具设计
│   │   └── scripts/validate-agent.sh
│   ├── prompt-engineering-expert/
│   │   ├── SKILL.md
│   │   └── references/                  # 25 种模式 · 评估 · 15 反模式
│   └── mcp-server-builder/
│       ├── SKILL.md
│       └── references/                  # 协议规范 · 6 个示例
├── scripts/                             # 仓库级工具
│   ├── install.sh                       # 本地 + 远程（curl | bash）
│   ├── validate.sh                      # SKILL.md frontmatter 校验
│   ├── test-validate.sh                 # 校验器 3 用例冒烟测试
│   └── generate-index.sh                # 自动生成上面的"快速索引"
├── references/                          # 跨 Skill 参考资料
├── examples/                            # 端到端示例
├── docs/
│   ├── CONTRIBUTING.md
│   ├── SKILL-AUTHORING-GUIDE.md
│   └── CHANGELOG.md
└── .github/
    ├── ISSUE_TEMPLATE/                  # bug · feature · skill request
    ├── pull_request_template.md
    └── workflows/validate-skills.yml
```

---

## 🤝 贡献指南

我们欢迎新 Skill、改进现有 Skill，以及被多个 Skill 引用的参考资料。

1. 通读 [`docs/SKILL-AUTHORING-GUIDE.md`](docs/SKILL-AUTHORING-GUIDE.md)。
2. 使用模板提交 **Skill request** issue —— 描述触发词、模式、配套资料。
3. 等待维护者确认范围。
4. 用模板提交 PR。CI 跑 `scripts/validate.sh`；必须通过。
5. 合并后，你的 Skill 自动出现在"快速索引"中 —— `scripts/generate-index.sh` 会在 CI 中重写 README。

完整指南见 [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md)。

---

## 🛠 兼容性

面向所有支持 Claude Code Skill 规范的工具：

| 工具 | 兼容性 | 备注 |
| --- | --- | --- |
| **Claude Code** | ✅ 主要支持 | 完整支持；软链安装可即时同步编辑。 |
| **Cursor** | ✅ | Skill 以斜杠命令等价物形式出现。 |
| **Windsurf** | ✅ | 通过 Claude Code Skill 适配器兼容。 |
| **Codex CLI** | ✅ | 通过 MCP 适配器层兼容。 |
| **其他** | ➡️ | 任何能加载 `SKILL.md` frontmatter + 正文的工具。 |

如果你的工具支持 SKILL.md 规范但未列出，请提交 issue，我们会补上。

---

## ⭐ Star 历史

如果这个 Skill 包为你节省了时间，欢迎点 Star —— 帮助更多人发现它。

<div align="center">

[![Star History Chart](https://api.star-history.com/svg?repos=liucx147/ai-app-dev-skills&type=Date)](https://star-history.com/#liucx147/ai-app-dev-skills&Date)

</div>

---

## 📄 许可证

[MIT](LICENSE) © 2026 AI App Dev Skills Contributors。

由一群厌倦了反复写同一套脚手架的 AI 工程师打造。🛠️
