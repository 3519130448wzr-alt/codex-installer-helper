# Windows 版 Codex 安装助手（非官方）

> [!CAUTION]
> 当前 Windows x64 与 ARM64 EXE 尚未在 Windows 实机运行，也没有 Authenticode 签名。这是公开测试包，不是正式发行版，可能触发 Microsoft Defender SmartScreen。请勿在重要工作电脑上测试；若系统无法确认发布者，请停止运行并反馈截图，不要关闭系统安全功能。

Windows 版是一个不需要管理员权限的 .NET 8 WinForms 应用，面向 Windows 11 x64 与 ARM64。发布产物是架构独立标注的自包含单文件 `.exe`，用户无需预装 .NET。

## 用户流程

1. 运行已签名的安装助手并点击“安装 Codex 并登录”。
2. 应用从 `https://chatgpt.com/codex/install.ps1` 下载脚本，只接受其精确官方重定向。
3. 应用检查脚本内容信号后，以当前用户身份运行脚本，并设置 `CODEX_NON_INTERACTIVE=true`。
4. 应用直接运行 `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin\codex.exe --version` 验证结果。
5. 应用调用 `codex login`；ChatGPT 账号确认由用户在浏览器完成。
6. 浏览器回调失败时，可在独立终端使用 `codex login --device-auth`，再回到应用检查登录状态。

检测到 npm、Bun 或未知来源安装时，助手不会卸载、覆盖或创建第二套 Codex，而是验证并使用现有版本进入登录流程。

## 本地构建

要求 Windows 11 与 .NET 8 SDK：

```powershell
windows\scripts\test.ps1
windows\scripts\security-check.ps1
windows\scripts\build.ps1 -Runtime win-x64 -Version 0.1.0
windows\scripts\build.ps1 -Runtime win-arm64 -Version 0.1.0
```

生成的单文件位于 `build\windows`。本地未签名产物只用于开发，不应公开分发。

## 安全边界

- 不内置或重新分发 Codex。
- 不使用第三方下载镜像、模型服务或 API 配置。
- 不读取 Codex 凭据存储，不保存密码、Token 或设备码。
- 不上传诊断信息，不含遥测 SDK。
- 只以 `asInvoker` 权限运行，不弹出管理员授权。
- 安装脚本下载失败、地址或内容检查失败、脚本失败、版本验证失败时立即停止。

公开发布必须经过 Authenticode 签名与时间戳验证，并在干净的 Windows 11 x64 和 ARM64 设备完成 SmartScreen 实机测试。
