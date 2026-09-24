# roc_desk 发布仓库

本仓库保存各工具的可下载 Windows 构建产物。

## 最新版本

- [v0.1.1](https://github.com/swimhigh/roc_desk-releases/releases/tag/v0.1.1)：修复双击后立即退出，六个 EXE 均可保持运行并显示窗口。

## 工具列表

- `roc_desk-http.exe`：HTTP 请求工具
- `roc_desk-explorer.exe`：文件浏览工具
- `roc_desk-editor.exe`：文本编辑工具
- `roc_desk-sql.exe`：SQL 数据库工具
- `roc_desk-ssh.exe`：SSH/SFTP 连接工具（含内嵌 RDP 用的 `wfreerdp.exe`）
- `roc_desk-workspace.exe`：工作区与终端工具

当前版本用于迁移阶段的人工启动验证，业务功能仍在持续接入。各工具自己的构建脚本
位于对应仓库的 `build-standalone.ps1`。

## 批量打包（.github/workflows/bundle.yml）

六个工具各自在自己的仓库独立发版（各自的 CI `build-standalone.yml`，标签号互不
相同），这里的 `bundle.yml` 是手动触发（Actions 页面 → Bundle standalone tools →
Run workflow，填一个 tag 名如 `v0.3.0`）：自动从六个仓库各自拉最新一次 release 的
exe（以及 `roc_desk-ssh` 的 `wfreerdp.exe` 运行依赖），打进同一个 zip，发布成这个
仓库的新 release。

**为什么要打包到同一个目录**：每个 standalone exe 的数据目录都是相对自己 exe 路径
解析的 `.rock_desk` 子目录（`roc_desk_core::paths::portable_data_dir`，和完整版
`roc_desk.exe` 的便携部署约定一致）——解压这个 zip 到一个目录里跑，六个工具会自动
共享同一份 `.rock_desk`，不需要额外配置。

这个 workflow 只是把"已经发布过的"资产重新打包一遍，不会重新触发各工具自己的构建；
先确保六个仓库各自的最新 release 已经是你想要打包的版本。
