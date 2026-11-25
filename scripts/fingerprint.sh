#!/usr/bin/env bash
# 打印一个第三方 skill 目录的内容指纹（不含 SOURCE.md）。取回时记进 SOURCE.md，自检时重算比对。
set -euo pipefail
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "用法：$0 <目录>" >&2; exit 64; }
cd "$1"
find . -type f ! -name SOURCE.md -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1
