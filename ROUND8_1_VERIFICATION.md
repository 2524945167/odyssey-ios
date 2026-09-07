# Odyssey 第 8.1 轮：设置简化与通用思考适配

## 范围与当前状态

用户确认：移除首页风格选择栏，改在设置选择；“网络游戏聊天”改为“网络聊天”；尽量简单地兼容常见模型，不增加特殊模型定制。实现、CI、产物下载及 12 张浅深色截图检查已完成；尚未通过真机或真实模型验收。

- 首页不再显示风格栏；入口统一为“设置 → 翻译风格”。当前风格自动保存，五份提示词仍可独立编辑与恢复。
- 网络聊天默认提示词兼顾社交平台、群聊、私信和游戏，根据语境使用常见缩写。持久化标识仍是 `gaming`，旧版用户自行编辑的模板不被覆盖。
- “设置 → 翻译参数”保持一个“深度思考”开关。已核实支持控制的配置默认关闭；不能确认控制方式时显示“跟随模型默认”，不把它误称为已关闭。
- 无厂商选择器、推理预算、强度等新高级选项；不猜测模型能力，不修改用户的 URL、Model ID、API Key，不自动重试或切换接口。
- 正式翻译默认 8192 tokens / 连续无数据 60 秒、最多 5 分钟，以及连接测试独立的 256 tokens / 30 秒均不改变。
- 未调用真实模型，未使用真实 API Key，未签名，未处理证书，未修改自动化或 CI 警告门禁。

## 兼容策略

基础翻译继续使用 Responses、Chat Completions、Anthropic Messages 三种协议。**协议兼容不等于思考参数兼容**。思考控制必须同时匹配已核实的官方端点、路径、协议和具体模型；未知模型或代理仍可使用基础翻译，但省略额外思考字段。不是“所有模型均可关闭思考”，也不是实测“市面多数模型均成功”。

| 服务与已核实的模型范围示例 | 协议 | 关闭 / 开启的实际字段 |
| --- | --- | --- |
| OpenAI GPT-5.1 / 5.2 / 5.4 / 5.5 / 5.6 系列白名单 | Chat Completions | `reasoning_effort: none / medium` |
| 同上 | Responses | `reasoning.effort: none / medium` |
| 阿里云百炼 Qwen 及文档明确支持混合思考的 DeepSeek、GLM、Kimi 托管模型 | Chat Completions | `enable_thinking: false / true` |
| 百炼 Responses 文档列出的混合思考模型子集 | Responses | `reasoning.effort: none / medium` |
| DeepSeek 官方 V4 Flash / Pro | Chat Completions | `thinking.type: disabled / enabled` |
| 同上 | Responses | `reasoning.effort: none / medium`；该服务将 medium 映射到 high |
| Anthropic Opus 4.6 / 4.7 / 4.8、Sonnet 4.6 / 5 | Anthropic Messages | `thinking.type: disabled / adaptive` |
| Google Gemini 2.5 Flash / Flash-Lite 官方 OpenAI 兼容端点 | Chat Completions | `reasoning_effort: none / medium` |
| 其他端点、协议组合或模型；强制思考/需特别定制者 | 用户选择的原协议 | 不附加思考控制，跟随服务默认 |

完整固定标识与端点条件在 `Core/Translation/TranslationThinkingPolicy.swift`，不使用模型名前缀猜测未来版本。旧 Claude 需要额外 `budget_tokens` 的方式、强制思考模型和特殊关闭限制均不纳入这轮。选择未知代理不会导致应用擅自发送另一家服务的参数；也不会为验证能力额外消耗一次请求。

## 官方依据（2026-09-07 核对）

