# 第 5 轮：SSE 流式接收与三协议适配

状态：用户已确认范围，代码与离线测试编写中，待 Xcode 27 / iOS 27 / Swift 6 CI 验证。不得提前标记测试通过。

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
- 完成后记录确切提交、Actions 运行、实际测试数量、警告、未签名 IPA 与 SHA-256。不以这些测试声称真实服务已验证。

## 官方依据

- [OpenAI 流式响应](https://developers.openai.com/api/docs/guides/streaming-responses)
- [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)
- [Anthropic 流式事件](https://platform.claude.com/docs/en/build-with-claude/streaming)
- [WHATWG SSE 行与事件解析](https://html.spec.whatwg.org/multipage/server-sent-events.html)
