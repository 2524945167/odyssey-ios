# Odyssey

Odyssey 是一款轻量、现代的 iOS 客户端应用。

## 当前状态

**第 2 轮完成**（已建立翻译首页与设置页 UI、MVVM 架构与轻量 ViewModel，并通过 GitHub Actions 自动构建与验证未签名 IPA）。

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
