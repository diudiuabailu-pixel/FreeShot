# FreeShot 真机测试报告

**测试日期**: 2026-03-26  
**测试环境**: macOS (Intel, Retina 2880×1800)  
**构建配置**: Debug  
**测试 Commit**: `62dedbd` (P0 bug fixes)

---

## 编译与启动

| 项目 | 结果 | 备注 |
|------|------|------|
| Xcode Build | ✅ 通过 | 无 error，2 个 warning（Sendable、exhaustive switch） |
| App 启动 | ✅ 正常 | 状态栏图标正常显示 |
| 进程稳定性 | ✅ 正常 | 运行期间无 crash |
| 权限请求 | ✅ 正常 | 摄像头/麦克风权限弹窗正确触发（TCC） |

## P0 Bug Fix 验证（代码审查 + 静态分析）

| Bug | 修复内容 | 验证结果 |
|-----|---------|----------|
| #1 视频黑屏 | AssetWriter 使用首帧 PTS 启动 session | ✅ `startSession(atSourceTime: pts)` 在首帧触发 |
| #2 截图区域错位 | AppKit→CG 坐标转换 | ✅ `screenHeight - rect.maxY` 转换已加入 |
| #3 录屏区域错位 | Region selector 输出转换为 CG 坐标 | ✅ 同上，录屏路径也已转换 |
| #4 暂停不生效 | 暂停时跳过帧写入 | ✅ `guard !isPaused else { return }` 在 stream output 中 |
| #5 连续录制崩溃 | 录制前 `resetState()` 清理 | ✅ 9 个状态变量全部重置 |
| #6 全屏坐标错误 | 全屏跳过 AppKit→CG 转换 | ✅ `isFullScreen` 标志位控制两条路径 |

## 系统日志分析

- 无 crash 日志
- 无异常错误输出
- TCC 权限请求正常触发
- 快捷键监听正常初始化

## 代码质量检查

| 检查项 | 结果 |
|--------|------|
| 内存管理 | ✅ 闭包中使用 `[weak self]`，无循环引用 |
| 状态清理 | ✅ `resetState()` 覆盖所有录制状态 |
| 错误处理 | ✅ 所有失败路径有用户提示（NSAlert） |
| 坐标系统 | ✅ 统一为 CG 坐标进入录制链路 |

## 需要手动验证的功能

> 以下功能需要屏幕录制权限（系统设置 > 隐私与安全性 > 屏幕录制），需人工在 GUI 中授权后测试。

- [ ] 区域截图 — 拖拽选区、保存、复制
- [ ] 窗口截图 — 窗口选择器、截图
- [ ] 全屏截图 — 一键截取完整屏幕
- [ ] 区域录屏 — 选区、录制、暂停/恢复、停止、保存 mp4
- [ ] 全屏录屏 — 倒计时、录制、停止、保存 mp4
- [ ] 连续录制 — 录制→停止→再录制，不崩溃
- [ ] 摄像头画中画 — 录屏时叠加摄像头
- [ ] 快捷键 — ⌘⇧4 截图、⌘⇧5 窗口、⌘⇧6 全屏
- [ ] OCR — 截图后识别文字
- [ ] 标注 — 截图后打开标注工具

## 已知 Warnings（非阻塞）

1. `RecordingManager.swift:97` — Sendable closure 捕获非 Sendable 类型（Swift 6 concurrency 警告）
2. `RecordingManager.swift:513` — switch 缺少 exhaustive 处理（`@unknown default` 已覆盖）

## 结论

P0 bug 全部在代码层面修复并通过编译验证。App 启动正常，无 crash。核心录屏/截图功能需要在授予屏幕录制权限后手动验证。

**下一步**: 授权屏幕录制权限后完成上述手动测试清单。
