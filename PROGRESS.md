# 当前开发状态

- 状态：已完成，等待提交。
- 目标：统计热力图默认展示截至今天的最近 365 天，同时保留自然年历史统计。
- 已完成：新增最近一年聚合入口；默认选择“最近一年”；保留具体自然年选择；修正跨年月份标签；更新测试、README 和官网说明。
- 关键位置：`StatisticsAggregator.swift`、`StatisticsViewController.swift`、`ContributionHeatmapView.swift`、`SwitchEventStoreTests.swift`。
- 验证：`make test` 20 项通过；`make build` 通过；实际界面确认默认最近一年，并可切换到 2026 自然年视图。
- 下一步：用户确认后提交，并按 RULES.md 发布新版 DMG。
- 恢复命令：`make test && make build && open dist/InputSwitch.app`。
