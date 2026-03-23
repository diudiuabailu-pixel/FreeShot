# FreeShot

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0%2B-blue" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

> 免费 macOS 录屏工具，专为自媒体创作者打造。

## ✨ 特性

- ✅ **完全免费** - 无任何付费功能限制
- 🎥 **屏幕录制** - 支持区域录屏和全屏录屏
- 📷 **摄像头叠加** - 录屏时同时录制人脸画面（画中画）
- 🎤 **音频录制** - 支持麦克风和系统声音
- ⏱️ **倒计时** - 3/5/10秒可选
- ⌨️ **键盘显示** - 录制时显示按键
- 🖱️ **鼠标点击** - 显示鼠标点击效果
- ⚡ **全局快捷键** - 快速启动录屏

## 📸 截图

![FreeShot](screenshot.png)

## 🚀 快速开始

### 下载

从 [Releases](https://github.com/diudiuabailu-pixel/FreeShot/releases) 下载最新版本。

### 运行

```bash
open FreeShot.app
```

或者双击 `FreeShot.app` 打开。

### 权限

首次运行需要授权以下权限：
- **屏幕录制** - 系统偏好设置 → 隐私与安全性 → 屏幕录制
- **摄像头** - 系统偏好设置 → 隐私与安全性 → 相机
- **麦克风** - 系统偏好设置 → 隐私与安全性 → 麦克风
- **辅助功能**（键盘显示）- 系统偏好设置 → 隐私与安全性 → 辅助功能

## ⌨️ 快捷键

| 快捷键 | 功能 |
|--------|------|
| ⌘+Shift+R | 区域录屏 |
| ⌘+Shift+F | 全屏录屏 |
| ⌘+Shift+S | 停止录屏 |

## 🛠️ 开发

### 环境要求

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

### 编译

```bash
cd FreeShot
xcodegen generate
xcodebuild -project FreeShot.xcodeproj -scheme FreeShot -configuration Release build
```

### 项目结构

```
FreeShot/
├── Sources/
│   ├── App/           # 应用入口、状态栏
│   ├── Recording/     # 录屏核心
│   ├── Views/         # UI 组件
│   └── ...
└── Resources/         # 资源文件
```

## 📝 更新日志

### v1.0.0
- 初始版本
- 区域/全屏录屏
- 摄像头叠加
- 麦克风/系统声音
- 倒计时
- 键盘/鼠标显示

## 📄 许可证

MIT License - 免费开源

## 👤 作者

diudiuabailu-pixel

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！
