# Odyssey 第 7 轮：真实流式翻译接入首页

状态：实现、云端编译、142 项测试及未签名 IPA 下载校验已通过，等待用户真机验收。尚未进行真实模型调用或真机验收；未开始第 8 轮。

## 已确认范围

- 用户批准将真实流式翻译接入现有首页，维持现有 Liquid Glass UI、中文到英语默认方向和双向交换。
- 正式翻译输出上限默认 **8192 tokens**，允许用户自定义，与连接测试默认 256 独立保存。
- 连续无数据超时默认 **60 秒**，允许用户自定义；单次请求总时长最多 **300 秒**。即使用户将无数据超时设得更长，总时长限制仍生效。
- 停止或超时保留已经收到的译文，不自动重试、续写、调高预算、切换协议或模型。
- 本轮不实现自动长文分段、完整语言列表、术语表、额外要求、历史、语音或后台执行能力。

## 实现

1. `TranslationOptions` / `TranslationPreferences`：只保存两个正整数，不存正文或密钥。参数页显式保存，恢复默认值也需要保存；字段出错时不部分保存。
2. `TranslationService`：使用三协议现有 SSE 解码器与安全传输；原文保持原样放入用户消息，翻译指令分别放在 Responses `instructions`、Chat Completions `system` 消息、Anthropic 顶层 `system`。不启用工具或额外推理参数。
3. 翻译使用独立 ephemeral 会话：用户自定义无数据超时、固定 5 分钟资源超时；沿用不缓存、不保存 Cookie/共享凭据、不跟随重定向和 2 MiB 响应保护。连接测试仍是原来的 30 秒。
4. `TranslationViewModel`：每次点击先读最新已保存配置及钥匙串，校验后创建一次请求；使用配置/参数/原文/语言快照。每个请求都有 ID，取消先使 ID 失效，迟到的增量、错误和终态都不能污染后续请求。
5. 首页逐步追加译文，主按钮在运行时变为“停止翻译”；明确区分完成、输出受限、拒绝、无文本、未完成、取消和错误。未配置时引导打开设置，不发送请求。
6. 修改原文或交换方向会停止旧请求并标注现有结果仅供参考；清除会停止并清空两侧。复制仍可复制已有部分译文。页面移除时取消本地请求，不新增后台执行保证。
7. 测试使用隔离 UserDefaults、内存 Keychain/剪贴板、可控延迟服务、离线 SSE 和拦截全部请求的 URLProtocol；不访问真实模型服务。

## 自动验收（已通过）

- 保留第 6 轮原有 117 项测试场景；旧模拟翻译用例替换为真实业务 + 离线传输的异步测试。
- 新增默认值/持久化隔离/输入校验/显式保存、三协议提示词与字段、超时与隐私配置、流式首页集成、停止/重复点击/迟到回调、原文修改与交换、配置快照、异常脱敏、原生网络取消及页面渲染测试。
- 页面通过真实 UIWindow 挂载、等待生命周期后截图，保持浅深色与原生输入控件覆盖。
- 原有编译/Actions 警告、SwiftUI 焦点/布局与测试生命周期诊断检查不放宽，不隐藏日志。
- 超时参数检查和模拟超时异常不等同于已在真实服务上等待满 60/300 秒；最终报告区分测试范围。

## CI 与产物证据

