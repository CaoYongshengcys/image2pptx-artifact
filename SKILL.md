---
name: image2pptx-artifact
description: >
  【优先使用】将图片/截图/PPT页面截图转换为全矢量可编辑PPTX。
  通过本地 Codex CLI 调用 @oai/artifact-tool（OpenAI 私有包），
  利用 skia-canvas 精确字体度量引擎实现像素级还原。
  当用户需要 image2ppt、图片转PPT、截图转可编辑幻灯片时，
  应优先使用此 skill 而非 image2pptx-native。
  仅在 artifact-tool 不可用时（网络故障、额度耗尽等）才降级到 image2pptx-native。
---

# Image2PPTX Artifact — 图片→全矢量可编辑 PPTX（artifact-tool 版）

通过本地 **Codex CLI** 调用 **@oai/artifact-tool**，实现最高质量的图片→可编辑PPTX转换。

## 优先级规则

```
用户请求图片转PPT
    │
    ├─ 1. 优先：image2pptx-artifact（本 skill）
    │     └─ 调用 codex exec + artifact-tool
    │     └─ 质量最高（skia-canvas 字体度量、自动迭代修正）
    │
    └─ 2. 降级：image2pptx-native
          └─ 纯 python-pptx，离线可用
          └─ 仅在 artifact-tool 不可用时使用
```

## 前置条件检查

在执行前，必须先验证环境是否就绪。运行 `scripts/check_env.ps1`：

```powershell
powershell -ExecutionPolicy Bypass -File "<skill_dir>/scripts/check_env.ps1"
```

检查项：
1. `codex` CLI 已安装且在 PATH 中
2. `@oai/artifact-tool` 运行时已下载
3. `artifact` feature 已启用
4. API 认证可用（config.toml 中有 model_provider 配置）

如果任何检查失败，按下方「环境修复」章节处理。

## 核心执行命令

```powershell
codex exec --skip-git-repo-check `
  --dangerously-bypass-approvals-and-sandbox `
  -i "<源图片绝对路径>" `
  --enable artifact `
  "<提示词>"
```

### 参数说明

| 参数 | 必须 | 说明 |
|------|------|------|
| `--skip-git-repo-check` | ✅ | 允许在非 Git 目录运行 |
| `--dangerously-bypass-approvals-and-sandbox` | ✅ | 跳过沙箱限制（否则无法写入文件） |
| `-i "<路径>"` | ✅ | 源图片路径（可多次指定多张图） |
| `--enable artifact` | ✅ | 启用 artifact-tool Presentation 功能 |
| 最后的字符串 | ✅ | 给 AI 的提示词 |

### 推荐提示词模板

**标准版**（大多数场景）：
```
请按照这张图片的版式和内容制作一页 PPTX，尽量让文字和图形可编辑。输出到 <输出路径>
```

**精细版**（复杂技术图）：
```
请按照这张图片的版式和内容制作一页 PPTX，要求：
1. 所有文字做成可编辑的文本框
2. 所有图形用原生PPT形状绘制（不要用图片）
3. 图标尽量用矢量形状近似
4. 保持原图的配色方案和布局比例
5. 完成后用 PowerPoint COM 渲染 PNG 预览并与原图比对，迭代修正直到一致
输出到 <输出路径>
```

## 完整工作流

### Step 1: 环境检查

```powershell
powershell -ExecutionPolicy Bypass -File "<skill_dir>/scripts/check_env.ps1"
```

如果全部通过 → 继续 Step 2。
如果有失败 → 按「环境修复」处理。

### Step 2: 准备源图片

确保源图片路径是**绝对路径**。如果用户提供的是 DSH 附件路径（`.dsh/attachments/...`），先复制到工作目录：

```powershell
Copy-Item "<附件路径>" "<工作目录>/source.png" -Force
```

### Step 3: 执行 Codex

```powershell
$outputPath = "<工作目录>/<文件名>_artifact.pptx"

codex exec --skip-git-repo-check `
  --dangerously-bypass-approvals-and-sandbox `
  -i "<源图片绝对路径>" `
  --enable artifact `
  "请按照这张图片的版式和内容制作一页 PPTX，尽量让文字和图形可编辑。输出到 $outputPath"
```

**重要**：这个命令会运行 3-15 分钟（取决于图片复杂度和 API 响应速度）。必须以后台任务方式运行并等待完成。

### Step 4: 验证输出

