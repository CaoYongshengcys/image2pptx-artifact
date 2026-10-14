# image2pptx-artifact

**将图片/截图转换为全矢量可编辑 PPTX** — 通过本地 Codex CLI 调用 `@oai/artifact-tool`，利用 skia-canvas 精确字体度量引擎实现像素级还原。

<p align="center">
  <img src="https://raw.githubusercontent.com/CaoYongshengcys/image2pptx-native/main/examples/tech_flowchart_2/original_inputs/source.png" width="45%" alt="Source"/>
  &nbsp;&nbsp;→&nbsp;&nbsp;
  <img src="https://raw.githubusercontent.com/CaoYongshengcys/image2pptx-native/main/examples/tech_flowchart_2/diagnostics/render.png" width="45%" alt="Result"/>
  <br/>
  <sub>左：源图（PNG 截图） → 右：生成的可编辑 PPTX 渲染结果（250 个原生元素，0 张位图）</sub>
</p>

> ⚠️ **本 Skill 需要配套 [OpenAI Codex CLI](https://github.com/openai/codex) 使用。** 它是一个 AI Agent Skill，不能独立运行——必须由 DSH / Codex CLI / Claude Code 等 AI 编码助手加载后，由 AI 调用 `codex exec` 来执行。

## ✨ 特性

- **最高质量还原** — skia-canvas 精确字体度量，文字排版像素级准确
- **AI 自主迭代** — Codex 自动进行 3 轮"渲染→裁剪比对→修正"循环
- **100% 矢量可编辑** — 所有文字为原生文本框，所有图形为原生 PPT 形状
- **0 张位图** — 图标全部用 MSO 形状 + 自由形状程序化绘制
- **全局 Skill** — 安装后在任何 DSH / Codex 会话中自动生效
- **自动降级** — 配合 [`image2pptx-native`](https://github.com/CaoYongshengcys/image2pptx-native) 使用，artifact-tool 不可用时自动降级到纯 python-pptx 方案

## 📋 前置条件

| 依赖 | 必须 | 说明 |
|------|------|------|
| [OpenAI Codex CLI](https://github.com/openai/codex) | ✅ | `npm install -g @openai/codex` |
| Node.js 18+ | ✅ | Codex CLI 运行时 |
| `@oai/artifact-tool` 运行时 | ✅ | Codex 首次使用时自动下载 |
| API Key（OpenAI / 第三方代理） | ✅ | 需要支持视觉理解的多模态模型 |
| PowerPoint（可选） | ❌ | 仅用于渲染验证 |

## 🚀 快速开始

### 1. 安装 Codex CLI

```powershell
# Windows（推荐用国内镜像）
npm install -g @openai/codex --registry https://registry.npmmirror.com

# macOS
brew install --cask codex

# 验证
codex --version
```

### 2. 配置 API

编辑 `~/.codex/config.toml`：

```toml
# ===== 模型配置 =====
model = "qwen3.8-max"                    # 或其他支持视觉的模型
model_provider = "aliyun"                 # provider 名称

# ===== 审批配置（重要！）=====
approval_policy = "never"                 # 自动执行，不弹窗
# approvals_reviewer = "auto_review"      # ← 必须注释掉！否则报错

# ===== 启用 artifact 功能 =====
[features]
artifact = true                           # 关键！默认关闭

# ===== Windows 沙箱 =====
[windows]
sandbox = "elevated"

# ===== API Provider =====
[model_providers.aliyun]
base_url = "https://your-endpoint/compatible-mode/v1"
name = "Aliyun Qwen"
wire_api = "responses"
requires_openai_auth = false

[model_providers.aliyun.auth]
command = "cmd"
args = ["/d", "/c", "echo", "sk-your-api-key-here"]
```

> **支持的 API 提供商**：OpenAI 官方、阿里云百炼、Aizex、或任何兼容 OpenAI Responses API 的代理。模型必须支持**视觉理解**（能看懂图片）。

### 3. 安装 Skill

```powershell
# DSH (DeepSeek Harness)
git clone https://github.com/CaoYongshengcys/image2pptx-artifact.git ~/.agents/skills/image2pptx-artifact

# Codex CLI
git clone https://github.com/CaoYongshengcys/image2pptx-artifact.git ~/.codex/skills/image2pptx-artifact

# Claude Code
git clone https://github.com/CaoYongshengcys/image2pptx-artifact.git ~/.claude/skills/image2pptx-artifact
```

### 4. 验证环境

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_env.ps1
```

预期输出：
```
[1/5] Checking Codex CLI ........... OK (codex-cli 0.162.1)
[2/5] Checking artifact-tool ....... OK (v2.6.9)
[3/5] Checking artifact feature .... OK (enabled)
[4/5] Checking API provider ........ OK (provider: aliyun)
[5/5] Checking approval policy ..... OK (never)

ALL CHECKS PASSED ✅
```

### 5. 使用

对 AI 说：**"把这张图片转成可编辑PPT"**

AI 会自动：
1. 加载 `image2pptx-artifact` skill
2. 运行环境检查
3. 调用 `codex exec` 执行转换
4. 等待 Codex 完成（3-15 分钟）
5. 验证输出并交付

## 🔧 手动执行命令

如果不通过 AI Skill，也可以直接在终端运行：

```powershell
codex exec --skip-git-repo-check `
  --dangerously-bypass-approvals-and-sandbox `
  -i "D:\path\to\source_image.png" `
  --enable artifact `
  "请按照这张图片的版式和内容制作一页 PPTX，尽量让文字和图形可编辑。输出到 D:\path\to\output.pptx"
```

### 参数说明

| 参数 | 说明 |
|------|------|
| `--skip-git-repo-check` | 允许在非 Git 目录运行 |
| `--dangerously-bypass-approvals-and-sandbox` | 跳过沙箱限制（否则无法写入文件） |
| `-i "<路径>"` | 源图片绝对路径（可多次指定） |
| `--enable artifact` | 启用 artifact-tool Presentation 功能 |
| 最后的字符串 | 给 AI 的提示词 |

## 🏗️ 工作原理

```
用户上传图片
    │
    ▼
DSH / AI Agent 加载 image2pptx-artifact skill
    │
    ▼
运行 check_env.ps1 验证环境
    │
    ▼
调用 codex exec --dangerously-bypass-approvals-and-sandbox
    │         -i "图片.png" --enable artifact "提示词"
    │
    ▼
Codex CLI 内部流程：
    ├── 1. LLM 分析图片（识别版式、文字、图标、颜色、坐标）
    ├── 2. 加载 PowerPoint Skill (SKILL.md)
    ├── 3. 确认 @oai/artifact-tool 运行时可用
    ├── 4. 初始化项目目录 + node_modules 链接
    ├── 5. 编写 .mjs 构建脚本（使用 artifact-tool API）
    ├── 6. Node.js 执行构建 → 生成 PPTX
    ├── 7. skia-canvas 渲染 PNG 预览
    ├── 8. 与原图比对，修正偏差（最多 3 轮）
    └── 9. 输出最终 .pptx
    │
    ▼
AI 验证输出 → 交付给用户
```

### artifact-tool 架构

```
┌──────────────────────────────────────────────┐
│              Codex CLI (Rust)                 │
│  ┌──────────┐  ┌─────────┐  ┌─────────────┐ │
│  │ LLM Agent│→ │  Skill   │→ │artifact-tool│ │
│  │(qwen/gpt)│  │  Loader  │  │  (Node.js)  │ │
│  └──────────┘  └─────────┘  └──────┬──────┘ │
│                                     │        │
│                            ┌────────▼──────┐ │
│                            │ skia-canvas   │ │
│                            │(字体度量/渲染) │ │
│                            └────────┬──────┘ │
│                                     │        │
│                            ┌────────▼──────┐ │
│                            │ PPTX Export   │ │
│                            │ (OOXML 生成)  │ │
│                            └───────────────┘ │
└──────────────────────────────────────────────┘
```

## 🔄 与 image2pptx-native 的配合

本 Skill 设计为与 [`image2pptx-native`](https://github.com/CaoYongshengcys/image2pptx-native) 配合使用：

```
用户请求图片转PPT
    │
    ├─ 优先：image2pptx-artifact（本仓库）
    │     • 质量最高（skia-canvas 字体度量）
    │     • AI 自主 3 轮迭代修正
    │     • ~250 元素
    │     • 需要联网 + API
    │
    └─ 降级：image2pptx-native
          • 纯 python-pptx，零依赖
          • 完全离线可用
          • ~200 元素
          • 秒级重建
```

**建议同时安装两个 Skill**，AI 会自动选择最优方案。

### 质量对比

| 维度 | artifact-tool | python-pptx native |
|------|--------------|-------------------|
| 元素数量 | ~250 | ~200 |
| 字体度量 | skia-canvas 精确计算 | 手动估算 |
| 图标细节 | 更丰富 | 简化近似 |
| 文字换行 | 自动适配 | 需手动调整 |
| 迭代修正 | AI 自主 3 轮裁剪比对 | 人工 2 轮目视 |
| 耗时 | 3-15 分钟 | 1-3 分钟 |
| 离线可用 | ❌ | ✅ |
| 费用 | API 调用费 | 免费 |

## 🐛 常见问题

### Q: `Model not found: codex-auto-review`

在 `config.toml` 中注释掉 `approvals_reviewer = "auto_review"`。

### Q: `sandbox: read-only` 写入失败

使用 `--dangerously-bypass-approvals-and-sandbox` 参数。

### Q: artifact-tool 运行时未找到

运行一次 `codex exec --skip-git-repo-check "hello"` 触发自动下载。

### Q: API 额度不足

在 `config.toml` 中切换到其他 provider，或等待额度重置。

### Q: TLS 握手超时

使用国内 npm 镜像：`npm install -g @openai/codex --registry https://registry.npmmirror.com`

详见 [完整操作手册](https://github.com/CaoYongshengcys/image2pptx-native/blob/main/docs/artifact-tool-guide.md)。

## 📁 项目结构

```
image2pptx-artifact/
├── README.md              # 本文件
├── SKILL.md               # AI Agent Skill 定义（DSH/Codex/Claude Code 自动识别）
├── LICENSE                # MIT License
└── scripts/
    └── check_env.ps1      # 环境检查脚本（5 项自动检测）
```

## 📄 License

MIT License — 详见 [LICENSE](LICENSE)

## 🙏 致谢

- [OpenAI Codex CLI](https://github.com/openai/codex) — 本地 AI 编码助手
- `@oai/artifact-tool` — OpenAI 私有 Presentation API（通过 Codex 运行时自动获取）
- [image2pptx-native](https://github.com/CaoYongshengcys/image2pptx-native) — 离线降级方案
