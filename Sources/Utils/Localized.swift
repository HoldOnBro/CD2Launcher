import Foundation

struct Localized {
    static var isChinese: Bool {
        let languages = Locale.preferredLanguages
        return languages.first { $0.hasPrefix("zh") } != nil
    }
    
    static func str(_ key: String) -> String {
        if isChinese {
            return chineseStrings[key] ?? englishStrings[key] ?? key
        }
        return englishStrings[key] ?? key
    }
    
    private static let englishStrings: [String: String] = [
        // Status bar
        "CloudDrive2": "CloudDrive2",
        "Running": "Running",
        "Stopped": "Stopped",
        "No mounts": "No mounts",
        "Mounted": "Mounted",
        
        // Buttons
        "Start": "Start",
        "Stop": "Stop",
        "Web UI": "Web UI",
        "Open CloudFS": "Open CloudFS",
        "Launch at Login": "Launch at Login",
        
        // Mount points
        "Mount Points": "Mount Points",
        "No mount points configured": "No mount points configured",
        "Open": "Open",
        "Mount": "Mount",
        "Unmount": "Unmount",
        
        // API Token
        "API Token Configuration": "API Token Configuration",
        "API Token Required": "API Token Required",
        "Enter your CloudDrive2 API token to enable mount/unmount functionality.": "Enter your CloudDrive2 API token to enable mount/unmount functionality.",
        "To enable mount/unmount functionality, you need to configure your CloudDrive2 API token.": "To enable mount/unmount functionality, you need to configure your CloudDrive2 API token.",
        "Enter API token (e.g., 32ebaf5d-b957-4db7-b1d8-1ccfa4957670)": "Enter API token (e.g., 32ebaf5d-b957-4db7-b1d8-1ccfa4957670)",
        "How to get API Token": "How to get API Token",
        "Save": "Save",
        "Cancel": "Cancel",
        "Help ?": "Help ?",
        "Configure Now": "Configure Now",
        "Later": "Later",
        
        // Help text
        "Help": "Help",
        "Click \"Help\" to see how to create an API token in CloudDrive2 Web UI.": "Click \"Help\" to see how to create an API token in CloudDrive2 Web UI.",
        "1. Open CloudDrive2 Web UI (click \"Web UI\" button)": "1. Open CloudDrive2 Web UI (click \"Web UI\" button)",
        "2. Go to \"System Management\" (系统管理)": "2. Go to \"System Management\" (系统管理)",
        "3. Click \"API Tokens\" (API令牌)": "3. Click \"API Tokens\" (API令牌)",
        "4. Click \"Create Token\" (创建令牌)": "4. Click \"Create Token\" (创建令牌)",
        "5. Set permissions to include Mount Management (挂载管理)": "5. Set permissions to include Mount Management (挂载管理)",
        "6. Copy the token and paste it here": "6. Copy the token and paste it here",
        
        // Errors
        "API token not configured. Please configure your API token in settings.": "API token not configured. Please configure your API token in settings.",
        "Failed to mount via CloudDrive2 API": "Failed to mount via CloudDrive2 API",
        "Failed to unmount via CloudDrive2 API": "Failed to unmount via CloudDrive2 API",
        
        // Version
        "v1.0": "v1.0",
        "Update Available": "Update Available",
        "A new version is available. Please download from CloudDrive2 website.": "A new version is available. Please download from CloudDrive2 website.",
        "Current Version": "Current Version",
        "Latest Version": "Latest Version",
        
        // Menu
        "Quit CD2Launcher": "Quit CD2Launcher",
    ]
    
    private static let chineseStrings: [String: String] = [
        // Status bar
        "CloudDrive2": "CloudDrive2",
        "Running": "运行中",
        "Stopped": "已停止",
        "No mounts": "无挂载",
        "Mounted": "已挂载",
        
        // Buttons
        "Start": "启动",
        "Stop": "停止",
        "Web UI": "网页端",
        "Open CloudFS": "打开云盘",
        "Launch at Login": "开机启动",
        
        // Mount points
        "Mount Points": "挂载点",
        "No mount points configured": "未配置挂载点",
        "Open": "打开",
        "Mount": "挂载",
        "Unmount": "卸载",
        
        // API Token
        "API Token Configuration": "API 令牌配置",
        "API Token Required": "需要 API 令牌",
        "Enter your CloudDrive2 API token to enable mount/unmount functionality.": "请输入您的 CloudDrive2 API 令牌以启用挂载/卸载功能。",
        "To enable mount/unmount functionality, you need to configure your CloudDrive2 API token.": "要启用挂载/卸载功能，您需要配置 CloudDrive2 API 令牌。",
        "Enter API token (e.g., 32ebaf5d-b957-4db7-b1d8-1ccfa4957670)": "输入 API 令牌（如 32ebaf5d-b957-4db7-b1d8-1ccfa4957670）",
        "How to get API Token": "如何获取 API 令牌",
        "Save": "保存",
        "Cancel": "取消",
        "Help ?": "帮助？",
        "Configure Now": "立即配置",
        "Later": "稍后",
        
        // Help text
        "Help": "帮助",
        "Click \"Help\" to see how to create an API token in CloudDrive2 Web UI.": "点击「帮助」查看如何在 CloudDrive2 网页端创建 API 令牌。",
        "1. Open CloudDrive2 Web UI (click \"Web UI\" button)": "1. 打开 CloudDrive2 网页端（点击「网页端」按钮）",
        "2. Go to \"System Management\" (系统管理)": "2. 进入「系统管理」",
        "3. Click \"API Tokens\" (API令牌)": "3. 点击「API 令牌」",
        "4. Click \"Create Token\" (创建令牌)": "4. 点击「创建令牌」",
        "5. Set permissions to include Mount Management (挂载管理)": "5. 设置权限，勾选「挂载管理」",
        "6. Copy the token and paste it here": "6. 复制令牌并粘贴到这里",
        
        // Errors
        "API token not configured. Please configure your API token in settings.": "API 令牌未配置，请在设置中配置您的 API 令牌。",
        "Failed to mount via CloudDrive2 API": "通过 CloudDrive2 API 挂载失败",
        "Failed to unmount via CloudDrive2 API": "通过 CloudDrive2 API 卸载失败",
        
        // Version
        "v1.0": "v1.0",
        "Update Available": "发现新版本",
        "A new version is available. Please download from CloudDrive2 website.": "发现新版本，请前往 CloudDrive2 网站下载。",
        "Current Version": "当前版本",
        "Latest Version": "最新版本",
        
        // Menu
        "Quit CD2Launcher": "退出 CD2Launcher",
    ]
}