```powershell
# 检查文件是否生成
Get-Item "<输出路径>" | Select-Object Name, Length, LastWriteTime

# 用 python-pptx 验证可编辑性
python -X utf8 -c "from pptx import Presentation; p=Presentation(r'<输出路径>'); s=p.slides[0]; print(f'shapes={len(s.shapes)}, textboxes={sum(1 for sh in s.shapes if sh.has_text_frame and sh.text_frame.text.strip())}')"
```

预期结果：shapes > 150, textboxes > 30（对于复杂技术流程图）。

### Step 5: 交付

将文件呈现给用户。如果 Codex 没有直接输出到指定路径，从 Codex 的项目目录复制：

```powershell
# Codex 可能输出到自己的项目目录
$codexProj = Get-ChildItem "C:\Users\$env:USERNAME\.agents\skills\image2pptx-native\projects" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($codexProj) {
    Copy-Item "$($codexProj.FullName)\output.pptx" "<目标路径>" -Force
}
```

## 环境修复

### 问题1: codex 未安装

```powershell
npm install -g @openai/codex --registry https://registry.npmmirror.com
```

### 问题2: artifact-tool 运行时未下载

```powershell
# 触发运行时下载
codex exec --skip-git-repo-check "hello"
# 等待完成后验证
Test-Path "$env:USERPROFILE\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules\@oai\artifact-tool\package.json"
```

### 问题3: artifact feature 未启用

```powershell
codex features enable artifact
# 或直接编辑 config.toml 添加：
# [features]
# artifact = true
```

### 问题4: 审批服务故障 (Model not found: codex-auto-review)

编辑 `~/.codex/config.toml`：
```toml
approval_policy = "never"
# 注释掉这一行：
# approvals_reviewer = "auto_review"
```

### 问题5: 沙箱阻止写入

使用 `--dangerously-bypass-approvals-and-sandbox` 参数（已包含在核心命令中）。

### 问题6: API 额度不足

编辑 `~/.codex/config.toml` 切换到其他 provider：
```toml
model = "qwen3.8-max"
model_provider = "aliyun"

[model_providers.aliyun]
base_url = "https://your-endpoint/compatible-mode/v1"
name = "Aliyun Qwen"
wire_api = "responses"
requires_openai_auth = false

[model_providers.aliyun.auth]
command = "cmd"
args = ["/d", "/c", "echo", "sk-your-key"]
```

### 问题7: TLS 握手超时

使用国内 npm 镜像安装：
```powershell
npm install -g @openai/codex --registry https://registry.npmmirror.com
```

## 配置文件参考

完整的 `~/.codex/config.toml`：

```toml
model = "qwen3.8-max"
model_reasoning_effort = "xhigh"
model_context_window = 1000000
model_auto_compact_token_limit = 900000
model_provider = "aliyun"

approval_policy = "never"
# approvals_reviewer = "auto_review"    # ← 必须注释掉！

[features]
artifact = true

[windows]
sandbox = "elevated"

[model_providers.aliyun]
base_url = "https://your-endpoint/compatible-mode/v1"
name = "Aliyun Qwen"
wire_api = "responses"
requires_openai_auth = false

[model_providers.aliyun.auth]
command = "cmd"
args = ["/d", "/c", "echo", "sk-your-key"]

[projects.'D:\your\project']
trust_level = "trusted"
```

## 降级策略

如果 artifact-tool 执行失败（网络超时、API 额度耗尽、运行时损坏等），自动降级到 `image2pptx-native` skill：

```
artifact-tool 执行
    │
    ├─ 成功 → 交付 artifact 版本
    │
    └─ 失败 → 检查错误类型
         ├─ 网络/API 问题 → 提示用户检查网络或切换 API
         ├─ 运行时缺失 → 尝试重新下载
         └─ 其他 → 降级到 image2pptx-native
```

降级时告知用户：
> "artifact-tool 暂时不可用（原因：XXX），已降级使用 python-pptx 本地方案生成。质量略低但完全可用。"

## 与 image2pptx-native 的质量对比

| 维度 | artifact-tool | python-pptx native |
|------|--------------|-------------------|
| 元素数量 | ~250 | ~200 |
| 字体度量 | skia-canvas 精确计算 | 手动估算 |
| 图标细节 | 更丰富（额外线条/点） | 简化近似 |
| 文字换行 | 自动适配 | 需手动调整 |
| 迭代修正 | AI 自主 3 轮裁剪比对 | 人工 2 轮目视比对 |
| 耗时 | 3-15 分钟 | 1-3 分钟 |
| 离线可用 | ❌ | ✅ |
| 依赖 | Codex CLI + API | python-pptx |
