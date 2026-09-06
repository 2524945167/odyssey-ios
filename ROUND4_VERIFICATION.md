# 第 4 轮：请求适配与连接测试

状态：已提交 GitHub Actions。第 27 次运行在页面离线渲染测试中发生 SwiftUI 崩溃，已定位并修正测试宿主，待重跑；不得视为验收完成。

## 已确认范围

- 支持 Responses API、Chat Completions API、Anthropic API（Messages），沿用第 3 轮的三种格式与自定义 Base URL / Model ID。
- 只接入设置页“测试连接”；首页继续使用本地 Mock，不接入真实翻译、SSE、术语表或历史。
- 用户手动点击后使用已保存配置发送一次固定短句 `Reply with OK.`，不发送首页原文。
- 测试输出上限默认 **256 tokens**，允许用户自定义正整数。开始测试时独立保存到本机，不修改已有 API 配置 JSON 或钥匙串。
- 30 秒超时、可取消，不自动重试、增加预算、更改模型或切换协议。
- 开发与自动化测试不使用真实密钥、不调用真实模型服务。真机测试由用户自行操作，可能产生费用。

## 实现与边界

### 请求

| 格式 | 在 Base URL 后追加 | 输出上限字段 | 鉴权 |
| --- | --- | --- | --- |
| Responses API | `/responses` | `max_output_tokens` | Bearer |
| Chat Completions API | `/chat/completions` | `max_completion_tokens` | Bearer |
| Anthropic API（Messages） | `/messages` | `max_tokens` | x-api-key + anthropic-version |

Base URL 保留自定义路径，仅移除末尾斜杠。例如 `https://example.invalid/gateway/v1/` 配 Responses API，实际请求为 `https://example.invalid/gateway/v1/responses`。不自动猜测 `/v1`，也不自动识别完整操作地址；页面在发送前显示实际请求地址。Base URL 应填写接口基础路径，而非完整的 `/responses` 或 `/messages` 操作地址。

所有请求 `stream: false`；OpenAI 两种格式还传 `store: false`。该字段不等于服务商完全不保留日志，第三方端点须以其隐私政策为准。没有 temperature、reasoning effort、工具或未经用户确认的模型专属参数。服务商不接受数值/字段时显示错误，不作静默兼容重试。

### 网络与隐私

- 每次测试建立独立 ephemeral URLSession，不使用磁盘缓存、共享 Cookie 或共享凭据。
- 保留系统 HTTPS 校验，不绕过证书错误；拒绝重定向，避免将凭据转发到服务器指定的新地址。
- 点击取消、离开页面、进入后台均取消本地任务及会话；**不能保证服务端停止生成或计费**。
- 以字节方式接收单次非流式 JSON（不是 SSE），响应体设 2 MiB 内存保护；超限停止接收。
- 不记录或展示请求头、API Key、模型原始输出、服务器错误正文；仅返回固定脱敏错误与 HTTP 状态。
- 输出上限不是金额上限。不同模型/服务有不同 token 限制，部分模型的推理会占用预算；用户自行提高上限可能增加费用。

### 界面与状态

- 沿用已有 Form 设置页，新增已保存配置摘要、实际请求地址、可编辑输出上限、恢复 256、开始/取消、结果及耗时。
- 上限为空、零、负数、非整数或超过本机整数可表示范围时，在发请求前拒绝，不自动改成默认值。
- 开始测试时才保存合法上限；无效输入不会覆盖上次合法设置。
- 请求期间禁用重复开始和上限编辑；请求 ID + 任务取消双重保护，迟到结果不能覆盖新测试。
- 只有 HTTP 2xx 且协议结构和文本结束状态正常才报告“连接成功”。额度耗尽、无文本、拒绝或未完整生成分别提示，不误报网络断开。

## 自动化验收清单（待完整 CI 通过）

保留现有 36 项测试，新增 `ConnectionTestProtocolTests` 与 `ConnectionTestViewModelTests`：

- 三种请求的路径、鉴权、字段白名单、固定短句、默认/自定义上限；无自动协议切换。
- HTTPS/嵌入凭据/Query/Fragment 拦截，API Key 防止头部注入。
- 三种协议的正常响应、输出耗尽、拒绝、空正文、错误格式和错误协议。
- HTTP 常见错误、超时、脱敏错误，单次请求且无重试。
- URLSession 安全配置、重定向拒绝、离线 URLProtocol 的真实传输适配和响应大小保护。
- 输出上限独立持久化、非法输入零请求、不修改原配置/密钥、仅用最新已保存配置。
- 重复开始、提前取消、旧请求迟到、失败后恢复按钮、输出受限提示。
- 浅色/深色 402 × 874 有窗口 UIHostingController 渲染，断言实际输入控件显示 256，保留截图附件。不能代替真机点击、数字键盘、取消或布局验收。

所有请求测试使用内存 mock 或离线 URLProtocol。测试域名为 `.invalid`，URLProtocol 拦截全部请求；不会使用真实 Keychain、标准 UserDefaults 写入或实际模型服务。

## 待完成验收

1. 提交后运行现有 Xcode 27 / iOS 27 / Swift 6 CI，记录实际运行链接、测试数量、错误与警告。
2. 修复编译/测试问题后再记录 IPA Artifact、内部 IPA SHA-256 和确切提交。
3. 不以“本地代码已编写”代替编译通过；第 3 轮已知 3 条 AppIntents 元数据跳过警告也必须如实核对，不宣称零警告。
4. 用户在 iPhone 16 Pro 验证默认 256、自定义并重新进入页面、非法输入、开始/取消、后台取消、浅深模式和配置未受影响。
5. 用户按自己的配置手动测试实际服务。若第三方不支持官方参数，收集脱敏的 HTTP 状态与服务商文档后，先确认兼容方案再改动。

## CI 修复记录

- 第 27 次运行（提交 `4abedd9553fa506f199bd0e27fe9147dccd8661d`）：19 项协议测试通过；在 `testConnectionViewRendersLightAndDarkWithoutRequests` 中，ImageRenderer 渲染 NavigationStack/Form 触发 `SwiftUICore/Logging.swift:232: Fatal error: no current update to enqueue action to`。Xcode 重启宿主后继续执行其他测试，但未结束整体测试，约 10 分钟后人为取消获取日志；无 IPA。
- 修复仅将新页面的渲染测试移入真实 UIWindow + UIHostingController，保留完整 Form、焦点和生命周期，不删除/跳过测试，不改动产品规则。
- 构建显式输出 `build/TestResults.xcresult`，CI 无论成功与否尽量上传为 `Odyssey-test-results`，保留截图与诊断；整个作业设置 15 分钟超时防止无限占用 runner。

## 官方依据

- [OpenAI Responses 请求与输出预算](https://developers.openai.com/api/reference/cli/resources/responses/methods/create)
- [OpenAI Chat Completions 参数与响应](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)
- [Anthropic Messages 请求与响应](https://platform.claude.com/docs/en/api/messages/create)
- [Apple URLSession 字节接收](https://developer.apple.com/documentation/foundation/urlsession/bytes(for:delegate:))
- [Apple ImageRenderer 的 UIKit 容器限制](https://developer.apple.com/documentation/swiftui/imagerenderer)
- [Apple UIHostingController](https://developer.apple.com/documentation/swiftui/uihostingcontroller)
- [Apple URLSession 重定向代理](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/urlsession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:))
