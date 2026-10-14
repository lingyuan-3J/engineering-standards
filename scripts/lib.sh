#!/usr/bin/env bash

standards_home() {
  printf '%s\n' "${1:-${CODEX_HOME:-$HOME/.codex}}"
}

remote_identity() {
  local value="${1%/}"
  case "$value" in
    https://github.com/*) value="${value%.git}"; printf '%s\n' "github.com/${value#https://github.com/}" | tr '[:upper:]' '[:lower:]' ;;
    git@github.com:*) value="${value%.git}"; printf '%s\n' "github.com/${value#git@github.com:}" | tr '[:upper:]' '[:lower:]' ;;
    *) if [ -d "$value" ]; then (cd -- "$value" && pwd -P); else printf '%s\n' "$value"; fi ;;
  esac
}

assert_standards_repository() {
  local directory="$1" expected="$2" actual
  [ -e "$directory/.git" ] || { echo 'Not an independent standards checkout.' >&2; return 1; }
  actual="$(git -C "$directory" remote get-url origin)" || return 1
  [ "$(remote_identity "$actual")" = "$(remote_identity "$expected")" ] || { echo "Unexpected standards origin: $actual" >&2; return 1; }
  [ -f "$directory/00-规范目录.md" ] || { echo 'Standards index is missing.' >&2; return 1; }
}

update_standards_entry() {
  local codex_directory="$1" entry="$1/AGENTS.md" temporary count_begin count_end
  if [ -f "$codex_directory/AGENTS.override.md" ] && grep -q '[^[:space:]]' "$codex_directory/AGENTS.override.md"; then
    echo 'A non-empty AGENTS.override.md takes precedence. Resolve that entry before installing shared standards.' >&2
    return 1
  fi
  temporary="$(mktemp "$codex_directory/.standards-entry.XXXXXX")" || return 1
  if [ -f "$entry" ]; then
    count_begin="$(grep -c '^<!-- BEGIN engineering-standards -->$' "$entry" || true)"
    count_end="$(grep -c '^<!-- END engineering-standards -->$' "$entry" || true)"
    if [ "$count_begin" != "$count_end" ] || [ "$count_begin" -gt 1 ]; then
      rm -f -- "$temporary"
      echo 'Malformed shared standards entry; file left unchanged.' >&2
      return 1
    fi
  fi
  local block
  block="$(cat <<'ENTRY'
<!-- BEGIN engineering-standards -->
## 共享工程规范

中央规范位于当前 Codex 主目录的 standards/。Codex 主目录优先取 CODEX_HOME，未设置时取用户主目录下 .codex；不要相对于项目工作目录解析。

开始编码或修改技术文档前，必须显式读取 standards/00-规范目录.md 和本次任务适用的正文；Markdown 链接不会自动展开。编码阅读通用规范，再按当前技术栈及任务从目录选读对应规范；Python 项目同时读取 Python 规范，框架、数据库和 AI 接入按实际使用选读。编写文档阅读技术文档编写规范。随后阅读当前项目及子目录 AGENTS.md 和对应领域方案，遵循明确的项目补充及例外。

要求记录或更新规范时：跨项目规则修改 standards/ 的唯一正文；项目特有规则修改项目文档；业务实现修改领域方案。不要在项目复制维护通用规则。修改本仓库前阅读规范维护规范，提交和推送须处于用户授权范围。

同步使用 standards/scripts/sync.ps1（PowerShell）或 sync.sh（Bash），不得自动 reset、stash 或覆盖本地修改。同步后对正在进行的会话显式重新读取规范，不能假设历史上下文已经更新。
<!-- END engineering-standards -->
ENTRY
)"
  if [ -f "$entry" ] && [ "$count_begin" -eq 1 ]; then
    # Replace only the managed block; preserve its surrounding lines.
    STANDARDS_ENTRY_BLOCK="$block" awk '
      /^<!-- BEGIN engineering-standards -->$/ { if (inside || done) exit 2; print ENVIRON["STANDARDS_ENTRY_BLOCK"]; inside=1; next }
      /^<!-- END engineering-standards -->$/ { if (!inside) exit 2; inside=0; done=1; next }
      !inside { print }
      END { if (inside || !done) exit 2 }
    ' "$entry" > "$temporary" || { rm -f -- "$temporary"; echo 'Invalid entry markers; original preserved.' >&2; return 1; }
  else
    if [ -f "$entry" ]; then
      cat "$entry" > "$temporary"
      printf '\n\n' >> "$temporary"
    fi
    printf '%s\n' "$block" >> "$temporary"
  fi
  if [ -f "$entry" ] && cmp -s "$entry" "$temporary"; then rm -f -- "$temporary"; return 0; fi
  if [ -f "$entry" ]; then
    mkdir -p "$codex_directory/standards-backups"
    local backup
    backup="$(mktemp "$codex_directory/standards-backups/AGENTS-$(date +%Y%m%d-%H%M%S).XXXXXX")"
    cp -p "$entry" "$backup"
  fi
  mv -f -- "$temporary" "$entry"
}
