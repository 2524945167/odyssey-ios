# Odyssey

Odyssey 是一款轻量、现代的 iOS 客户端应用。

## 当前状态

**第 3 轮已获用户真机确认，第 4 轮本地开发中（待 CI 与真机验收）**。

第 3 轮补修通过 [GitHub Actions 第 25 次运行](https://github.com/2524945167/odyssey-ios/actions/runs/34030365899)：36 项测试通过，未签名 IPA 已生成；日志存在 3 条 AppIntents 元数据提取跳过警告。历史结果见 [第 3 轮验收记录](ROUND3_VERIFICATION.md)。第 4 轮连接测试代码及默认 256、可自定义的测试输出上限已编写，尚未编译验收；范围、费用说明与测试清单见 [第 4 轮验收记录](ROUND4_VERIFICATION.md)。

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
