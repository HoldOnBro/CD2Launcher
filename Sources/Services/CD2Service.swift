import Foundation
import Combine
import AppKit
import ServiceManagement

struct CD2MountConfig: Codable {
    let name: String
    let sourcePath: String
    let mountPoint: String
    let readOnly: Bool
    let localMount: Bool
    let autoMount: Bool
    
    enum CodingKeys: String, CodingKey {
        case name
        case sourcePath = "source_path"
        case mountPoint = "mount_point"
        case readOnly = "read_only"
        case localMount = "local_mount"
        case autoMount = "auto_mount"
    }
}

struct CD2Config: Codable {
    let mountPoints: [CD2MountConfig]
    
    enum CodingKeys: String, CodingKey {
        case mountPoints = "mount_points"
    }
}

class CD2Service: ObservableObject {
    
    @Published private(set) var isRunning = false
    @Published private(set) var isInstalled = false
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var systemInfo: CD2SystemInfo?
    @Published private(set) var mountPoints: [CD2MountPoint] = []
    @Published private(set) var errorMessage: String?
    @Published var needsAPITokenConfiguration: Bool = false
    @Published private(set) var isUpdateAvailable: Bool = false
    @Published private(set) var latestVersion: String = ""
    
    private var monitoringTimer: Timer?
    
    private let currentVersion = "1.0.1"
    private let latestVersionURL = "https://api.github.com/repos/cloud-fs/cloud-fs.github.io/releases/latest"
    
    private let cd2InstallBasePath = "/Users/xyz/Waytech/CloudDrive2"
    private var cd2ExecutablePath: String {
        return "\(cd2InstallBasePath)/clouddrive"
    }
    private var cd2ConfigPath: String {
        return cd2InstallBasePath
    }
    
    private let cd2CLIPath = "/Users/xyz/Documents/CD2Launcher/cmd/cd2cli/cd2_mounter"
    
    private let apiTokenKey = "CD2APIToken"
    var apiToken: String? {
        get { UserDefaults.standard.string(forKey: apiTokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: apiTokenKey) }
    }
    
    private let wasRunningKey = "CD2WasRunning"
    private let wasMountedKey = "CD2WasMounted"
    
    var hasAPIToken: Bool {
        guard let token = apiToken, !token.isEmpty else { return false }
        return true
    }
    
    func saveStateForQuit() {
        UserDefaults.standard.set(isRunning, forKey: wasRunningKey)
        let hasMountedMounts = mountPoints.contains { $0.isMounted }
        UserDefaults.standard.set(hasMountedMounts, forKey: wasMountedKey)
        UserDefaults.standard.synchronize()
        print("Saved state: wasRunning=\(isRunning), wasMounted=\(hasMountedMounts)")
    }
    
