# Engineering Standards

跨设备、跨项目共享的编码规范和技术文档规范。正文入口为 [规范目录](00-规范目录.md)，仓库只维护通用规则，业务细节留在各项目。

## 1 第一版内容

包括通用编码、技术文档、React、微信小程序、Django 及规范维护规则。规则按需阅读，不要求所有项目采用同一技术栈，也不复制某个项目的数据库、账号或开发进度。

## 2 Windows 安装

需要 Git 和 PowerShell。首次在 PowerShell 中执行：

```powershell
$codexDirectory = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
git clone https://github.com/lingyuan-3J/engineering-standards.git (Join-Path $codexDirectory 'standards')
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $codexDirectory 'standards/scripts/install.ps1')
```

如果目录已克隆，直接运行安装器，不再次 clone。`ExecutionPolicy Bypass` 只作用于这次脚本进程，不修改机器持久策略。也可使用 PowerShell 7 的 `pwsh`。

## 3 macOS 安装

macOS/Linux 需要 Git 和 Bash：

```bash
codex_directory="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$codex_directory"
git clone https://github.com/lingyuan-3J/engineering-standards.git "$codex_directory/standards"
bash "$codex_directory/standards/scripts/install.sh"
```

如果已克隆，直接运行安装器。脚本写入当前设备的路径，不依赖固定用户名。

## 4 日常同步

Windows：

```powershell
$codexDirectory = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $codexDirectory 'standards/scripts/sync.ps1')
```

macOS/Linux：

```bash
bash "${CODEX_HOME:-$HOME/.codex}/standards/scripts/sync.sh"
```

脚本快进更新并维护全局入口，检测本地修改、错误远端或分支偏离时失败并保留内容。Git 不会自动同步；第一版由你运行脚本，可放入个人开发启动流程。本仓库不默认创建后台任务。

## 5 更新规范

先同步，再直接编辑本地 `standards/` 中的正文；不要到项目复制修改。检查通过后提交推送：

```bash
git -C "${CODEX_HOME:-$HOME/.codex}/standards" add .
git -C "${CODEX_HOME:-$HOME/.codex}/standards" commit -m "docs: update engineering standards"
git -C "${CODEX_HOME:-$HOME/.codex}/standards" push
```

以上是 Bash 示例，PowerShell 使用实际 Codex 主目录。其他设备运行同步脚本获得新提交。冲突由维护者显式处理，脚本不会替你自动提交、推送、stash 或 reset。

## 6 项目接入

全局 `AGENTS.md` 只保留读取规范的托管入口，安装器保留其他个人指令并在修改前备份。项目的 AGENTS.md 保留本项目文档入口、技术栈、补充和例外。

```markdown
# 项目协作入口

遵循全局入口要求读取中央规范；项目补充规则见 docs/03-开发规范/。
实现领域功能前，从 docs/00-文档目录.md 查找并阅读对应方案。
通用规则更新到中央规范，项目规则更新到本项目。
```

项目或子目录规则可以覆盖全局默认，迁移时须清理无意保留的旧副本。安装器检测到非空 `AGENTS.override.md` 会停止，避免被覆盖的全局入口实际上没有生效。

## 7 生效方式

Codex 在开始运行时加载全局及项目 AGENTS.md；普通文档链接不会自动展开，入口明确要求读取适用正文。已经打开的会话在同步后显式要求重新读取，新会话按入口使用。可以问 Codex“列出本次读取的规范及规范仓库提交号”核对来源。

官方机制见 [AGENTS.md 文档](https://learn.chatgpt.com/docs/agent-configuration/agents-md)。本仓库采用本地 Git 同步，没有声称 Codex 账号会自动同步这些文件。

## 8 本地验证

```powershell
pwsh -NoProfile -File scripts/check-docs.ps1
pwsh -NoProfile -File tests/scripts.test.ps1
```

```bash
bash tests/scripts.test.sh
```

脚本测试使用独立临时仓库和临时 Codex 目录，不修改真实个人入口，不访问真实业务库。测试覆盖首次安装、重复安装、旧入口保留、快进同步和冲突拒绝。
