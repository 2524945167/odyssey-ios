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
- 用户已明确授权把首页输入控件局部封装为原生 UITextView，保持现有外观和交互、不设置全局键盘样式，并要求本轮以零警告为目标。
- 必须检查主题连续切换、焦点、光标、中文组合输入和文本保留；不得用强制失焦再聚焦或按主题重建控件掩盖问题。

## 键盘实现与测试范围

- 首页使用局部 `TranslationTextEditor` / `ThemeAwareTextView`，源文本仍由原 ViewModel 管理，焦点通过本地 Binding 与原生 first responder 同步。API 设置表单不受影响。
- 从窗口的实际 UIKit traits 读取深浅色；主题改变时更新本输入控件的 `keyboardAppearance`，只对当前 first responder 刷新输入视图。前台恢复时额外刷新，覆盖扩展曾被挂起的情况；不根据旧颜色取反。
- 主题刷新不重建输入控件、不修改原文/选区、不强制失焦再聚焦；模型回写在存在 marked text 时不覆盖组合输入。保留清除、译文复制、空白收起及内外滚动交互。
- 新增 7 项真实 UIWindow 挂载测试：初始主题、连续切换并保持选区、marked text 保留、前台恢复、收起再打开、SwiftUI 文本与焦点双向绑定、首页控件身份及浅深色层级截图。
- 保留原有 7 个页面浅深色/已配置状态验收场景，改名为 MountedRendering 并使用 UIHostingController / UIGraphicsImageRenderer：先断言原生输入框或列表实际挂载，再验证截图与尺寸。删除无效的离线原生页面渲染方式，不删减测试场景；纯 SwiftUI 品牌组件仍保留 ImageRenderer。

## 用户真机验收清单

请在 iPhone 16 Pro / iOS 27 + 微信输入法验证：

1. 输入框打开时从控制中心连续切换浅色→深色→浅色，键盘与页面同色且不反转。
2. 切到系统设置改变主题，再返回 Odyssey，仍保持一致；收起再打开键盘也一致。
3. 输入中文拼音尚未选字时切换主题，检查候选/组合输入、原文和光标是否保留。
4. 点击顶部空白收起、再次输入、清除、语言互换、复制与打开设置均正常。

模拟器不包含微信输入法扩展，真实扩展的候选栏和配色仍待以上真机确认；不得将其报告为已经修复验证。

## 验收证据

- 协议检查点提交 `4e3f4992abd4778ff9bbf0742970101ebf2a8042` 通过 [CI 第 31 次运行](https://github.com/2524945167/odyssey-ios/actions/runs/34082212691)：110 项测试通过，IPA 打包成功；当时仍有 3 条 AppIntents 警告，不是本轮最终产物。
- 键盘补丁和零警告配置等待新一轮 CI 验证。离线模拟器验证不能替代 iPhone 16 Pro + 微信输入法真机验证。
- 中间检查点 `fe8fdc68204c411a62fe0467ec87d926dbe93e21` 通过 [CI 第 32 次运行](https://github.com/2524945167/odyssey-ios/actions/runs/34083704879)：117 项全部通过，编译/Actions 警告为 0。但完整日志复核发现 7 条旧 ImageRenderer 测试的 Invalid Configuration 诊断，因此不将该检查点视为完全干净的最终验收结果。

## 零警告处理

- 项目未使用 App Intents/Siri/快捷指令，原有 3 条警告来自无依赖时仍执行的元数据提取任务。
- 使用构建系统的 `LM_SKIP_METADATA_EXTRACTION = YES` 跳过无用任务，不开启 `LM_FILTER_WARNINGS`、不屏蔽日志、不添加无用 framework。以后接入 App Intents 时需移除此配置。
- 以完整 CI 日志为准，待验证是否达到零警告。
- Swift/C 系编译警告视为错误；构建脚本用 tee 保留完整测试/Release 日志，并对 warning、Invalid Configuration、状态更新和 FocusState 诊断设置失败检查。不过滤输出，原日志随测试附件上传。

## 官方依据

- [OpenAI 流式响应](https://developers.openai.com/api/docs/guides/streaming-responses)
- [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)
- [Anthropic 流式事件及未知事件兼容说明](https://platform.claude.com/docs/en/build-with-claude/streaming)
- [Apple 键盘外观](https://developer.apple.com/documentation/uikit/uitextinputtraits/keyboardappearance)
- [Apple 输入视图刷新](https://developer.apple.com/documentation/uikit/uiresponder/reloadinputviews())
- [Swift Build 元数据提取任务的跳过条件](https://github.com/swiftlang/swift-build/blob/main/Sources/SWBApplePlatform/AppIntentsMetadataTaskProducer.swift)
