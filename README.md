# Codex 安装助手（非官方）

一个面向 macOS 与 Windows 新手的图形化 Codex CLI 安装助手。它不包含 Codex 二进制，也不提供第三方 API；用户确认后，应用从 OpenAI 官方地址下载安装脚本，运行官方 standalone 安装，验证版本，并启动 Codex 自身的 ChatGPT 登录流程。

> 本项目是独立的社区工具，不由 OpenAI 开发、认可或赞助。Codex、ChatGPT 和 OpenAI 是其各自权利人的名称或商标。本项目使用自有名称与图标，不使用 OpenAI 官方标志。

> [!WARNING]
> 当前发布的是朋友试用版，不是正式签名发行版。macOS DMG 仅经过本地 ad-hoc 签名、尚未 Apple 公证，首次打开需要在“系统设置 → 隐私与安全”中选择“仍要打开”。Windows x64/ARM64 EXE 尚未在 Windows 实机运行，且没有 Authenticode 签名，可能被 SmartScreen 拦截。请只从本仓库 Release 下载，并先阅读[朋友试用指南](docs/FRIEND_TEST_GUIDE.md)。

## macOS 用户流程

1. 打开测试版 DMG，将“Codex 安装助手”拖到“应用程序”。
2. 首次启动若被 macOS 拦截，在“系统设置 → 隐私与安全”中点击“仍要打开”，然后查看检测到的安装状态。
3. 点击“安装 Codex 并登录”。
4. 应用从 `https://chatgpt.com/codex/install.sh` 下载并检查脚本，在用户目录安装最新版 Codex。
5. 应用运行 `codex --version`，随后启动 `codex login`。
6. 用户在浏览器中完成 ChatGPT 登录；应用通过 `codex login status` 确认结果。

如果已检测到 Homebrew、npm、Bun 或未知来源的 Codex，应用不会卸载或覆盖它，也不会创建第二套 standalone 安装；用户可以直接验证并登录现有版本。

## 安全边界

- 安装脚本入口：`https://chatgpt.com/codex/install.sh`
- 只接受精确的官方重定向：`https://releases.openai.com/codex/install.sh`
- 唯一负载来源与校验逻辑：由 OpenAI 官方脚本管理
- 默认安装目录：`~/.local/bin`
- 不要求管理员权限
- 不读取 `~/.codex/auth.json`
- 不包含 API Key 输入框、第三方模型地址、日志上传或遥测
- 安装脚本先下载到权限为 `0700` 的临时目录，通过 HTTPS 最终地址和内容信号检查后才执行
- 自动测试只使用临时 HOME 和伪造脚本，不触碰真实 Codex

OpenAI 当前提供的安装与认证方式以[官方 Codex CLI 文档](https://learn.chatgpt.com/docs/codex/cli)和[认证文档](https://learn.chatgpt.com/docs/auth)为准。

## Windows 版本

Windows 版使用 .NET 8 WinForms，构建为无需预装 .NET 的 x64 与 ARM64 自包含单文件 `.exe`。它下载并检查官方 `install.ps1`，以普通用户权限安装到 `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin`，再验证版本和 ChatGPT 登录状态。当前 EXE 只完成了 macOS 上的交叉编译和静态测试，尚未在 Windows 实机验证。

源码、构建命令、安全边界与测试说明见 [windows/README.md](windows/README.md)。正式产物必须经过 Authenticode 签名与时间戳验证；当前未签名测试包仅用于朋友协助验收。

## 本地开发

要求：macOS 13+、Swift 5.9+、Command Line Tools。完整 Xcode 仅在归档和公开发布时需要。

```bash
make test
make security-check
make app
```

构建本地测试 DMG：

```bash
make dmg
```

未设置 `SIGNING_IDENTITY` 时，应用只进行 ad-hoc 签名，适用于本机验证，不可作为公开发布产物。

## 正式签名与公证

```bash
SIGNING_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)" \
VERSION="0.1.0" \
BUILD_NUMBER="1" \
make dmg
```

使用本机 notarytool profile：

```bash
NOTARY_PROFILE="codex-installer-notary" \
VERSION="0.1.0" \
bash scripts/notarize.sh
```

完整步骤、凭据变量和发布验收见 [docs/RELEASE.md](docs/RELEASE.md)。

## 当前阶段

- macOS SwiftUI MVP：已实现
- Universal Apple Silicon + Intel 构建：已配置
- Developer ID / notarization：脚本与 CI 已配置，需要发布者证书与 Apple API 凭据
- Windows .NET 8 MVP：已实现源码、自动测试、x64/ARM64 单文件构建与 Authenticode 发布 CI
- Windows 实机验收：仍需在干净的 Windows 11 x64 与 ARM64 设备完成，见 [docs/WINDOWS_PHASE_2.md](docs/WINDOWS_PHASE_2.md)

## License

MIT，见 [LICENSE](LICENSE)。本许可只覆盖本安装助手的源代码，不授予 OpenAI 产品、名称或标志的任何权利。
