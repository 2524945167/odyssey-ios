# Odyssey

Odyssey 是一款轻量、现代的 iOS 客户端应用。

## 当前状态

**第 8 轮翻译风格模板与思考设置已实现，等待 CI 与真机验收**。首页新增五种风格，模板可在设置中独立编辑；已核实的 Qwen3.7 Flash 官方接口支持默认关闭的思考开关，其他服务不发送该参数且明确标记未适配。范围和验收项见 [第 8 轮验收记录](ROUND8_VERIFICATION.md)。未调用真实模型，不声称已实测提速。

**第 7 轮真实流式翻译接入已通过 CI，等待真机验收**。[GitHub Actions 第 36 次运行](https://github.com/2524945167/odyssey-ios/actions/runs/34092020577) 的 142 项测试全部通过，编译与 Actions 警告为 0，未签名 IPA 已下载并核对哈希。正式翻译默认输出上限 8192 tokens、无数据超时 60 秒，两项可在“设置 → 翻译参数”自定义；单次请求最多 5 分钟。连接测试的 256 tokens / 30 秒保持独立。首页已接入三协议流式翻译，支持停止、保留部分译文与明确的未完成提示，不自动重试。范围、产物证据、模拟器系统诊断与待验收项见 [第 7 轮验收记录](ROUND7_VERIFICATION.md)。测试使用离线服务，尚未执行真实模型调用。

用户已对第 6 轮反馈“没问题了”并批准进入第 7 轮；按该反馈记录轮次通过，不推断未提供的逐项真机测试结果。

第 6 轮通过 [GitHub Actions 第 35 次运行](https://github.com/2524945167/odyssey-ios/actions/runs/34085782572)：117 项测试全部通过，编译与 Actions 警告为 0，已知的页面渲染、焦点布局及测试生命周期诊断也已消除。首页采用局部原生输入控件同步键盘主题；没有新增真实模型调用或改动连接测试默认 256-token 上限。模拟器仍有系统键盘/触觉等诊断，不宣称整个运行日志完全无提示。最终代码提交、IPA 哈希、失败检查点和真机清单见 [第 6 轮验收记录](ROUND6_VERIFICATION.md)。

第 4 轮通过 [GitHub Actions 第 28 次运行的重试](https://github.com/2524945167/odyssey-ios/actions/runs/34035461881)：67 项测试通过，Release 编译与未签名 IPA 打包、结构校验成功；日志存在 3 条 AppIntents 元数据提取跳过警告，不宣称零警告。连接测试默认输出上限为 256 tokens，可由用户自定义；首页仍是本地模拟翻译。范围、费用说明与产物证据见 [第 4 轮验收记录](ROUND4_VERIFICATION.md)，历史结果见 [第 3 轮验收记录](ROUND3_VERIFICATION.md)。用户已表示“没问题，继续下一轮”，但未提供逐项真机或真实服务测试记录，不将 CI 结果描述为已完成这些测试。

第 5 轮通过 [GitHub Actions 第 29 次运行](https://github.com/2524945167/odyssey-ios/actions/runs/34040390958)：保留原有 67 项、新增 35 项，共 102 项测试全部通过；Release 编译、未签名 IPA 打包及结构校验通过。日志仍有 3 条 AppIntents 元数据提取跳过警告。本轮只新增 SSE 传输与三协议适配，没有真实模型请求、UI 变化或新的翻译默认预算；范围、安全边界及确切提交和产物证据见 [第 5 轮验收记录](ROUND5_VERIFICATION.md)。

## 如何触发 GitHub Actions

GitHub Actions CI 流水线配置为自动执行，支持以下触发方式：
1. **代码推送**：向任何分支执行 `git push` 会自动触发 CI。
2. **Pull Request**：向仓库创建或更新 PR 时自动触发。
3. **手动触发**：在 GitHub 仓库页面进入 **Actions** 标签页，在左侧选择 **Odyssey CI**，点击右侧的 **Run workflow** 按钮即可手动执行。

## 如何下载未签名 IPA

CI 构建成功后会自动打包未签名的 IPA 文件供自签工具使用：
1. 打开 GitHub 仓库页面，进入 **Actions** 标签页。
2. 点击进入最新一次执行成功的 **Odyssey CI** 工作流运行记录。
3. 滚动到页面底部的 **Artifacts** 区域。
4. 点击下载 **`Odyssey-unsigned.ipa`**。
5. 解压下载的压缩包即可获取 `Odyssey-unsigned.ipa`，可直接传输至 iPhone 使用自签工具（如 TrollStore、AltStore、SideStore 或自签证书）进行安装与测试。
