#!/usr/bin/env bash
# 只检查可判定结构不变量；内容正确性仍需人和独立复核。
set -uo pipefail
cd "$(dirname "$0")/.."
# skills/ 或 third-party/ 可能为空，未匹配的 glob 不能留成字面量去遍历
shopt -s nullglob
fail=0 skipped=0 strict=0
note() {
  echo "  ✗ $1"
  fail=1
}
skip() {
  echo "  – $1"
  skipped=$((skipped + 1))
}
usage() { echo "用法：$0 [--strict]" >&2; }
[ "$#" -le 1 ] || {
  usage
  exit 64
}
case "${1:-}" in "") ;; --strict) strict=1 ;; *)
  usage
  exit 64
  ;;
esac

echo "① frontmatter name 与目录名一致"
for d in skills/*/ third-party/*/; do
  n=$(basename "$d") f="${d}SKILL.md"
  [ -f "$f" ] || {
    note "$n 缺 SKILL.md"
    continue
  }
  [ "$n" = "$(awk '/^name:/{print $2;exit}' "$f")" ] || note "$n 的 name 不匹配"
done

echo "② 自己的 skill 过官方 validator"
validator=""
for c in scripts/vendor/quick_validate.py "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" "$HOME/.claude/skills/.system/skill-creator/scripts/quick_validate.py"; do
  [ -f "$c" ] && {
    validator=$c
    break
  }
done
if [ -z "$validator" ]; then
  note "缺 validator"
elif ! python3 -c 'import yaml' 2>/dev/null; then
  skip "缺 PyYAML，validator 未运行"
else
  # 第三方 skill 按上游格式写，可能用到 validator 不认的字段，不归本仓库修
  for d in skills/*/; do
    [ -f "${d}SKILL.md" ] && python3 "$validator" "$d" >/dev/null 2>&1 || note "$(basename "$d") 未通过 validator"
  done
fi

echo "③ 第三方 skill 与来源清单一一对应、出处完整"
listed=$(grep -vE '^(#|$)' third-party/sources.tsv 2>/dev/null | cut -f1)
for n in $listed; do
  [ -d "third-party/$n" ] || note "sources.tsv 登记的 $n 没有目录"
done
for d in third-party/*/; do
  n=$(basename "$d") s="${d}SOURCE.md"
  printf '%s\n' "$listed" | grep -qxF "$n" || note "third-party/$n 未登记在 sources.tsv"
  [ -f "$s" ] || {
    note "third-party/$n 缺 SOURCE.md"
    continue
  }
  grep -qE '`[0-9a-f]{40}`' "$s" || note "third-party/$n/SOURCE.md 缺 SHA"
  grep -q '许可证' "$s" || note "third-party/$n/SOURCE.md 缺许可证"
  lic=$(grep -oE 'licenses/LICENSE-[A-Za-z0-9._-]+\.txt' "$s" | head -1)
  [ -n "$lic" ] && [ -f "$lic" ] || note "third-party/$n 的许可证全文不在 licenses/"
done
grep -q 'third-party/' NOTICE 2>/dev/null || note "NOTICE 未登记 third-party/"

echo "④ 自己的 skill 不带 SOURCE.md，也不和第三方重名"
for d in skills/*/; do
  n=$(basename "$d")
  [ ! -f "${d}SOURCE.md" ] || note "skills/$n 带 SOURCE.md：第三方副本应放 third-party/"
  [ ! -d "third-party/$n" ] || note "$n 同时在 skills/ 和 third-party/"
done

echo "⑤ 第三方内容没被手改"
for d in third-party/*/; do
  n=$(basename "$d") s="${d}SOURCE.md"
  [ -f "$s" ] || continue
  want=$(grep '内容指纹' "$s" | grep -oE '[0-9a-f]{64}' | head -1)
  [ -n "$want" ] || {
    note "third-party/$n/SOURCE.md 缺内容指纹"
    continue
  }
  [ "$(scripts/fingerprint.sh "$d")" = "$want" ] || note "third-party/$n 与取回时的指纹不一致（被手改过？要改就复制到 skills/）"
done

