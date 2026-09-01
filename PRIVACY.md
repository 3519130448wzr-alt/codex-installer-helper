# 隐私说明

Codex 安装助手不收集、上传或出售个人数据，也不包含分析、广告、崩溃上报或遥测 SDK。

应用只执行以下本地操作：

- 检查当前平台的 PATH 与常见用户级路径中是否存在 `codex` 可执行文件；
- 从 OpenAI 官方 HTTPS 地址下载安装脚本；
- 在用户目录运行官方安装脚本并执行 `codex --version`；
- 启动 `codex login` 并通过 `codex login status` 获取成功或失败状态；
- 在当前应用窗口中显示临时诊断输出。

应用不会读取 Codex 凭据文件、浏览器 Cookie、项目文件、终端历史或 API Key。macOS 与 Windows 版本的诊断输出都只保存在当前进程内，退出应用后不会持久化，也不会被传输。

Codex 和 ChatGPT 登录过程由 OpenAI 的软件与服务处理，其数据实践受 OpenAI 自身政策约束。