    func restoreStateOnLaunch() {
        let wasRunning = UserDefaults.standard.bool(forKey: wasRunningKey)
        let wasMounted = UserDefaults.standard.bool(forKey: wasMountedKey)
        print("Restoring state: wasRunning=\(wasRunning), wasMounted=\(wasMounted)")
        
        if wasRunning && isInstalled && !isRunning {
            startCD2()
        }
        
        if wasMounted && isRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.restoreMounts()
            }
        }
    }
    
    private func restoreMounts() {
        for mp in mountPoints {
            if mp.isMounted {
                continue
            }
            print("Auto-mounting: \(mp.mountPoint)")
            mount(mountPoint: mp.mountPoint)
        }
    }
    
    private var cd2ConfigFilePath: String {
        return "\(cd2InstallBasePath)/config.toml"
    }
    
    private var cloudFSMountBase: String {
        if let config = loadMountConfig(), let firstMount = config.mountPoints.first {
            return firstMount.mountPoint
        }
        return "/Users/xyz/Documents/4800PLUS"
    }
    
    private let downloadBaseURL = "https://github.com/cloud-fs/cloud-fs.github.io/releases/download/v1.0.1"
    
    init() {
        checkInstallation()
        checkStatus()
    }
    
    func loadMountConfig() -> CD2Config? {
        let configPath = cd2ConfigFilePath
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return nil
        }
        
        return parseTOMLConfig(content)
    }
    
    private func parseTOMLConfig(_ content: String) -> CD2Config? {
        var mountPoints: [CD2MountConfig] = []
        
        let lines = content.components(separatedBy: .newlines)
        var currentMount: [String: String] = [:]
        var inMountSection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed == "[[mount_points]]" {
                if !currentMount.isEmpty {
                    if let mp = createMountConfig(from: currentMount) {
                        mountPoints.append(mp)
                    }
                }
                currentMount = [:]
                inMountSection = true
                continue
            }
            
            if inMountSection {
                if trimmed.hasPrefix("name") {
                    currentMount["name"] = extractValue(from: trimmed)
                } else if trimmed.hasPrefix("source_path") {
                    currentMount["source_path"] = extractValue(from: trimmed)
                } else if trimmed.hasPrefix("mount_point") {
                    currentMount["mount_point"] = extractValue(from: trimmed)
                } else if trimmed.hasPrefix("read_only") {
                    currentMount["read_only"] = extractValue(from: trimmed)
                } else if trimmed.hasPrefix("local_mount") {
                    currentMount["local_mount"] = extractValue(from: trimmed)
                } else if trimmed.hasPrefix("auto_mount") {
                    currentMount["auto_mount"] = extractValue(from: trimmed)
                } else if trimmed.isEmpty || trimmed.hasPrefix("[") {
                    inMountSection = false
                    if !currentMount.isEmpty {
                        if let mp = createMountConfig(from: currentMount) {
                            mountPoints.append(mp)
                        }
                        currentMount = [:]
                    }
                }
            }
        }
        
        if !currentMount.isEmpty {
            if let mp = createMountConfig(from: currentMount) {
                mountPoints.append(mp)
            }
        }
        
        return CD2Config(mountPoints: mountPoints)
    }
    
    private func extractValue(from line: String) -> String {
        let parts = line.components(separatedBy: "=")
        if parts.count >= 2 {
            return parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
        }
        return ""
    }
    
    private func createMountConfig(from dict: [String: String]) -> CD2MountConfig? {
        guard let name = dict["name"],
              let sourcePath = dict["source_path"],
              let mountPoint = dict["mount_point"] else {
            return nil
        }
        
        let readOnly = dict["read_only"] == "true"
        let localMount = dict["local_mount"] == "true"
        let autoMount = dict["auto_mount"] == "true"
        
        return CD2MountConfig(
            name: name,
            sourcePath: sourcePath,
            mountPoint: mountPoint,
            readOnly: readOnly,
            localMount: localMount,
            autoMount: autoMount
        )
    }
    
    private func getArchitecture() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        
        if machine.contains("arm64") || machine.contains("aarch64") {
            return "aarch64"
        } else {
            return "x86_64"
        }
    }
    
    private func getDownloadURL() -> String {
        let arch = getArchitecture()
        return "\(downloadBaseURL)/clouddrive-2-macos-\(arch)-1.0.1.tgz"
    }
    
    private func checkInstallation() {
        let installed = FileManager.default.fileExists(atPath: cd2ExecutablePath)
        DispatchQueue.main.async {
            self.isInstalled = installed
        }
    }
    
    func checkForUpdates() {
        guard let url = URL(string: latestVersionURL) else { return }
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            do {
                let data = try Data(contentsOf: url)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tagName = json["tag_name"] as? String {
                    let latestVer = tagName.replacingOccurrences(of: "v", with: "")
                    DispatchQueue.main.async {
                        self?.latestVersion = latestVer
                        self?.isUpdateAvailable = latestVer != self?.currentVersion
                    }
                }
            } catch {
                print("Failed to check for updates: \(error)")
            }
        }
    }
    
    func startMonitoring() {
        checkStatus()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    func checkStatus() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let running = self.checkIfCD2IsRunning()
            DispatchQueue.main.async {
                self.isRunning = running
            }
            
            if running {
                self.fetchMountPointsFromFileSystem()
            } else {
                DispatchQueue.main.async {
                    self.mountPoints = []
                }
            }
        }
    }
    
    private func checkIfCD2IsRunning() -> Bool {
        return checkPort(port: 19798)
    }
    
    private func checkPort(port: Int) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-i", ":19798", "-n"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return output.contains("LISTEN")
        } catch {
            return false
        }
    }
    
    private func fetchMountPointsFromFileSystem() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var mounts: [CD2MountPoint] = []
            
            let fileManager = FileManager.default
            
            guard let config = self.loadMountConfig() else {
                DispatchQueue.main.async {
                    self.mountPoints = []
                }
                return
            }
            
            // Get the list of currently active mount points from the system
            let activeMounts = self.getActiveSystemMounts()
            
            for mountConfig in config.mountPoints {
                let fullPath = mountConfig.mountPoint
                var isDirectory: ObjCBool = false
                
                guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    // Directory doesn't exist — still show it as unmounted
                    let mount = CD2MountPoint(
                        id: mountConfig.name,
                        mountPoint: fullPath,
                        sourceDir: mountConfig.sourcePath,
                        localMount: mountConfig.localMount,
                        autoMount: mountConfig.autoMount,
                        isMounted: false
                    )
                    mounts.append(mount)
                    continue
                }
                
                // Use statfs to reliably detect if this path is an active mount point
                let isMounted = self.isPathMounted(fullPath, activeMounts: activeMounts)
                
                let mount = CD2MountPoint(
                    id: mountConfig.name,
                    mountPoint: fullPath,
                    sourceDir: mountConfig.sourcePath,
                    localMount: mountConfig.localMount,
                    autoMount: mountConfig.autoMount,
                    isMounted: isMounted
                )
                mounts.append(mount)
            }
            
            DispatchQueue.main.async {
                self.mountPoints = mounts
            }
        }
    }
    
    /// Get list of active mount points from the system using /sbin/mount
    private func getActiveSystemMounts() -> Set<String> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/sbin/mount")
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            var mounts = Set<String>()
            for line in output.components(separatedBy: "\n") {
                // Format: "device on /mount/point (type, options)"
                let parts = line.components(separatedBy: " on ")
                if parts.count >= 2 {
                    let rest = parts[1]
                    if let parenRange = rest.range(of: " (") {
                        let mountPath = String(rest[rest.startIndex..<parenRange.lowerBound])
                        mounts.insert(mountPath)
                    }
                }
            }
            return mounts
        } catch {
            return []
        }
    }
    
    /// Check if a path is an active mount point using system mount list
    private func isPathMounted(_ path: String, activeMounts: Set<String>) -> Bool {
        // Check if this path is in the active mount list from /sbin/mount
        if activeMounts.contains(path) {
            return true
        }
        
        // Also check if any active mount is a child of this path
        // (handles cases where the mount path in config differs slightly)
        let normalizedPath = (path as NSString).standardizingPath
        for mount in activeMounts {
            let normalizedMount = (mount as NSString).standardizingPath
            if normalizedMount == normalizedPath {
                return true
            }
        }
        
        return false
    }
    
    func downloadAndInstallCD2(completion: @escaping (Bool) -> Void) {
        guard !isDownloading else { return }
        
        DispatchQueue.main.async {
            self.isDownloading = true
            self.downloadProgress = 0
            self.errorMessage = nil
        }
        
        let downloadURL = getDownloadURL()
        guard let url = URL(string: downloadURL) else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid download URL"
                self.isDownloading = false
            }
            completion(false)
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("clouddrive-2-macos-1.0.1.tgz")
        let extractDir = tempDir.appendingPathComponent("clouddrive-2-macos-1.0.1")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                if FileManager.default.fileExists(atPath: tempFile.path) {
                    try FileManager.default.removeItem(at: tempFile)
                }
                if FileManager.default.fileExists(atPath: extractDir.path) {
                    try FileManager.default.removeItem(at: extractDir)
                }
                
                self?.downloadFile(from: url, to: tempFile) { success in
                    guard success else {
                        DispatchQueue.main.async {
                            self?.errorMessage = "Download failed"
                            self?.isDownloading = false
                        }
                        completion(false)
                        return
                    }
                    
                    self?.extractAndInstall(from: tempFile, extractDir: extractDir, completion: completion)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.isDownloading = false
                }
                completion(false)
            }
        }
    }
    
    private func downloadFile(from url: URL, to destination: URL, completion: @escaping (Bool) -> Void) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: .main)
        
        let task = session.downloadTask(with: url) { [weak self] tempURL, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = "Download error: \(error.localizedDescription)"
                }
                completion(false)
                return
            }
            
            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self?.errorMessage = "No file downloaded"
                }
                completion(false)
                return
            }
            
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: tempURL, to: destination)
                completion(true)
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to save file: \(error.localizedDescription)"
                }
                completion(false)
            }
        }
        
        task.resume()
    }
    
    private func extractAndInstall(from tarFile: URL, extractDir: URL, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            self.downloadProgress = 0.5
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                task.arguments = ["-xzf", tarFile.path, "-C", FileManager.default.temporaryDirectory.path]
                task.currentDirectoryURL = FileManager.default.temporaryDirectory
                
                try task.run()
                task.waitUntilExit()
                
                guard task.terminationStatus == 0 else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Failed to extract archive"
                        self?.isDownloading = false
                    }
                    completion(false)
                    return
                }
                
                let innerDir = FileManager.default.temporaryDirectory.appendingPathComponent("clouddrive-2-macos-aarch64-1.0.1")
                
                let installDir = URL(fileURLWithPath: self?.cd2InstallBasePath ?? "/Users/xyz/Waytech/CloudDrive2")
                
                if FileManager.default.fileExists(atPath: installDir.path) {
                    try FileManager.default.removeItem(at: installDir)
                }
                try FileManager.default.createDirectory(at: installDir, withIntermediateDirectories: true)
                
                let extractedClouddrive = innerDir.appendingPathComponent("clouddrive")
                let destClouddrive = installDir.appendingPathComponent("clouddrive")
                
                if FileManager.default.fileExists(atPath: extractedClouddrive.path) {
                    try FileManager.default.copyItem(at: extractedClouddrive, to: destClouddrive)
                }
                
                let wwwroot = innerDir.appendingPathComponent("wwwroot")
                let destWwwroot = installDir.appendingPathComponent("wwwroot")
                if FileManager.default.fileExists(atPath: wwwroot.path) {
                    try FileManager.default.copyItem(at: wwwroot, to: destWwwroot)
                }
                
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destClouddrive.path)
                
                DispatchQueue.main.async {
                    self?.downloadProgress = 1.0
                    self?.isDownloading = false
                    self?.isInstalled = true
                }
                
                completion(true)
                
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = "Installation failed: \(error.localizedDescription)"
                    self?.isDownloading = false
                }
                completion(false)
            }
        }
    }
    
    func startCD2() {
        if !isInstalled {
            downloadAndInstallCD2 { [weak self] success in
                if success {
                    self?.doStartCD2()
                }
            }
        } else {
            doStartCD2()
        }
    }
    
    private func doStartCD2() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: cd2ExecutablePath)
        task.currentDirectoryURL = URL(fileURLWithPath: cd2ConfigPath)
        task.arguments = []
        
        do {
            try task.run()
            DispatchQueue.main.async {
                self.isRunning = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.checkStatus()
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start CloudDrive2: \(error.localizedDescription)"
            }
        }
    }
    
    func stopCD2() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["clouddrive"]
        
        do {
            try task.run()
            task.waitUntilExit()
            DispatchQueue.main.async {
                self.isRunning = false
                self.mountPoints = []
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to stop CloudDrive2: \(error.localizedDescription)"
            }
        }
    }
    
    func mount(mountPoint: String) {
        print("Mount requested for: \(mountPoint)")
        
        guard let token = apiToken, !token.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = Localized.str("API token not configured. Please configure your API token in settings.")
                self.needsAPITokenConfiguration = true
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.runCD2CLI(action: "mount", mountPoint: mountPoint, token: token)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.checkStatus()
                if result == false {
                    self?.errorMessage = Localized.str("Failed to mount via CloudDrive2 API")
                }
            }
        }
    }
    
    func unmount(mountPoint: String) {
        print("Unmount requested for: \(mountPoint)")
        
        guard let token = apiToken, !token.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = Localized.str("API token not configured. Please configure your API token in settings.")
                self.needsAPITokenConfiguration = true
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let success = self?.runCD2CLI(action: "unmount", mountPoint: mountPoint, token: token) ?? false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.checkStatus()
                if !success {
                    self?.errorMessage = Localized.str("Failed to unmount via CloudDrive2 API")
                }
            }
        }
    }
    
    private func tryLocalUnmount(mountPoint: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["unmount", mountPoint]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            print("Local unmount result: \(output)")
            
            if task.terminationStatus == 0 {
                return true
            }
            
            // diskutil failed, try umount as fallback (works for FUSE mounts)
            let fallbackTask = Process()
            fallbackTask.executableURL = URL(fileURLWithPath: "/sbin/umount")
            fallbackTask.arguments = [mountPoint]
            
            let fallbackPipe = Pipe()
            fallbackTask.standardOutput = fallbackPipe
            fallbackTask.standardError = fallbackPipe
            
            try fallbackTask.run()
            fallbackTask.waitUntilExit()
            
            let fallbackData = fallbackPipe.fileHandleForReading.readDataToEndOfFile()
            let fallbackOutput = String(data: fallbackData, encoding: .utf8) ?? ""
            print("Fallback umount result: \(fallbackOutput)")
            
            return fallbackTask.terminationStatus == 0
        } catch {
            print("Local unmount error: \(error.localizedDescription)")
            return false
        }
    }
    
    private func runCD2CLI(action: String, mountPoint: String, token: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: cd2CLIPath)
        task.arguments = ["-action", action, "-mountpoint", mountPoint, "-token", token]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            print("CD2 CLI \(action) result: \(output)")
            
            return task.terminationStatus == 0 && output.contains("Success")
        } catch {
            print("CD2 CLI error: \(error.localizedDescription)")
            return false
        }
    }
    
    func openMountPoint(_ mountPoint: CD2MountPoint) {
        let path = mountPoint.mountPoint
        let url = URL(fileURLWithPath: path)
        
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(url)
        } else if mountPoint.isMounted {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openWebUI() {
        if let url = URL(string: "http://localhost:19798") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openCloudFSRoot() {
        let url = URL(fileURLWithPath: cloudFSMountBase)
        NSWorkspace.shared.open(url)
    }
    
    func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to set launch at login: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func getLaunchAtLoginStatus() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
