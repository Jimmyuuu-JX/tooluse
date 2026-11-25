#!/usr/bin/env bash
# 按 third-party/sources.tsv 从上游取回第三方 skill：整目录替换，写 SOURCE.md 和许可证全文。
# 只复制文件，不执行取回的任何内容。取回后先看 git diff，确认上游改了什么再提交。
# 用法：scripts/update-third-party.sh [名字...]，不给名字就全部取回。
set -euo pipefail
cd "$(dirname "$0")/.."
export GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/usr/bin/false
tmp=$(mktemp -d "${TMPDIR:-/tmp}/tooluse-fetch.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
today=$(date -u +%F)
found=0
while IFS=$'\t' read -r name repo path ref license; do
  case "$name" in '' | '#'*) continue ;; esac
  if [ "$#" -gt 0 ]; then
    hit=0
    for w in "$@"; do [ "$w" = "$name" ] && hit=1; done
    [ "$hit" -eq 1 ] || continue
  fi
  found=$((found + 1))
  [[ "$name" =~ ^[a-z0-9-]+$ && "$repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || { echo "sources.tsv 行不合法：$name $repo" >&2; exit 65; }
  case "/$path/$license/" in */../*) echo "$name 的路径含 ..：$path $license" >&2; exit 65 ;; esac
  clone="$tmp/${repo//\//_}@$ref"
  if [ ! -d "$clone" ]; then
    git clone -q --depth 1 --filter=blob:none --sparse --branch "$ref" "https://github.com/$repo.git" "$clone"
  fi
  git -C "$clone" sparse-checkout add "$path"
  [ -f "$clone/$path/SKILL.md" ] || { echo "$repo 的 $path 下没有 SKILL.md" >&2; exit 66; }
  [ ! -e "$clone/$path/SOURCE.md" ] || { echo "$repo 的 $path 自带 SOURCE.md，和本仓库的出处记录重名" >&2; exit 66; }
  sha=$(git -C "$clone" rev-parse HEAD)
  lic_id=${repo//\//-}
  [ "${license%/*}" = "$license" ] || { lic_dir=${license%/*}; lic_id="$lic_id-${lic_dir//\//-}"; }
  lic="licenses/LICENSE-$lic_id.txt"
  git -C "$clone" show "HEAD:$license" >"$lic"
  dest="third-party/$name"
  rm -rf -- "$dest"
  mkdir -p "$dest"
  cp -R "$clone/$path/." "$dest/"
  fp=$(scripts/fingerprint.sh "$dest")
  cat >"$dest/SOURCE.md" <<MD
# $name：第三方逐字副本，本地不编辑

| | |
|---|---|
| 上游 | [$repo/$path](https://github.com/$repo/tree/$sha/$path) |
| 跟随分支 | \`$ref\` |
| 钉住 SHA | \`$sha\` |
| 取回日期 | $today |
| 许可证 | $(head -1 "$lic")，全文见 [../../$lic](../../$lic) |
| 内容指纹 | \`$fp\` |

更新：\`scripts/update-third-party.sh $name\`。要改内容，复制到 \`skills/\` 换个名字，当自己的维护。
MD
  echo "已取回 $name ← $repo@${sha:0:8}"
done <third-party/sources.tsv
[ "$found" -gt 0 ] || { echo "sources.tsv 里没有要取回的条目：$*" >&2; exit 65; }
echo
git status --short -- third-party licenses
echo "先看 git diff -- third-party licenses，确认上游的改动，再提交。"
