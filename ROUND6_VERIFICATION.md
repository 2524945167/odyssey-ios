# 第 6 轮：兼容性复查与键盘主题修复

状态：代码已实现并通过第 35 次 CI。用户随后反馈“没问题了”并批准进入第 7 轮，按该反馈记录本轮验收通过；不据此虚构逐项真机测试记录。以下 CI 与产物证据保持原样。

## 最终 CI 与交付产物（2026-09-07）

- 代码提交：`fd0711da3dfad76a8301f142905d072ccabe7204`。
- [GitHub Actions 第 35 次运行](https://github.com/2524945167/odyssey-ios/actions/runs/34085782572)，Job `101629432146`，结论 success。
- Xcode 27.0 / 27A5252f，macOS 26.5.2，iPhone 17 / iOS 27.0 Simulator，Swift 6。
- 保留原有 102 个验收场景，增加 8 个协议兼容性测试和 7 个键盘/原生页面测试，共 **117 项通过、0 失败**；测试耗时 26.645 秒（总计 33.452 秒）。原有 7 个页面用例更换为实际挂载渲染，不减少覆盖。
- Debug 测试与 Release 构建通过；编译 warning、Actions warning、AppIntents 跳过 warning 均为 **0**。Invalid Configuration、FocusState、状态更新、生命周期不平衡、AttributeGraph 布局循环诊断均为 **0**。脚本警告检查通过，原始日志保留。
- Git 跟踪文件密钥扫描通过；本轮测试没有向真实模型发送请求。
- IPA artifact：`Odyssey-unsigned.ipa`，ID `10005227344`；测试/日志/截图 artifact ID `10005226795`。
- 外层 ZIP：439,653 字节，SHA-256 `5bb8ff053b3270b3d824023891c462f52d1a48b584d35cfb04d13e2e1fcd7b08`。
- 内部未签名 IPA：444,220 字节，SHA-256 `e2bf3785b7ae8542969e0af44c3aba1ea030ef800362f45483827f0db0d63dd4`。下载后重新计算，与 CI 输出一致。
- 内部包含非空 `Payload/Odyssey.app/Odyssey` 与 `Info.plist`；CI 确认 Bundle ID `com.kupetis.odyssey`。
- 已下载至 `C:\Users\Kupetis\Downloads\Odyssey-Round6-run35\Odyssey-unsigned.ipa`，尚未签名。对应目录保留测试结果、完整构建日志及 11 张页面截图；已检查最终首页、API 表单及设置页的代表截图，未发现此次替换造成的布局破坏。

### 零警告的边界与待确认项

以上“零警告”指本次编译/Actions 警告及列出的项目运行时诊断，不等于整个模拟器日志没有任何提示。日志仍包含 UIKit 键盘渲染、PointerUI/XPC、缺少触觉资源等诊断，以及一次 `Keyboard queue task timeout detected`。这些原始日志未屏蔽；键盘队列提示的真机影响尚未确认，请一并关注主题切换时是否卡顿。不能在未真机验证前把微信输入法问题声明为已彻底解决。

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

- 调整前首页使用 SwiftUI TextEditor；当时生产代码未发现强制 preferredColorScheme、keyboardAppearance 或全局 UIAppearance 设置。
- 无本地 Xcode/微信输入法运行环境，不能声称已经复现或确认系统/输入法根因。
- 用户已明确授权把首页输入控件局部封装为原生 UITextView，保持现有外观和交互、不设置全局键盘样式，并要求本轮以零警告为目标。
- 必须检查主题连续切换、焦点、光标、中文组合输入和文本保留；不得用强制失焦再聚焦或按主题重建控件掩盖问题。

## 键盘实现与测试范围

- 首页使用局部 `TranslationTextEditor` / `ThemeAwareTextView`，源文本仍由原 ViewModel 管理，焦点通过本地 Binding 与原生 first responder 同步。API 设置表单不受影响。
- 从窗口的实际 UIKit traits 读取深浅色；主题改变时更新本输入控件的 `keyboardAppearance`，只对当前 first responder 刷新输入视图。前台恢复时额外刷新，覆盖扩展曾被挂起的情况；不根据旧颜色取反。
- 主题刷新不重建输入控件、不修改原文/选区、不强制失焦再聚焦；模型回写在存在 marked text 时不覆盖组合输入。保留清除、译文复制、空白收起及内外滚动交互。
- 新增 7 项真实 UIWindow 挂载测试：初始主题、连续切换并保持选区、marked text 保留、前台恢复、收起再打开、SwiftUI 文本与焦点双向绑定、首页控件身份及浅深色层级截图。
- 原生焦点操作在当前 SwiftUI 布局事务结束后执行，合并到最新绑定状态；控件卸载会取消待执行更新。测试窗口等待 viewDidAppear/viewDidDisappear 实际回调，异步清理，不打断 UIKit 生命周期。
- 保留原有 7 个页面浅深色/已配置状态验收场景，改名为 MountedRendering 并使用 UIHostingController / UIGraphicsImageRenderer：先断言原生输入框或列表实际挂载，再验证截图与尺寸。删除无效的离线原生页面渲染方式，不删减测试场景；纯 SwiftUI 品牌组件仍保留 ImageRenderer。

## 用户真机验收清单

请在 iPhone 16 Pro / iOS 27 + 微信输入法验证：

1. 输入框打开时从控制中心连续切换浅色→深色→浅色，键盘与页面同色且不反转。
2. 切到系统设置改变主题，再返回 Odyssey，仍保持一致；收起再打开键盘也一致。
3. 输入中文拼音尚未选字时切换主题，检查候选/组合输入、原文和光标是否保留。
4. 点击顶部空白收起、再次输入、清除、语言互换、复制与打开设置均正常。
5. 上述过程中留意键盘是否卡顿、候选栏是否重置；如异常请记录切换入口和微信输入法版本。

模拟器不包含微信输入法扩展，真实扩展的候选栏和配色仍待以上真机确认；不得将其报告为已经修复验证。

## 验收证据

- 协议检查点提交 `4e3f4992abd4778ff9bbf0742970101ebf2a8042` 通过 [CI 第 31 次运行](https://github.com/2524945167/odyssey-ios/actions/runs/34082212691)：110 项测试通过，IPA 打包成功；当时仍有 3 条 AppIntents 警告，不是本轮最终产物。
- 下列为中间验证记录；最终结果见本文顶部第 35 次 CI。离线模拟器验证不能替代 iPhone 16 Pro + 微信输入法真机验证。
- 中间检查点 `fe8fdc68204c411a62fe0467ec87d926dbe93e21` 通过 [CI 第 32 次运行](https://github.com/2524945167/odyssey-ios/actions/runs/34083704879)：117 项全部通过，编译/Actions 警告为 0。但完整日志复核发现 7 条旧 ImageRenderer 测试的 Invalid Configuration 诊断，因此不将该检查点视为完全干净的最终验收结果。
- 中间检查点 `db7c8d203022e0ac0280df07bbfea89a5bedc4b8` 通过 [CI 第 33 次运行](https://github.com/2524945167/odyssey-ios/actions/runs/34084324186)：117 项通过、编译/Actions 警告和 Invalid Configuration 为 0。复核仍发现测试窗口生命周期不平衡与焦点布局循环诊断，随后补充生命周期等待与布局外焦点更新，等待最终 CI。
- [CI 第 34 次运行](https://github.com/2524945167/odyssey-ios/actions/runs/34084771703) 未通过：测试清理先隐藏 UIWindow 再等待 viewDidDisappear，未收到回调而超时，并触发 XCTest 的后续诊断错误。该次没有交付 IPA。已调整为窗口仍可见时先移除根控制器，再完成隐藏与原窗口恢复；没有放宽业务或键盘断言。

## 零警告处理

- 项目未使用 App Intents/Siri/快捷指令，原有 3 条警告来自无依赖时仍执行的元数据提取任务。
- 使用构建系统的 `LM_SKIP_METADATA_EXTRACTION = YES` 跳过无用任务，不开启 `LM_FILTER_WARNINGS`、不屏蔽日志、不添加无用 framework。以后接入 App Intents 时需移除此配置。
- 最终已按完整第 35 次 CI 日志核对，具体零警告范围与保留的系统诊断见顶部说明。
- Swift/C 系编译警告视为错误；构建脚本用 tee 保留完整测试/Release 日志，并对 warning、Invalid Configuration、状态更新和 FocusState 诊断设置失败检查。不过滤输出，原日志随测试附件上传。
- 后续也纳入生命周期不平衡、AttributeGraph 布局循环检查。模拟器的 PointerUI/XPC、图形缓存、键盘渲染等系统诊断不等同于编译警告；不屏蔽它们，也不承诺整个操作系统日志绝对安静。

## 官方依据

- [OpenAI 流式响应](https://developers.openai.com/api/docs/guides/streaming-responses)
- [OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)
- [Anthropic 流式事件及未知事件兼容说明](https://platform.claude.com/docs/en/build-with-claude/streaming)
- [Apple 键盘外观](https://developer.apple.com/documentation/uikit/uitextinputtraits/keyboardappearance)
- [Apple 输入视图刷新](https://developer.apple.com/documentation/uikit/uiresponder/reloadinputviews())
- [Swift Build 元数据提取任务的跳过条件](https://github.com/swiftlang/swift-build/blob/main/Sources/SWBApplePlatform/AppIntentsMetadataTaskProducer.swift)