- 代码提交：[`c9524fafe1b7aa8f4dce3297be09caf0f6c15219`](https://github.com/2524945167/odyssey-ios/commit/c9524fafe1b7aa8f4dce3297be09caf0f6c15219)。后续验收文档提交不改变该构建产物。
- [GitHub Actions 第 36 次运行](https://github.com/2524945167/odyssey-ios/actions/runs/34092020577)：Run ID `34092020577`，Job ID `101647334440`，结果 `completed / success`。
- 环境：`xcode-27` Runner；macOS 26.5.2；Xcode 27.0（27A5252f）；iPhone 17 模拟器 / iOS 27.0。
- 共 **142 项测试通过，0 失败**：保留原有 117 项场景，新增 23 项翻译集成测试及 2 项原生传输测试。测试用例累计耗时 46.993 秒，套件经过时间 54.172 秒。
- 密钥扫描通过；`TEST SUCCEEDED`、`BUILD SUCCEEDED` 与 warning/runtime diagnostic gate 均通过。
- 完整作业日志及下载后的构建日志复核：编译 `warning:` **0**，Actions `##[warning]` **0**，已知 SwiftUI 焦点/状态/布局及测试生命周期诊断 **0**。没有过滤或隐藏原始日志。
- 模拟器仍有 PointerUI/XPC、键盘渲染、缺少触觉库资源等系统诊断，以及 **1 次 KeyboardTaskQueue 超时提示**；相关测试通过。这不等同于全部运行日志没有提示，也不能替代微信输入法真机验证。

产物：

- Artifact 名称 `Odyssey-unsigned.ipa`，ID `10007291410`。
- 外层 ZIP：484,752 字节；SHA-256 `730acf9a297f1b543d165366652d28e4ae1ed6e57876699e965423105ad494e9`，与 GitHub Artifact digest 一致。
- 内部 IPA：489,499 字节；SHA-256 `561f7a024bbf3d18ac924a064a2005709667484da326557efc2c2a3ac9f66dd6`，与 CI 输出一致。
- 下载后重新校验 ZIP/IPA 完整性、`Payload/Odyssey.app/Info.plist` 和非空可执行文件；Bundle ID 为 `com.kupetis.odyssey`。
- 本地文件：`C:\Users\Kupetis\Downloads\Odyssey-Round7-run36\ipa\Odyssey-unsigned.ipa`。未签名、未安装；本轮没有读取或使用签名证书。
- 测试 Artifact `Odyssey-test-results`，ID `10007290677`；SHA-256 `d5109a11b4f4cf1adaea0c4b9a09df5e89d5e937ab79bf1d45d3fad8475e27d5`，与 GitHub digest 一致。包含 xcresult、完整测试/Release 日志及 15 张截图。
- 已人工查看新增参数页、流式首页的浅/深色共 4 张截图：默认 8192 / 60、5 分钟说明与保存操作可见，首页部分译文及“停止翻译”按钮可见，无明显遮挡。截图使用离线测试数据，不是实际模型翻译成果。

本地环境是 Windows，没有 Xcode；iOS 编译和执行证据来自上述云端运行，不声称已在本机完成 Xcode 测试。

## 真机验收清单

1. 在“设置 → 翻译参数”确认默认 8192 / 60，修改保存、重新打开仍一致；连接测试参数不变。
2. 使用自己保存的服务配置点击翻译，验证英文逐步显示、中文/Emoji/段落保留；交换后验证英语到中文。
3. 运行中停止，已有部分内容保留；再次翻译不混入前一次结果；清除/改原文/交换方向不被旧请求覆盖。
4. 验证空白原文、未配置、错误密钥、断网、输出上限与超时提示，不误报成功、不自动重复发送。
5. 微信输入法打开时来回切换深浅色，检查键盘、候选拼音、光标和输入内容；验证点击空白收起键盘、复制、设置入口。
6. 长文本滚动可读，停止按钮可用；本轮没有自动分段，对模型自身上下文/输出上限或 2 MiB 接收保护不作无限保证。

真实服务调用可能产生费用；停止本地连接不保证服务端立即停止生成或计费。真实测试须由用户操作或另行明确授权。

## 参考

- [OpenAI Responses 请求字段](https://developers.openai.com/api/reference/cli/resources/responses/methods/create)
- [Claude Messages 顶层 system 与流式请求](https://platform.claude.com/docs/en/api/messages/create)
- [Apple 无数据超时](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/timeoutintervalforrequest)
- [Apple 请求总时长限制](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/timeoutintervalforresource)
