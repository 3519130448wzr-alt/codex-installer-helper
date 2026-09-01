# 给朋友的试用指南

这是一款非官方的 Codex 安装助手。它不包含 Codex，也不要求输入 API Key；点击确认后，它只会从 OpenAI 官方地址下载安装脚本，并调用 Codex 自身的 ChatGPT 登录流程。

## 先确认下载来源

只从本项目的 GitHub Releases 页面下载。不要使用别人重新打包或转发的不明文件。

## macOS 试用

适用于 macOS 13 或更高版本，Apple Silicon 与 Intel Mac 均包含在同一个 DMG 中。

1. 下载文件名包含 `macOS.dmg` 的文件并双击打开。
2. 把“Codex 安装助手”拖到右侧的“应用程序”。
3. 在“应用程序”中双击“Codex 安装助手”。
4. 当前测试版没有 Apple 公证；如果系统阻止打开，请先关闭提示，然后进入“系统设置 → 隐私与安全”，向下滚动到“安全性”，在对应提示旁点击“仍要打开”，输入 Mac 登录密码确认。
5. 回到应用，点击“安装 Codex 并登录”。
6. 浏览器打开后，使用自己的 ChatGPT 账号完成登录。
7. 完成页出现版本号和安装路径后，点击“打开终端”，输入 `codex --version` 检查。

“仍要打开”是 Apple 为未公证应用提供的手动例外。只有在文件确实来自本仓库且你信任发送者时才应使用。

## Windows 试用——尚未实机验证

> Windows 版是第一次外部测试。x64 与 ARM64 EXE 均未进行 Authenticode 签名，也没有在 Windows 真机运行。请优先在备用电脑或虚拟机测试。

1. 大多数 Intel/AMD Windows 电脑下载文件名包含 `windows-x64-unsigned.exe` 的版本。
2. Windows ARM 电脑才下载 `windows-arm64-unsigned.exe`。
3. 双击运行。如果 Microsoft Defender SmartScreen 阻止运行，请先截图并反馈；不要关闭 Defender、SmartScreen 或其他系统安全功能。
4. 如果应用正常打开，确认窗口顶部显示“Codex 安装助手（非官方）”。
5. 点击“安装 Codex 并登录”，在浏览器中完成 ChatGPT 登录。
6. 完成后点击“打开终端”，输入 `codex --version` 检查。

## 请反馈这些信息

- 操作系统版本与芯片类型；
- 下载的文件名；
- 安装助手停在哪个步骤；
- 页面显示的版本号和安装路径；
- 如果失败，提供不含账号、设备码、Token 或其他凭据的截图。

不要发送 ChatGPT 密码、验证码、设备登录码、Token、API Key 或 Codex 凭据文件。
