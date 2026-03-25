# FreeShot

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0%2B-blue" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

> 免费 macOS 截图/录屏工具，专为自媒体创作者打造。

## 当前状态

项目目前处于 **高强度开发 / 修复阶段**。

- 已完成基础截图与录屏主流程开发
- 已开始修复权限、区域录制、选项接线等关键问题
- **仍需在 macOS 真机完成完整验证**
- README 中仅保留“已开发/已接入”的能力，不代表全部已经稳定可商用

## 已开发能力

- 截图：区域 / 窗口 / 全屏
- 录屏：区域 / 全屏
- 摄像头画中画
- 倒计时
- 键盘显示
- 鼠标点击显示
- OCR 文本识别
- 滚动截图（开发中，需进一步验证）
- 多显示器支持（开发中，需进一步验证）
- 标注工具
- GIF 导出
- 视频裁剪
- 截图历史

## 当前重点修复项

- 屏幕录制权限与失败提示
- 区域录屏坐标映射
- 全屏/区域录屏文件生成稳定性
- 音视频写入链路
- 多显示器与 Retina 表现
- 连续录制稳定性

## 快速开始

### 运行

```bash
open FreeShot.app
```

### 开发

```bash
cd FreeShot
xcodegen generate
xcodebuild -project FreeShot.xcodeproj -scheme FreeShot -configuration Release build
```

## 测试

请优先参考：

- `Docs/TEST_CHECKLIST.md`
- `Docs/DEVELOPMENT_OPTIMIZATION_PLAN.md`

## 许可证

MIT License
