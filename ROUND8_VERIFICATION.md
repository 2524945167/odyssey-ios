# Odyssey 第 8 轮：翻译风格模板与思考设置

状态：已通过云端编译、165 项测试、六张新增页面截图检查及 IPA 下载校验，等待用户真机验收。未调用真实模型，未测量实际提速幅度。

## 用户确认范围

- 首页语言栏下方增加横向风格栏，默认“自然表达”。五项为自然表达、口语聊天、网络游戏聊天、正式商务、自定义。
- 每个预设提示词可独立编辑、保存、恢复默认；自定义项使用用户填写的要求。
- 设置中增加深度思考开关，默认关闭。用户使用 Qwen3.7 Flash 官方 Chat Completions；本轮核实并适配该模型的官方 Chat Completions / Responses，其他服务保持原参数并明确显示“未适配”。
- 保留 8192 tokens / 60 秒默认可调参数、300 秒请求总时长、部分译文保留、不自动重试等既有约束。

## 实现与边界

1. `TranslationStyle` 提供稳定的五种标识和中文可编辑风格模板。固定翻译指令与风格要求分开；用户原文仍原样放在 user/input 中，不混入指令。
2. 游戏风格只在准确、易懂且语境合适时使用常见缩写，否则完整表达；保留否定、行动、角色/技能/地点/数字，不擅加 gg、lol 或攻击性语言。模板文本检查不等同于真实模型质量评测。
3. `TranslationPreferences` 独立保存选择与模板覆盖；旧参数字典缺少 `thinkingEnabled` 时默认为 false，不改变原 token/超时设置和 Keychain。只保存用户主动填写的模板，不保存翻译正文。
4. 编辑页明确保存、恢复默认也需要保存；未保存返回时丢弃草稿。恢复一份模板不改变其他模板。自定义为空时只发送固定翻译规则，其他预设拒绝空白保存。
5. 风格栏运行中不可切换；空闲时切换仅保存选择、不自动请求，并将已有译文标记为旧风格。设置页保存不会改动运行中请求的不可变快照；修改未选中的模板不影响当前结果。
6. 思考控制只匹配官方已核实域名/路径与 `qwen3.7-flash`、`qwen3.7-flash-2026-07-15`。Chat 发送顶层布尔 `enable_thinking`；Responses 发送 `reasoning.effort` 为关闭 `none` / 开启 `medium`。不使用 SDK 专用的 `extra_body` JSON 包装，不发送给其他模型、中转或 Anthropic 接口。
7. 参数页只有在当前配置受支持时显示有效开关；其他配置说明沿用服务商默认，不把 UI 的默认关闭误报为服务端已经关闭。
8. 思考过程仍不显示在译文里。连接测试不受翻译模板和思考开关影响，默认预算/超时仍为 256 tokens / 30 秒。
9. 未实现新语言、术语表、额外要求、后台运行、自动分段、二次审校、多次调用或自动降级；没有迁移用户模型、端点或密钥。

## 自动化验证结果

