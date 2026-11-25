# 改这个库的规矩

1. **不为 Skill 新增 CI、门禁脚本、vendor 副本或自动指标。** `scripts/self-check.sh` 是唯一自检脚本；
   `link.sh`、`update-third-party.sh`、`fingerprint.sh` 只管链接和取回，不参与 CI 之外的决策、度量或新增权限。
2. **一个 Skill 连续 3 个真实任务没改变过行为就删掉。** 不降级、不“先留着”；git 历史保留。删掉后重跑 `scripts/link.sh` 清掉失效链接。
3. **第三方 skill 不手改。** 只用 `update-third-party.sh` 取回；要改就复制到 `skills/` 换名字。

改动理由写在 commit message，不另设变更账本；同一事实有两份，必有一份先烂。
常驻块是唯一无条件读取的成本，应保持简短；修改时优先删重复事实，不用字数上限代替语义检查。

本地跑 `scripts/self-check.sh --strict` 前先 `python3 -m pip install pyyaml`：缺它时官方 validator 只能跳过，
而严格模式把跳过算作失败，红的原因与改动无关。CI 的依赖安装见 `.github/workflows/self-check.yml`。
