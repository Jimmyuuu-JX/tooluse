---
name: ux-review
description: Review and fix a product's user experience by eight principles (complexity belongs to the system, not the user). Use when building or changing user-facing UI, interaction or copy, to check that change against the principles; run the full audit-and-fix pass only when the user asks to review the experience of a product or area (体验审查, 按体验原则审一遍, 优化用户体验).
---

# 体验审查

总原则：复杂应该留给系统，不要留给用户，用户体验至高无上。

## 八条原则

- 系统能判断的，不留给用户
- 此刻没用的，就不出现
- 能替人做的，就直接做
- 同一件事，处处一样
- 按下去有回应，再按能收回
- 不打断人手上的事
- 常用的好做，会丢东西的难误碰
- 界面自己说明自己

## 两种用法

- **顺手对照**：做界面、交互或文案改动时，用八条检查这次改动本身，不借机扩大范围。
- **专项审查**：用户要求审查某个产品或区域的体验时，按下面的流程走。范围按用户说的；没说就是当前项目用户看得到的全部界面。

## 专项审查流程

1. 先把产品真正用一遍，按八条记下问题，每条写清在哪、用户会遇到什么、违反哪条。只从代码推出来的问题先算猜测，在界面里确认后才算数。
2. 需要第二视角时，另找一个独立的审查方当方案、文案、交互顾问：给它产品和这八条，不给自己的结论。
3. 直接修好。仓库有自己的界面规则时，以仓库规则为准。
4. 修完亲手用一遍确认，像用户一样点真实的控件；再请独立审查方复核这次改动。
5. 提交、合并、上线按所在仓库的规则和用户的授权进行，本 skill 不授予这些权限。
