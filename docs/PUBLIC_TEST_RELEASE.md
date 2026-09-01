# Codex 安装助手 0.1.0 公开测试版

这是面向朋友的小范围公开测试，不是正式签名发行版。

## 下载选择

- `Codex-Installer-Helper-0.1.0-macOS.dmg`：macOS 13+，同一个文件支持 Apple Silicon 与 Intel。
- `Codex-Installer-Helper-0.1.0-beta.1-windows-x64-unsigned.exe`：大多数 Intel/AMD Windows 电脑。
- `Codex-Installer-Helper-0.1.0-beta.1-windows-arm64-unsigned.exe`：Windows ARM 电脑。
- 每个安装包旁的 `.sha256` 文件用于校验下载完整性。

## 已完成验证

- macOS 核心测试 9/9 通过；应用是 arm64 + x86_64 Universal 二进制。
- macOS DMG 结构和 SHA-256 校验通过。
- Windows 核心跨平台测试 7 项通过，2 项 Windows PowerShell/CMD 集成测试因当前没有 Windows 环境而跳过。
- Windows x64 与 ARM64 均成功交叉编译为单文件 PE GUI 应用，SHA-256 校验通过。
- 源码安全扫描没有发现第三方 API、Key 配置、凭据读取、遥测 SDK 或捆绑的 Codex 二进制。

## 尚未完成

- macOS 没有 Developer ID 正式签名，也没有 Apple 公证；第一次启动需要手动选择“仍要打开”。
- Windows 两个架构均没有 Authenticode 签名。
- Windows 安装、PATH 更新、OAuth、设备登录回退和 SmartScreen 尚未在实机验证。
- 当前发布不应被镜像、重新打包或作为正式软件推荐。

详细点击步骤见[朋友试用指南](FRIEND_TEST_GUIDE.md)。
