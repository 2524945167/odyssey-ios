# 第 5 轮：SSE 流式接收与三协议适配

状态：已实现并通过 Xcode 27 / iOS 27 / Swift 6 CI 离线验收，未进入第 6 轮。没有真实服务或本轮真机测试记录，不将离线测试描述为这些测试已经完成。

## 已确认范围与不变项

- 仅实现基础传输和协议层，不接入首页、不改 UI；首页真实翻译仍安排第 7 轮。
- Responses API、Chat Completions API、Anthropic Messages 分别解析，绝不静默切换协议、重试或续传。
- 流式入口要求调用方显式提供文本与输出上限，没有新的正式翻译默认预算。连接测试仍发送 `Reply with OK.`，`stream: false`，默认上限 256 可自定义。
- 不读取或修改首页内容、钥匙串、配置存储、术语表与历史。生产 UI 不调用流式入口。
- 本机/CI 不使用真实密钥或真实模型服务；请求测试全部使用内存传输或拦截所有 URL 的离线 URLProtocol。

## 实现约束

- SSE 按字节分行，支持 UTF-8 跨包、首行 BOM、LF/CRLF/CR、多行 data、注释及未知字段。只在空行派发；EOF 不人为补齐残缺事件。id/retry 不引发重连或持久化。
- 只输出文本增量，不把推理、工具参数、拒绝正文或服务器错误拼入译文。
- Responses 使用 delta 输出；done/completed 完整快照不重复追加，结束快照与已接收文本不一致时报错。
- Chat Completions 等待 finish_reason 与 `[DONE]`；usage 的空 choices 不能视为完成。
- Anthropic 跟踪消息与内容块状态；等待 stop_reason 与 message_stop，未关闭的块或未知索引不能报告成功。
- 完成、输出受限、拒绝、无文本、不完整分开表示；HTTP 2xx 或 TCP EOF 不是成功依据。
- 每次请求独立 ephemeral URLSession，沿用现有 30 秒网络超时及 2 MiB 接收保护；后续正式翻译的产品配置仍须另行确认。
- 禁用缓存/Cookie/共享凭据，保留系统 TLS，拒绝重定向。验证 HTTP 状态和 text/event-stream 类型，不把 HTML/非流式 JSON 当作 SSE。
- 串行等待增量消费方，避免无限队列；调用方取消 Task、解析/消费失败或收到合法终态时关闭本次实际连接。取消不保证服务端停止生成或计费。
- 所有对外错误固定脱敏，不保存原始错误、API Key、地址或响应正文。

## 自动化验收

- 保留原有 67 项测试；新增 SSEDecoderTests、StreamingServiceTests、StreamingTransportTests。
- 覆盖中文/Emoji/组合字符任意分片、不同换行、多行事件、EOF、无效 UTF-8 和大小保护。
- 覆盖三种请求字段、显式上限、鉴权隔离、路径保留、原连接测试未改变。
- 覆盖正常/受限/拒绝/无文本终态、断流保留部分文本、不重复追加、错误协议、未知事件与块顺序。
- 使用实际 URLSession + 离线 URLProtocol 检查 MIME/HTTP/大小限制、首字节前取消、文本到达后取消、合法终态提前关闭和消费方失败关闭。
- 确切提交、Actions 运行、实际测试数量、警告、未签名 IPA 与 SHA-256 记录如下。不以这些测试声称真实服务已验证。

## CI 与产物证据（2026-09-06）

- 功能提交：[cfbeceb0702b1e4397314b1201be1dcaa79fa74c](https://github.com/2524945167/odyssey-ios/commit/cfbeceb0702b1e4397314b1201be1dcaa79fa74c)。后续验收文档提交不改变此构建对应的功能代码。
- [Actions Run #29 / 34040390958](https://github.com/2524945167/odyssey-ios/actions/runs/34040390958)，Job `101505955233`：completed / success。
- 环境：macOS 26.5.2，Xcode 27.0（27A5252f），Swift 6；iPhone 17 / iOS 27.0 模拟器。
- 原有 67 项测试保留；新增 SSEDecoderTests 10 项、StreamingServiceTests 16 项、StreamingTransportTests 9 项，总计 **102 项，0 失败**。日志汇总耗时 7.929 秒（wall time 17.224 秒），`TEST SUCCEEDED`。
- 密钥扫描通过；Release `BUILD SUCCEEDED`。日志有 **3 条** `Metadata extraction skipped, no AppIntents.framework dependency found`，不宣称零警告；未通过添加无关功能或关闭警告隐藏这些提示。
- 未签名 IPA Artifact：`Odyssey-unsigned.ipa`，ID `9991544018`，外层 ZIP 为 `427753` 字节。
- 外层 ZIP SHA-256（GitHub Artifact digest）：`b4afbb51b85cb46526d7b2db6179b6009d24876a4a390deb41e31138e9abbbfe`。
- 内部 IPA SHA-256（CI 打包后计算）：`a50ef6422fe4933e4d47474b639ea697373b6c008058a91948cba9fd7ab17ce3`。
- CI 验证内部 IPA 非空（422K）、含 `Payload/Odyssey.app/Info.plist`，Bundle ID 为 `com.kupetis.odyssey`。
- 本机已下载、解压并独立复算外层 ZIP 与内部 IPA 哈希，均与上述云端值完全一致；内部 IPA 精确大小为 `432343` 字节，重新检查确认含上述 Info.plist。下载位置：`C:\Users\Kupetis\Downloads\Odyssey-Round5-run29\Odyssey-unsigned.ipa`，未签名。
- 测试结果 Artifact：`Odyssey-test-results`，ID `9991543571`，含 `.xcresult`，便于独立核查。

## 本轮交付边界

- 首页仍为 Mock 翻译，连接测试仍默认 256 tokens；本轮 IPA 未签名，未使用任何用户证书。
- 后续接入首页前仍须确认正式翻译的输出上限、请求提示词与交互规则，不能由本轮底层实现替用户决定。
- 真实服务及第三方网关兼容性尚待后续获准测试；本轮证明的是离线协议处理、URLSession 取消/收尾及构建结果。

## 官方依据

- [OpenAI 流式响应](https://developers.openai.com/api/docs/guides/streaming-responses)
- [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)
- [Anthropic 流式事件](https://platform.claude.com/docs/en/build-with-claude/streaming)
- [WHATWG SSE 行与事件解析](https://html.spec.whatwg.org/multipage/server-sent-events.html)