- [OpenAI 推理指南](https://developers.openai.com/api/docs/guides/reasoning)、[最新模型指南](https://developers.openai.com/api/docs/guides/latest-model)：区分 Chat 与 Responses 字段，不能把 low 当作关闭。
- OpenAI 模型具体支持范围：[GPT-5.1](https://developers.openai.com/api/docs/models/gpt-5.1)、[GPT-5.2](https://developers.openai.com/api/docs/models/gpt-5.2)、[GPT-5.4](https://developers.openai.com/api/docs/models/gpt-5.4)、[GPT-5.5](https://developers.openai.com/api/docs/models/gpt-5.5)、[GPT-5.6 Sol](https://developers.openai.com/api/docs/models/gpt-5.6-sol)、[Terra](https://developers.openai.com/api/docs/models/gpt-5.6-terra)、[Luna](https://developers.openai.com/api/docs/models/gpt-5.6-luna)。
- [百炼深度思考](https://www.alibabacloud.com/help/zh/model-studio/deep-thinking)、[百炼 Responses 兼容接口](https://www.alibabacloud.com/help/zh/model-studio/compatibility-with-openai-responses-api)：托管服务使用自己的控制契约，Responses 支持集合与 Chat 不完全相同。
- [DeepSeek 思考模式](https://api-docs.deepseek.com/guides/thinking_mode/)、[Responses 参数](https://api-docs.deepseek.com/api/create-response/)：typed thinking 和 effort 的对应关系。
- [Anthropic 思考模式](https://platform.claude.com/docs/en/build-with-claude/thinking)、[开关与模型限制](https://platform.claude.com/docs/en/build-with-claude/thinking-troubleshooting)：仅使用不需要手动预算的普通 adaptive/disabled 组合。
- [Google OpenAI 兼容接口](https://ai.google.dev/gemini-api/docs/openai)：Gemini 2.5 Flash / Flash-Lite 可用 none；不能对 Pro 或不可关闭的版本照搬。

依据官方接口说明设计离线请求契约测试；这些证据不等于账号权限、地区可用性、模型输出质量或速度的真实调用测试。

## 已执行的验证

- 保留原有 165 项测试，新增 16 项：五类控制契约、未知/强制思考与特殊配置边界、托管服务差异、探测请求不变、旧数据迁移、设置切换请求快照、浅深色设置页挂载。
- 使用假密钥、隔离的 UserDefaults、离线服务与模拟器窗口；不发送网络模型请求。
- 导出首页、网络聊天模板、设置主页、风格选择页、支持/不支持控制的翻译参数页浅深色截图；截图证明布局，不能替代真机交互验收。
- CI 已通过完整测试、严格 Swift 6 编译、密钥扫描、现有应用警告门禁、Release IPA 打包与内部结构校验。
- 下载实际 IPA 后核对 SHA-256、ZIP CRC、Info.plist、可执行文件存在且非空。不将 GitHub 外层 ZIP 哈希与内部 IPA 混淆。

## 待真机验收

1. 首页不再有风格选择栏；原输入、双向语言切换、复制、停止、键盘主题和点击空白收起正常。
2. 设置 → 翻译风格可选择五种风格，重启后保持；设置主页摘要一致。网络聊天旧自定义模板仍在。
3. 修改风格不会自动发起翻译；进行中的请求不变，下次手动翻译才使用新风格。
4. 已核实的当前 Qwen 官方 Chat 配置继续显示思考开关，初始关闭；未知代理显示跟随模型默认，不显示误导性关闭开关。
5. 浅深色下设置与首页正常，分享的朋友需要自行配置自己的服务与密钥。安装包不带任何个人配置或真实密钥。

## CI 与产物结果

- 功能提交：[`0480472fcf443eb87d3a1a20cd2d1866b8f7baa1`](https://github.com/2524945167/odyssey-ios/commit/0480472fcf443eb87d3a1a20cd2d1866b8f7baa1)。后续提交仅补充验收文档，不改变 IPA 中的代码。
- [Actions Run #38](https://github.com/2524945167/odyssey-ios/actions/runs/34104318725)，Run ID `34104318725`，Job ID `101685710492`，全部步骤 success。
- 环境：Xcode 27.0，iOS 27.0 iPhone 17 模拟器；挂载截图窗口 402 × 874 points，图片 1206 × 2622 pixels。
- 原 165 项 + 新增 16 项 = **181 项测试全部通过**，0 failures；日志汇总耗时 `68.785 (84.989) seconds`。新增兼容性测试类 14 项全部通过，另新增 2 项设置挂载测试。
- `** TEST SUCCEEDED **`、`** BUILD SUCCEEDED **`、本地/云端密钥扫描 PASSED。
- Actions `##[warning]` 为 0，编译 `warning:` 为 0；下载后的 TestBuild.log 与 ReleaseBuild.log 再次核对，已知 SwiftUI/FocusState/布局/视图生命周期门禁命中 0。未删减日志、放宽门禁或移除旧测试。
- 模拟器仍记录 PointerUI/XPC、UIKit `cannot add handler`、键盘与缺失触觉资源等诊断，含 KeyboardTaskQueue 信息。**不宣称整份日志零诊断，也不将这些消息伪称为已修复。**

### IPA 与测试附件

| 项目 | 实际结果 |
| --- | --- |
| IPA Artifact | `Odyssey-unsigned.ipa`，ID `10011920028` |
| GitHub 外层 ZIP 大小 | 542,469 bytes |
| 外层 ZIP SHA-256 | `60aed114c07b91660380eea19b3490ff198833f55e2b352399ddb021ab62367c` |
| 内部 IPA 大小 | 547,745 bytes |
| 内部 IPA SHA-256 | `f7498c139ebddbc42192caece4c225887c7602fde8a8606e5dc5f616f00b49f8` |
| 测试附件 | `Odyssey-test-results`，ID `10011919207`，22,407,408 bytes |
| 测试附件 ZIP SHA-256 | `11dd7a286435414fddb834f05c2b57fe635223daadfee3a155832767eaac1fdf` |

实际文件已下载至 `C:/Users/Kupetis/Downloads/Odyssey-Round8.1-run38/`，内部 IPA 位于 `ipa/Odyssey-unsigned.ipa`。两份外层 ZIP 哈希与 GitHub artifact digest 一致；IPA 哈希与 CI 打包日志逐位一致。

下载后的 IPA ZIP CRC 校验通过，包含 `Payload/Odyssey.app/Info.plist`；Bundle ID 为 `com.kupetis.odyssey`，最低 iOS `27.0`，SDK `iphoneos27.0`。可执行文件 `Payload/Odyssey.app/Odyssey` 为 2,590,680 bytes，非空；包中无 embedded.mobileprovision、无 _CodeSignature。交付的是**未签名 IPA**。

### 截图检查

`tests/TestAttachments/manifest.json` 包含全部导出映射。已逐张打开这轮 12 张 `Round8_1-*` 截图：首页、设置主页、翻译风格、网络聊天提示词、支持思考开关的翻译参数、不支持控制的翻译参数，各有浅深色。

- 首页仅保留品牌/设置入口、语言切换、输入/译文及翻译按钮，已没有风格栏。
- 设置主页显示“翻译风格 · 网络聊天”；详情有“当前风格”菜单及五份模板编辑入口，没有重叠或标题截断。
- 支持的配置显示关闭状态的单一思考开关；未知代理显示“跟随模型默认”，没有误导性开关。
- 网络聊天提示词编辑区允许滚动；浅色截图只显示正文的初始可见部分，底部内容需在编辑区滚动，不将单张截图当作全部文本可见的证据。
- 挂载截图不包含系统状态栏，不替代 iPhone 16 Pro 的触摸、微信输入法与真实服务验收。尚未测试真实模型的速度或翻译质量。
