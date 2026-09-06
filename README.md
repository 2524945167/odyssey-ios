# Odyssey

Odyssey 是一款轻量、现代的 iOS 客户端应用。

## 当前状态

**第 5 轮流式接收基础已实现并通过 CI；尚未接入首页真实翻译**。

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
