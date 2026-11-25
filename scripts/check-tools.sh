#!/usr/bin/env bash
# 本机核对：Claude Code、Codex、pi 是否都能加载本仓库的每个 skill。不调用模型；只在本机跑，CI 不跑。
# Codex 问 app-server 的 skills/list，pi 用它自己的加载代码，Claude 看 ~/.claude/skills 下的链接能否读到 SKILL.md。
set -uo pipefail
cd "$(dirname "$0")/.."
names=$(for d in skills/*/ third-party/*/; do [ -f "${d}SKILL.md" ] && basename "$d"; done)
fail=0

claude_missing=""
for n in $names; do [ -f "$HOME/.claude/skills/$n/SKILL.md" ] || claude_missing="$claude_missing $n"; done

codex=${CODEX_BIN:-$(command -v codex || echo /Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex)}
if [ -x "$codex" ]; then
  codex_json=$( (printf '%s\n' \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"tooluse-check","version":"0"}}}' \
    '{"jsonrpc":"2.0","method":"initialized"}' \
    "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"skills/list\",\"params\":{\"cwds\":[\"$HOME\"]}}"
    sleep 6) | "$codex" app-server 2>/dev/null)
  codex_names=$(printf '%s\n' "$codex_json" | python3 -c '
import sys, json
for line in sys.stdin:
    try: m = json.loads(line)
    except ValueError: continue
    if m.get("id") != 2: continue
    def walk(x):
        if isinstance(x, dict):
            if isinstance(x.get("name"), str) and "path" in x: print(x["name"])
            for v in x.values(): walk(v)
        elif isinstance(x, list):
            for v in x: walk(v)
    walk(m.get("result"))')
else
  codex_names="<no-codex>"
fi

pi_js=${PI_SKILLS_JS:-}
if [ -z "$pi_js" ] && command -v pi >/dev/null 2>&1; then
  d=$(dirname "$(readlink -f "$(command -v pi)")")
  while [ "$d" != / ] && [ ! -f "$d/dist/core/skills.js" ]; do d=$(dirname "$d"); done
  pi_js="$d/dist/core/skills.js"
fi
if [ -f "$pi_js" ]; then
  pi_names=$(PI_JS="$pi_js" node --input-type=module -e '
const m = await import(process.env.PI_JS);
const r = m.loadSkills({ cwd: process.env.HOME, includeDefaults: true, skillPaths: [process.env.HOME + "/.agents/skills"] });
for (const s of r.skills) console.log(s.name);')
else
  pi_names="<no-pi>"
fi

for n in $names; do
  row="$n:"
  case " $claude_missing " in *" $n "*) row="$row claude✗" ; fail=1 ;; *) row="$row claude✓" ;; esac
  if printf '%s\n' "$codex_names" | grep -qxF "$n"; then row="$row codex✓"; else row="$row codex✗"; fail=1; fi
  if printf '%s\n' "$pi_names" | grep -qxF "$n"; then row="$row pi✓"; else row="$row pi✗"; fail=1; fi
  echo "$row"
done
[ "$fail" -eq 0 ] && echo "三端都能加载全部 skill。" || echo "有工具加载不到，见上面的 ✗。"
exit "$fail"
