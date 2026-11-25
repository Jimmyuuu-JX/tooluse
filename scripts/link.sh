#!/usr/bin/env bash
# 把 skills/ 和 third-party/ 下每个 skill 链接进 ~/.agents/skills（Codex、pi 直接读），
# 再在 ~/.claude/skills 建指向它的链接（Claude Code 只读这里）。
# 只补缺的链接、清掉已失效的链接；同名的实体目录或指向别处的链接一律不动，列出后以非零退出。
set -euo pipefail
cd "$(dirname "$0")/.."
repo=$(pwd -P)
agents=${TOOLUSE_AGENTS_DIR:-$HOME/.agents/skills}
claude=${TOOLUSE_CLAUDE_DIR:-$HOME/.claude/skills}
mkdir -p "$agents" "$claude"
conflict=0
same() { [ "$(cd "$1" 2>/dev/null && pwd -P)" = "$(cd "$2" 2>/dev/null && pwd -P)" ]; }
link() {
  local dest=$1 target=$2
  if [ -L "$dest" ] || [ -e "$dest" ]; then
    same "$dest" "$target" && return 0
    echo "冲突：$dest 已存在，没有指向 $target" >&2
    conflict=1
    return 0
  fi
  ln -s "$target" "$dest"
  echo "已链接 $dest"
}
for d in skills/*/ third-party/*/; do
  [ -f "${d}SKILL.md" ] || continue
  n=$(basename "$d")
  link "$agents/$n" "$repo/${d%/}"
  link "$claude/$n" "$agents/$n"
done
for l in "$agents"/* "$claude"/*; do
  [ -L "$l" ] && [ ! -e "$l" ] || continue
  case "$(readlink "$l")" in "$repo"/* | "$agents"/* | ../../.agents/skills/*)
    rm -- "$l"
    echo "已清掉失效链接 $l"
    ;;
  esac
done
exit "$conflict"