echo "⑥ vendor 副本出处完整、没有本地改动"
[ -f scripts/vendor/SOURCE.md ] || note "vendor 缺 SOURCE.md"
grep -qE '`[0-9a-f]{40}`' scripts/vendor/SOURCE.md 2>/dev/null || note "vendor 缺 SHA"
[ -f licenses/LICENSE-anthropics-skills.txt ] || note "缺 Anthropic 许可证"
grep -q 'scripts/vendor' NOTICE 2>/dev/null || note "NOTICE 未登记 vendor"
dirty=$(git status --porcelain -- scripts/vendor | grep -vE 'SOURCE\.md|__pycache__' | wc -l | tr -d ' ')
[ "$dirty" -eq 0 ] || note "vendor 有 $dirty 个本地改动"

echo "⑦ 仓库内相对链接可落地"
python3 - <<'PY' || fail=1
import glob,os,re,sys
bad=[]
for path in glob.glob('**/*.md',recursive=True):
    if '.git' in path: continue
    text=open(path,encoding='utf-8').read()
    text=re.sub(r'```.*?```','',text,flags=re.S); text=re.sub(r'`[^`\n]*`','',text)
    for m in re.finditer(r'\]\((?!https?:|mailto:|#)([^)]+)\)',text):
        dest=m.group(1).split('#')[0].strip(); dest=re.split(r'\s+["\']',dest)[0]
        if dest and not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(path) or '.',dest))): bad.append(f'{path} → {dest}')
for item in bad: print(f'  ✗ 断链 {item}')
sys.exit(bool(bad))
PY

echo "⑧ 顶层许可证与 NOTICE 划清边界"
[ -f LICENSE ] && grep -q 'Permission is hereby granted' LICENSE || note "LICENSE 不是 MIT 正文"
[ -f NOTICE ] && grep -q 'SOURCE.md' NOTICE || note "NOTICE 缺判别方法"
grep -q 'NOTICE' README.md || note "README 未指向 NOTICE"

echo "⑨ 随包脚本自检"
if command -v node >/dev/null 2>&1; then
  node skills/project-doc-system/scripts/init-docs.mjs --self-test >/dev/null 2>&1 || note "init-docs 自检失败"
else skip "没有 node，跳过随包脚本自检"; fi
link_tmp=$(mktemp -d "${TMPDIR:-/tmp}/tooluse-link.XXXXXX")
link_run() { TOOLUSE_AGENTS_DIR="$link_tmp/agents" TOOLUSE_CLAUDE_DIR="$link_tmp/claude" bash scripts/link.sh "$@"; }
if link_run >/dev/null 2>&1; then
  for d in skills/*/ third-party/*/; do
    n=$(basename "$d")
    [ -f "$link_tmp/claude/$n/SKILL.md" ] || note "link.sh 没让 $n 经 Claude 目录可读"
  done
  [ -z "$(link_run 2>&1)" ] || note "link.sh 重跑不是零输出"
  ln -s "$link_tmp/nowhere" "$link_tmp/agents/gone-skill"
  link_run >/dev/null 2>&1
  [ ! -L "$link_tmp/agents/gone-skill" ] && note "link.sh 清掉了不指向本仓库的失效链接"
  rm -f "$link_tmp/agents/gone-skill"
  ln -s "$(pwd -P)/skills/gone-skill" "$link_tmp/agents/gone-skill"
  link_run >/dev/null 2>&1
  [ -L "$link_tmp/agents/gone-skill" ] && note "link.sh 没清掉指向本仓库已删 skill 的链接"
  first=$(basename "$(ls -d skills/*/ | head -1)")
  rm "$link_tmp/agents/$first" && mkdir "$link_tmp/agents/$first" && touch "$link_tmp/agents/$first/keep"
  link_run >/dev/null 2>&1 && note "link.sh 遇到同名实体目录没有报错"
  [ -f "$link_tmp/agents/$first/keep" ] || note "link.sh 动了同名实体目录"
else
  note "link.sh 在空目录上失败"
fi
rm -rf -- "$link_tmp"

echo "⑩ 常驻路由与共享块"
python3 - <<'PY' || fail=1
import collections,glob,os,re,sys
expected={
 'authority-boundary': {'README.md','skills/evidence-led-reviewer/SKILL.md','skills/project-doc-system/SKILL.md'},
 'impact-triggers': {'resident/tooluse-resident.md'},
}
authority={'authority-boundary':'README.md','impact-triggers':'resident/tooluse-resident.md'}
mark=re.compile(r'<!--\s*shared:([a-z0-9-]+):(start|end)\s*-->')
blocks=collections.defaultdict(dict); bad=False
for path in glob.glob('**/*.md',recursive=True):
    if '.git' in path: continue
    text=open(path,encoding='utf-8').read(); open_key=None; body_start=0
    for m in mark.finditer(text):
        key,kind=m.groups()
        if kind=='start':
            if open_key is not None: print(f'  ✗ {path}：共享块嵌套或交叉'); bad=True
            open_key,body_start=key,m.end()
        elif open_key is None or key!=open_key:
            print(f'  ✗ {path}：共享块 end 无对应 start'); bad=True
        else:
            if path in blocks[key]: print(f'  ✗ {path}：共享块 {key} 重复'); bad=True
            blocks[key][path]=text[body_start:m.start()]; open_key=None
    if open_key is not None: print(f'  ✗ {path}：共享块 {open_key} 未闭合'); bad=True
