# FreeShot

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0%2B-blue" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

> 免费 macOS 截图/录屏工具，专为自媒体创作者打造。

## ✨ 特性

- ✅ **完全免费** - 无任何付费功能限制
- 📸 **截图** - 区域/窗口/全屏截图
- 🎥 **录屏** - 区域/全屏录制
- 📷 **摄像头叠加** - 录屏时同时录制人脸（画中画）
- 🎤 **音频录制** - 麦克风 + 系统声音
- ⏱️ **倒计时** - 3/5/10秒可选
- ⌨️ **键盘显示** - 录制时显示按键
- 🖱️ **鼠标点击** - 显示鼠标点击效果
- 🔍 **OCR** - 从图片识别文字
- 📐 **滚动截图** - 长页面截取
- ✏️ **标注工具** - 箭头/矩形/圆形/文字
- 🎬 **GIF 导出** - 视频转 GIF
- ✂️ **视频裁剪** - 剪辑视频
- 📚 **截图历史** - 自动保存历史记录

## 🚀 快速开始

### 运行

```bash
open FreeShot.app
```

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| ⌘+Shift+4 | 截取区域 |
| ⌘+Shift+5 | 截取窗口 |
| ⌘+Shift+6 | 截取全屏 |
| ⌘+Shift+R | 区域录屏 |
| ⌘+Shift+F | 全屏录屏 |
| ⌘+Shift+S | 停止录屏 |

## 📝 开发

```bash
cd FreeShot
xcodegen generate
xcodebuild -project FreeShot.xcodeproj -scheme FreeShot -configuration Release build
```

## 📄 许可证

MIT License
