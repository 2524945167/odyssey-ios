# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Security & Secret Management Guidelines

1. **No Committed Secrets**:
   - 严禁在仓库中提交任何私钥、证书、Provisioning Profile、密码或 API Key。
   - 所有敏感凭证必须通过环境变量或安全的外部配置注入，不得进入 Git 历史记录。

2. **Automated Secret Scanning**:
   - CI 流水线包含自动化密钥扫描机制 (`Scripts/scan_secrets.sh`)，在每次构建和测试前强制检查，阻止潜在敏感信息泄漏。

## Reporting a Vulnerability

若发现潜在的安全漏洞或敏感信息泄漏风险，请不要通过公开的 Issue 提交。请通过私人渠道联系安全负责人或仓库管理员进行报告与处理。