- 代码提交：[`8dcc33b278e5f0b8efb0eb02799786b61a9eafd5`](https://github.com/2524945167/odyssey-ios/commit/8dcc33b278e5f0b8efb0eb02799786b61a9eafd5)。之后仅更新验收文档，不改变此构建的代码。
- [GitHub Actions #37](https://github.com/2524945167/odyssey-ios/actions/runs/34098748914)，Run ID `34098748914`，Job ID `101668113214`，2026-09-07 完成，结论 `success`；测试与 Release 均成功。
- 在 iPhone 17 / iOS 27.0 模拟器执行 **165 项测试，0 失败**，测试耗时合计 48.792 秒，套件经过时间 66.307 秒。保留第 7 轮 142 项，新增 23 项模板/持久化/迁移、字段白名单、思考开关与协议隔离、参数快照、离线 Qwen SSE 和真实挂载页面浅深色截图测试。
- 使用独立 UserDefaults suite、Mock Keychain/剪贴板、离线传输；测试使用虚构密钥，不请求模型服务。
- 本地和云端 Git 跟踪文件密钥扫描通过；本地 `git diff --check` 与两个 Bash 脚本语法检查通过。本机无 Xcode，iOS 编译依赖云端。
- 编译警告、Actions `##[warning]` 均为 **0**。既有 CI 检查的焦点、状态修改、页面生命周期与 AttributeGraph 诊断均为 0；没有删减检查规则或过滤原始日志。
- **不宣称整个运行日志没有提示**：日志仍有 PointerUI/XPC、UIKit `cannot add handler`、键盘渲染和触觉资源缺失诊断，以及 1 条 `UIKeyboardTaskQueue` 超时提示；165 项测试未因此失败。它们仍保留在原始日志中，不能将模拟器测试等同于微信输入法真机性能验证。

## 产物与本机校验

- IPA Artifact：`Odyssey-unsigned.ipa`，ID `10009796507`，外层 ZIP 541,095 字节；内部 IPA **545,948 字节**。
- 外层 ZIP SHA-256：`94f7fcda0aecfb6363f19d98dfd5f9dc2f9ca93679da0ceb14de9ca727377890`。
- 内部 IPA SHA-256：`869f8251403fdba31ab2868003bd6766bc2cf3e47ba6b8611c2dd5319e3e1e8c`，与 CI 输出逐位一致。
- 下载后检查 ZIP CRC、`Payload/Odyssey.app/Info.plist`、Bundle ID `com.kupetis.odyssey`、最低系统 `27.0`，以及 2,584,152 字节的非空 Mach-O 可执行文件 `Odyssey`。无 `_CodeSignature` / `embedded.mobileprovision`，本轮未签名。
- 本机 IPA：`C:\Users\Kupetis\Downloads\Odyssey-Round8-run37\ipa\Odyssey-unsigned.ipa`。
- 测试 Artifact：`Odyssey-test-results`，ID `10009795614`，21,897,726 字节；SHA-256 `35f589878354f2188b4c5db5fed4c03d7751394956520bcf1f72e0b62ef5de29`，下载值与 GitHub digest 一致。
- 原始日志、xcresult 与截图位于本机 `C:\Users\Kupetis\Downloads\Odyssey-Round8-run37\tests`。

## 截图检查

新增首页风格栏、游戏模板编辑页、受支持接口的翻译参数页各有浅/深色截图，共六张，已逐张查看。使用真实挂载窗口 402 × 874 点、3× 渲染，而非仅断言 ImageRenderer 非空；实际宿主模拟器仍为 iPhone 17。页面文字可读，选中风格蓝色突出，思考开关初始关闭。风格栏横向溢出可滚动，不能从静态截图宣称已完成所有真机点击和滑动验收。

截图映射保存在 `TestAttachments/manifest.json`：

| 页面 | 浅色文件 | 深色文件 |
| --- | --- | --- |
| 首页风格栏 | `48D16CF1-A61A-42B0-99BB-7370A563C643.png` | `68855B88-A960-4DA0-BEE6-248C0B812151.png` |
| 游戏模板 | `CA60004C-9B42-4A20-9417-4C5E4CD18DA5.png` | `C9A92B68-3E89-4B74-B7D9-981A13938838.png` |
| 思考设置 | `285EBA3C-9D38-4C4B-B90E-13E3A7FF22D2.png` | `F76F519E-6951-431D-8F99-5A90CE88A42A.png` |

## 真机验收清单

1. 默认选择自然表达；五项横向滑动可达，深浅色和键盘收起正常。
2. 设置 → 翻译提示词：编辑游戏模板保存，返回首页选择游戏风格；重新进入和重启 App 后仍保存。其他模板不变。
3. 恢复模板后尚未保存时退出，已保存版本不变；恢复后保存，仅当前模板回到默认。自定义空白使用基础翻译规则。
4. 设置 → 翻译参数：Qwen 官方配置显示“深度思考”默认关闭，开启/关闭均需保存；未知服务显示未适配，不声称控制成功。
5. 用相同模型、端点、原文，分别记录关闭/开启思考时从点击到首段译文的等待及总时长，多次比较 hello 和正常短句。网络/服务排队仍可能影响结果，不保证秒回。
6. 分别翻译日常聊天、游戏指令、商务文本，核对意思、缩写、语气、数字与否定；没有真实模型评测前不声称新模板质量必然更高。
7. 流式过程中停止/清除/交换、修改模板及参数后再次翻译，确认无旧请求内容混入，无自动重复请求。

真实模型验收由用户操作或另行明确授权，可能产生费用。用户仅授权本轮开发、离线测试与构建，没有授权开发过程使用其模型密钥。

## 官方参考

- [OpenAI 指令与原文分层](https://developers.openai.com/api/docs/guides/prompt-engineering)
- [百炼 Qwen 思考模型、默认值及 Chat 参数](https://www.alibabacloud.com/help/zh/model-studio/deep-thinking)
- [百炼 Responses 思考参数及官方域名](https://www.alibabacloud.com/help/zh/model-studio/compatibility-with-openai-responses-api)
