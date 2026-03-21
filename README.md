# CD2Launcher

一款用于管理 CloudDrive2 挂载点的 macOS 菜单栏应用。

## 功能特性

- **菜单栏集成**：作为菜单栏应用运行（无 Dock 图标）
- **挂载/卸载管理**：直接从菜单栏挂载和卸载云盘
- **CloudDrive2 API 集成**：使用 CloudDrive2 的 gRPC API 进行可靠的挂载操作
- **状态持久化**：记住 CloudDrive2 运行状态和挂载状态，跨重启保持
- **多语言支持**：支持英文和简体中文（自动检测系统语言）
- **网页端访问**：快速访问 CloudDrive2 网页端

## 系统要求

- macOS 12.0 (Monterey) 或更高版本
- 已安装并运行 [CloudDrive2](https://www.clouddrive2.com/)
- 需要具有挂载管理权限的 CloudDrive2 API 令牌

## 安装

1. 从 Releases 页面下载最新版本
2. 将 `CD2Launcher.app` 移动到应用程序文件夹
3. 启动 CD2Launcher
4. 通过设置按钮配置您的 CloudDrive2 API 令牌

## 配置

### 获取 API 令牌

1. 打开 CloudDrive2 网页端
2. 进入「系统管理」
3. 点击「API 令牌」
4. 点击「创建令牌」
5. 勾选「挂载管理」权限
6. 复制生成的令牌
7. 粘贴到 CD2Launcher 的设置对话框中

## 使用方法

- **点击菜单栏图标** 打开弹出窗口
- **启动/停止** CloudDrive2 服务
- **挂载/卸载** 云盘（点击操作按钮）
- **网页端** 访问 CloudDrive2 进行完整管理
- **设置按钮**（齿轮图标）配置 API 令牌

## 从源码构建

```bash
# 如果尚未安装 XcodeGen
brew install xcodegen

# 生成 Xcode 项目
xcodegen generate

# 在 Xcode 中打开
open CD2Launcher.xcodeproj
```

## 许可证

MIT 许可证
