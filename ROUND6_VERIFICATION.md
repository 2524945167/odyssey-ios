# 第 6 轮：兼容性复查与键盘主题修复

状态：进行中，尚未通过本轮完整验收，不进入第 7 轮。

## 用户确认的范围

- 修复首页键盘打开时切换深浅色不更新、连续切换后反色的问题。用户确认使用微信输入法；切换入口待补充。
- 复查现有 Responses、Chat Completions、Anthropic Messages 三协议、自定义 Base URL 与异常响应，补齐遗漏测试。
- 保留原有 102 项测试，CI 编译及打包后由用户真机验收。
- 不新增协议、自动探测、降级或重试；不调用真实模型，不接入首页真实翻译；连接测试默认上限 256 不变。

## 协议复查

- Chat Completions：若网关提供生成 ID，同一连接后续提供的 ID 必须一致（包括 usage 帧），防止混入另一条生成；沿用省略 ID 的兼容行为。
- Responses：同一 output_index 的文本增量不得突然换成另一个 item_id。
- Anthropic：未知顶层元数据事件继续兼容忽略；未知内容增量继续接收但最终标为不完整，避免丢掉未识别内容后仍声称完整成功。已知推理、签名、工具参数不进入译文。
- 新增离线覆盖：自定义路径/端口/编码与协议后缀矩阵，禁止 URL 的零请求验证，响应身份一致性，未知内容终态，多文本块初始文本，三协议 BOM/注释/CRLF 字节分片。

## 键盘排查与授权

- 首页当前使用 SwiftUI TextEditor；生产代码未发现强制 preferredColorScheme、keyboardAppearance 或全局 UIAppearance 设置。
- 无本地 Xcode/微信输入法运行环境，不能声称已经复现或确认系统/输入法根因。
- 已向用户询问是否允许把首页输入控件局部封装为原生 UITextView，保持现有外观和交互、不设置全局键盘样式。获得确认前不实施此调整。
- 必须检查主题连续切换、焦点、光标、中文组合输入和文本保留；不得用强制失焦再聚焦或按主题重建控件掩盖问题。

## 验收证据

待 CI 和真机结果补充。离线模拟器验证不能替代 iPhone 16 Pro + 微信输入法真机验证。

## 官方依据

- [OpenAI 流式响应](https://developers.openai.com/api/docs/guides/streaming-responses)
- [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)
- [Anthropic 流式事件及未知事件兼容说明](https://platform.claude.com/docs/en/build-with-claude/streaming)
- [Apple 键盘外观](https://developer.apple.com/documentation/uikit/uitextinputtraits/keyboardappearance)
- [Apple 输入视图刷新](https://developer.apple.com/documentation/uikit/uiresponder/reloadinputviews())
