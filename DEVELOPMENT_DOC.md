# FreeShot 开发文档

> **注意**：本文档不包含任何个人身份信息，仅记录项目技术细节与开发进展。

---

## 一、项目概述

| 项目 | 内容 |
|------|------|
| **项目名称** | FreeShot |
| **类型** | macOS 截图/录屏工具 |
| **目标用户** | 自媒体创作者 |
| **技术栈** | Swift + SwiftUI + AppKit + ScreenCaptureKit |
| **最低系统** | macOS 13.0+ |
| **许可证** | MIT |

### 核心功能

- ✅ 截图：区域 / 窗口 / 全屏
- ✅ 录屏：区域 / 全屏（支持摄像头画中画）
- ✅ 快捷键支持
- ✅ 截图预览、标注、OCR
- ✅ 视频转 GIF、视频裁剪
- ✅ 截图历史记录
- ✅ 多显示器支持
- ⚙️ 设置面板（开发中）

---

## 二、开发历程

### 2026-03-26 — P0 关键 Bug 修复

**问题**：录屏出现黑屏/空文件、截图区域偏差、暂停无效、连续录制崩溃。

**修复内容**：
1. **AssetWriter 时间戳** — 使用首帧 PTS 启动 session，避免黑屏
2. **坐标系统** — AppKit (bottom-left) → CG (top-left) 转换
3. **暂停功能** — 添加 `isPaused` 标记，跳过暂停时的帧写入
4. **状态清理** — 新增 `resetState()` 方法，防止连续录制崩溃
5. **全屏路径** — 分离全屏与区域录屏的坐标处理

**Commit**: `62dedbd`

### 2026-03-26 — UI 接线与功能完善

**问题**：History/Settings 按钮空壳、截图选项无法交互、GIF 导出可能卡死、窗口截图无预览。

**修复内容**：
1. **History 按钮** → 打开截图历史窗口
2. **Settings 按钮** → 打开设置面板（图片格式、保存位置、视频质量、快捷键说明）
3. **Screenshot 选项** → 从 `.constant()` 改为 `@State` 绑定（可交互）
4. **GIF 导出** → 修复 completion 回调，添加失败处理
5. **窗口截图** → 添加 QuickPreviewWindow + 历史记录

**Commit**: `138982a` (更新测试报告)

---

## 三、真机测试报告

**测试日期**: 2026-03-26  
**测试环境**: macOS Intel (Retina 2880×1800)  
**构建**: Debug ✅

### 已验证项

| 功能 | 状态 | 备注 |
|------|------|------|
| 编译通过 | ✅ | 无 error，2 warnings |
| App 启动 | ✅ | 状态栏图标正常 |
| 进程稳定 | ✅ | 无 crash |
| TCC 权限 | ✅ | 摄像头/麦克风弹窗正常 |
| P0 Bug 修复 | ✅ | 代码层面全部验证通过 |
| History 按钮 | ✅ | 已接线 |
| Settings 按钮 | ✅ | 已接线 |
| 截图选项 | ✅ | 可交互 |

### 待手动验证（需屏幕录制权限）

- [ ] 区域/窗口/全屏截图实际保存
- [ ] 区域/全屏录屏输出有效 MP4
- [ ] 连续录制 2-3 次不崩溃
- [ ] 暂停/恢复功能
- [ ] 摄像头画中画
- [ ] GIF 导出
- [ ] 视频裁剪
- [ ] OCR 文字识别

---

## 四、代码结构

```
Sources/
├── App/
│   ├── ScreenCamProApp.swift      # @main 入口
│   ├── AppDelegate.swift          # 状态栏、权限初始化
│   ├── PopoverView.swift          # 主 UI（截图/录屏 tab + 设置）
│   ├── HotkeyManager.swift        # 全局快捷键监听
│   └── TouchBarController.swift    # Touch Bar 支持
├── Recording/
│   ├── RecordingManager.swift      # 录屏核心（ScreenCaptureKit + AVAssetWriter）
│   └── RecordingState.swift        # 录屏状态管理
├── Capture/
│   ├── ScreenshotManager.swift     # 截图入口
│   ├── RegionSelector.swift         # 区域选择浮窗
│   ├── QuickPreviewWindow.swift    # 截图预览浮窗
│   ├── AnnotationWindow.swift       # 标注工具
│   ├── OCRManager.swift            # Vision OCR
│   ├── ScreenshotHistory.swift     # 历史记录存储
│   ├── WindowPicker.swift          # 窗口选择器
│   ├── ScrollCaptureManager.swift  # 滚动截图（开发中）
│   └── MultiDisplayManager.swift   # 多显示器支持
└── Views/
    ├── CameraPreviewWindow.swift   # 摄像头预览
    ├── CountdownWindow.swift       # 倒计时
    ├── RecordingIndicator.swift    # 录屏状态浮窗
    ├── KeystrokeOverlay.swift      # 按键显示
    ├── GifExporter.swift           # GIF 导出
    ├── VideoTrimmer.swift          # 视频裁剪
    ├── ScreenshotHistoryView.swift # 历史 UI (SwiftUI)
    └── CloudUploadManager.swift    # 云上传/分享
```

---

## 五、技术亮点

### 1. ScreenCaptureKit 录屏
```swift
// 使用 SCStream 捕获屏幕，AVAssetWriter 写入视频
let config = SCStreamConfiguration()
config.width = Int(sourceRect.width * scaleFactor)
config.capturesAudio = true
stream = SCStream(filter: filter, configuration: config, delegate: self)
```

### 2. 坐标系统兼容
```swift
// AppKit (bottom-left) → CG (top-left)
let screenHeight = NSScreen.main?.frame.height ?? 0
let cgRect = CGRect(x: rect.minX, y: screenHeight - rect.maxY, ...)
```

### 3. 动态 Session 启动
```swift
// 等待首帧 PTS，避免 AssetWriter 时间错乱
if !sessionStarted {
    assetWriter?.startSession(atSourceTime: pts)
    sessionStarted = true
}
```

---

## 六、下一步计划

### P0（当前）
- [x] 录屏核心链路修复
- [x] 坐标系统修复
- [x] 暂停/状态清理
- [x] UI 按钮接线
- [ ] **真机验证录屏/截图实际输出**

### P1
- [ ] 滚动截图真机验证
- [ ] 多显示器录屏验证
- [ ] 标注工具实际使用
- [ ] OCR 功能验证

### P2
- [ ] GIF 导出验证
- [ ] 视频裁剪验证
- [ ] 云上传功能完善
- [ ] 偏好设置页完善

### P3（发布准备）
- [ ] README 精简为已验证能力
- [ ] 打包、签名、分发

---

## 七、已知问题

1. **权限**：需手动在「系统设置 > 隐私与安全性 > 屏幕录制」授权
2. **快捷键冲突**：未检测与其他 App 的快捷键冲突
3. **Retina 适配**：区域选择在高缩放倍率下可能有偏差
4. **测试覆盖**：核心功能需真机验证

---

## 八、相关资源

- **GitHub**: https://github.com/diudiuabailu-pixel/FreeShot
- **README**: [README.md](./README.md)
- **测试报告**: [TESTING_REPORT.md](./TESTING_REPORT.md)

---

*最后更新: 2026-03-26*