for key in set(expected)|set(blocks):
    want=expected.get(key); got=set(blocks.get(key,{}))
    if want is None: print(f'  ✗ 未登记共享块 {key}：{sorted(got)}'); bad=True; continue
    if got != want: print(f'  ✗ 共享块 {key} 消费者不符：期望 {sorted(want)}，实际 {sorted(got)}'); bad=True; continue
    source=blocks[key][authority[key]]
    for path in got:
        if blocks[key][path] != source: print(f'  ✗ 共享块 {key} 在 {path} 漂移'); bad=True
resident='resident/tooluse-resident.md'
# 只搜标题会假绑：保留「判定」标题、删掉下面九类触发条件，旧版仍然放行。
# 所以逐类检查触发条件本体，而不是它们的容器。
need=['**子代理。**','**验证沉淀。**','**判定。**','**实施。**','**独立复核门。**','回退目标条件','固定工作树快照','放宽、删除或改写验收条件','真正独立','需求来源','未独立复核']
triggers=[
 ('认证与权限',['认证','权限','同意']),
 ('资金与计费',['支付','计费','资金']),
 ('凭据与敏感数据',['凭据','隐私','客户']),
 ('数据变更',['迁移','删除','批量改写','schema']),
 ('对外契约',['对外 API','协议','兼容契约']),
 ('并发与一致性',['并发','事务','幂等','一致性']),
 ('基础设施与供应链',['基础设施','网络边界','密钥','供应链']),
 ('发布与生产接触',['外部可访问','生产数据','生产凭据']),
 ('不可逆操作',['不可逆','不能可靠恢复']),
]
if not os.path.exists(resident): print(f'  ✗ 缺 {resident}'); bad=True
else:
    text=open(resident,encoding='utf-8').read()
    missing=[x for x in need if x not in text]
    if missing: print(f'  ✗ 常驻路由缺关键语义：{missing}'); bad=True
    block=blocks.get('impact-triggers',{}).get(resident,'')
    for label,needles in triggers:
        if not all(n in block for n in needles):
            print(f'  ✗ 高影响触发条件缺「{label}」（需：{needles}）'); bad=True
prompt='skills/evidence-led-reviewer/assets/reviewer-role-prompt.md'
def sections(text):
    out=collections.defaultdict(str); current=''
    for line in text.splitlines():
        if line.startswith('## '): current=line[3:].strip()
        else: out[current]+=line+'\n'
    return out
checks={'': ['derived-copy:'], '本次输入':['需求来源','执行方转述不算','Baseline SHA','Candidate','固定工作树快照'], '工作方式':['未跟踪文件','审前审后','不要求用户先提交','按风险选择','不能授予工具','已批准','未授权处理','宿主'], '定级':['阻塞：','不阻塞：','重审新 candidate'], '输出':['产品正确性只能写「未验证」','顶层只能是「未验证」','不得给可发布结论','仓库内已验证']}
if not os.path.exists(prompt): print(f'  ✗ 缺派生模板 {prompt}'); bad=True
else:
    parts=sections(open(prompt,encoding='utf-8').read())
    for section,needles in checks.items():
        missing=[n for n in needles if n not in parts.get(section,'')]
        if missing: print(f'  ✗ 模板 {section or "头部"} 缺 {missing}'); bad=True
sys.exit(bad)
PY

echo
if [ "$fail" -ne 0 ]; then
  echo "有失败项。"
elif [ "$skipped" -gt 0 ]; then
  echo "没有失败项，但有 $skipped 项被跳过——本次结果不构成全部通过。"
  [ "$strict" -eq 0 ] || {
    echo "严格模式下，跳过项视为未通过。"
    fail=2
  }
else echo "全部通过。"; fi
exit "$fail"
