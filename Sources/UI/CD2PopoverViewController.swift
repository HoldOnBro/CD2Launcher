import AppKit
import Combine

class CD2PopoverViewController: NSViewController, NSWindowDelegate {
    
    private let cd2Service: CD2Service
    private var cancellables = Set<AnyCancellable>()
    
    // Layout constants for consistent spacing
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 14
    private let sectionSpacing: CGFloat = 2
    private let popoverWidth: CGFloat = 320
    
    private var headerView: NSView!
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var footerView: NSView!
    private var apiTokenPanel: NSWindow?
    private var apiTokenField: NSTextField?

        // MARK: - 快捷键支持 (关键修复)
        // 重写此方法确保 Command+C/V/X 等快捷键在弹出窗口中有效
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "x": return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
            case "c": return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            case "v": return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
            case "a": return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    // --- Header elements ---
    
    private lazy var statusDot: NSView = {
        let dot = NSView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 5
        return dot
    }()
    
    private lazy var titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "CloudDrive2")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .labelColor
        return label
    }()
    
    private lazy var statusLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Checking...")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        return label
    }()
    
    private lazy var actionButton: NSButton = {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.target = self
        button.action = #selector(toggleCD2)
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        return button
    }()
    
    // --- Quick action buttons row ---
    
    private lazy var buttonRow: NSStackView = {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        return stack
    }()
    
    private lazy var webUIButton: NSButton = {
        let button = NSButton(title: Localized.str("Web UI"), target: self, action: #selector(openWebUI))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        button.controlSize = .small
        return button
    }()
    
    // --- Download progress ---
    
    private lazy var downloadProgressView: NSProgressIndicator = {
        let progress = NSProgressIndicator()
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.isHidden = true
        return progress
    }()
    
    private lazy var downloadLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Downloading CloudDrive2...")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 10)
        label.textColor = .secondaryLabelColor
        label.isHidden = true
        return label
    }()
    
    // --- Mount section ---
    
    private lazy var mountsHeaderLabel: NSTextField = {
        let label = NSTextField(labelWithString: Localized.str("Mount Points").uppercased())
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }()
    
    private lazy var emptyStateLabel: NSTextField = {
        let label = NSTextField(labelWithString: Localized.str("No mount points configured"))
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabelColor
        label.alignment = .center
        return label
    }()
    
    // --- Footer ---
    
    private lazy var launchAtLoginCheckbox: NSButton = {
        let button = NSButton(checkboxWithTitle: Localized.str("Launch at Login"), target: self, action: #selector(toggleLaunchAtLogin))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11)
        return button
    }()
    
    private lazy var settingsButton: NSButton = {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: Localized.str("Settings"))
        button.contentTintColor = .secondaryLabelColor
        button.target = self
        button.action = #selector(openSettings)
        button.toolTip = Localized.str("Settings")
        return button
    }()
    
    private lazy var versionLabel: NSTextField = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let label = NSTextField(labelWithString: "v\(version)")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 10)
        label.textColor = .tertiaryLabelColor
        return label
    }()
    
    init(cd2Service: CD2Service) {
        self.cd2Service = cd2Service
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: 280))
        view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindData()
        updateLaunchAtLoginState()
        checkAndPromptAPIToken()
    }
    
    private func setupUI() {
        // --- Header ---
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        
        // --- Separator ---
        let separatorView = NSBox()
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.boxType = .separator
        
        // --- Scroll area for mount points ---
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        
        stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 6
        // 确保这里直接使用 .fill，它是 NSStackView.Alignment 的成员
        stackView.alignment = .centerX // 或者 .fill，取决于你是否想要子视图撑满宽度
        stackView.distribution = .fill // 决定子视图如何分布
        scrollView.documentView = stackView
        
        // --- Footer ---
        footerView = NSView()
        footerView.translatesAutoresizingMaskIntoConstraints = false
        
        let footerSeparator = NSBox()
        footerSeparator.translatesAutoresizingMaskIntoConstraints = false
        footerSeparator.boxType = .separator
        
        // --- Add subviews ---
        view.addSubview(headerView)
        
        headerView.addSubview(statusDot)
        headerView.addSubview(titleLabel)
        headerView.addSubview(statusLabel)
        headerView.addSubview(actionButton)
        headerView.addSubview(buttonRow)
        headerView.addSubview(downloadProgressView)
        headerView.addSubview(downloadLabel)
        
        buttonRow.addArrangedSubview(webUIButton)
        
        view.addSubview(separatorView)
        view.addSubview(mountsHeaderLabel)
        view.addSubview(scrollView)
        view.addSubview(emptyStateLabel)
        view.addSubview(footerSeparator)
        view.addSubview(footerView)
        footerView.addSubview(launchAtLoginCheckbox)
        footerView.addSubview(settingsButton)
        footerView.addSubview(versionLabel)
        
        let hp = horizontalPadding
        let vp = verticalPadding
        
        NSLayoutConstraint.activate([
            // --- Header ---
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Status dot + Title row
            statusDot.topAnchor.constraint(equalTo: headerView.topAnchor, constant: vp + 2),
            statusDot.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: hp),
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),
            
            titleLabel.centerYAnchor.constraint(equalTo: statusDot.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 6),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            statusLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: hp),
            
            // Action button (top-right)
            actionButton.topAnchor.constraint(equalTo: headerView.topAnchor, constant: vp - 2),
            actionButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -hp),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            // Quick action buttons row — centered with equal padding
            buttonRow.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: sectionSpacing),
            buttonRow.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: hp),
            buttonRow.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -hp),
            buttonRow.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -sectionSpacing),
            
            // Download progress (overlays button row area when visible)
            downloadLabel.centerYAnchor.constraint(equalTo: buttonRow.centerYAnchor, constant: -8),
            downloadLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: hp),
            
            downloadProgressView.topAnchor.constraint(equalTo: downloadLabel.bottomAnchor, constant: 4),
            downloadProgressView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: hp),
            downloadProgressView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -hp),
            
            // --- Separator ---
            separatorView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            separatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hp),
            separatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hp),
            
            // 调整标题与分隔线的距离
            mountsHeaderLabel.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 10),
            mountsHeaderLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hp),
            // 调整滚动视图紧贴标题，减少视觉间隙
            scrollView.topAnchor.constraint(equalTo: mountsHeaderLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hp),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hp),
            scrollView.bottomAnchor.constraint(equalTo: footerSeparator.topAnchor, constant: -12),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor, constant: 0),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // --- Footer separator ---
            footerSeparator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hp),
            footerSeparator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hp),
            
            // --- Footer ---
            footerView.topAnchor.constraint(equalTo: footerSeparator.bottomAnchor, constant: 6),
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hp),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hp),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            footerView.heightAnchor.constraint(equalToConstant: 22),
            
            launchAtLoginCheckbox.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            launchAtLoginCheckbox.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            
            settingsButton.leadingAnchor.constraint(equalTo: launchAtLoginCheckbox.trailingAnchor, constant: 8),
            settingsButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 20),
            settingsButton.heightAnchor.constraint(equalToConstant: 20),
            
            versionLabel.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
            versionLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
        ])
    }
    
    private func bindData() {
        cd2Service.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running in
                self?.updateStatus(running: running)
            }
            .store(in: &cancellables)
        
        cd2Service.$isDownloading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] downloading in
                self?.updateDownloading(downloading)
            }
            .store(in: &cancellables)
        
        cd2Service.$downloadProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.downloadProgressView.doubleValue = progress
            }
            .store(in: &cancellables)
        
        cd2Service.$isInstalled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateInstallStatus()
            }
            .store(in: &cancellables)
        
        cd2Service.$mountPoints
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mounts in
                self?.updateMountList(mounts)
            }
            .store(in: &cancellables)
        
        cd2Service.$needsAPITokenConfiguration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] needsConfig in
                if needsConfig {
                    self?.showAPITokenDialog()
                    self?.cd2Service.needsAPITokenConfiguration = false
                }
            }
            .store(in: &cancellables)
        
        cd2Service.$isUpdateAvailable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isUpdateAvailable in
                if isUpdateAvailable {
                    self?.showUpdateAlert()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateStatus(running: Bool) {
        if running {
            statusLabel.stringValue = Localized.str("Running")
            statusLabel.textColor = .systemGreen
            statusDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            actionButton.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: Localized.str("Stop"))
            actionButton.title = " " + Localized.str("Stop")
            actionButton.contentTintColor = .systemRed
            buttonRow.isHidden = false
        } else {
            statusLabel.stringValue = Localized.str("Stopped")
            statusLabel.textColor = .systemRed
            statusDot.layer?.backgroundColor = NSColor.systemRed.cgColor
            actionButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: Localized.str("Start"))
            actionButton.title = " " + Localized.str("Start")
            actionButton.contentTintColor = .systemGreen
            buttonRow.isHidden = true
        }
        updateInstallStatus()
    }
    
    private func updateInstallStatus() {
        if !cd2Service.isInstalled && !cd2Service.isRunning {
            statusLabel.stringValue = "Not installed"
            statusLabel.textColor = .systemOrange
            statusDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
            actionButton.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "Download")
            actionButton.title = " Install"
            actionButton.contentTintColor = .systemBlue
        }
    }
    
    private func updateDownloading(_ downloading: Bool) {
        downloadProgressView.isHidden = !downloading
        downloadLabel.isHidden = !downloading
        actionButton.isEnabled = !downloading
        buttonRow.isHidden = downloading || !cd2Service.isRunning
        
        if downloading {
            downloadLabel.stringValue = "Downloading..."
        }
    }
    
    private func updateMountList(_ mounts: [CD2MountPoint]) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        emptyStateLabel.isHidden = !mounts.isEmpty
        
        for mount in mounts {
            let container = CD2MountRowContainerView(mountPoint: mount)
            container.onRowClick = { [weak self] in
                self?.cd2Service.openMountPoint(mount)
            }
            container.onActionClick = { [weak self] in
                if mount.isMounted {
                    self?.cd2Service.unmount(mountPoint: mount.mountPoint)
                } else {
                    self?.cd2Service.mount(mountPoint: mount.mountPoint)
                }
            }
            stackView.addArrangedSubview(container)
            
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            ])
        }
        
        let totalHeight = calculateTotalHeight(mounts: mounts)
        updateViewHeight(totalHeight)
    }
    
    private func calculateTotalHeight(mounts: [CD2MountPoint]) -> CGFloat {
        let headerHeight: CGFloat = 95  // 包含状态栏和按钮行
        let separatorHeight: CGFloat = 1
        let mountsHeaderHeight: CGFloat = 20 // 缩小标题占用
        let footerHeight: CGFloat = 40
        let padding: CGFloat = 8  // 显著缩小额外内边距
        
        let rowHeight: CGFloat = 48
        let rowSpacing: CGFloat = 6
        let mountsHeight = CGFloat(mounts.count) * rowHeight + CGFloat(max(0, mounts.count - 1)) * rowSpacing
        
        // 如果没有挂载点，给一个较小的占位高度（Empty State）
        let contentHeight = mounts.isEmpty ? 60 : mountsHeight
        
        return headerHeight + separatorHeight + mountsHeaderHeight + contentHeight + footerHeight + padding
    }
    
    private func updateViewHeight(_ height: CGFloat) {
        let maxHeight: CGFloat = 480
        let newHeight = min(height, maxHeight)
        
        let newSize = NSSize(width: popoverWidth, height: newHeight)
        let currentSize = preferredContentSize
        
        if abs(currentSize.height - newHeight) > 2 {
            preferredContentSize = newSize
        }
    }
    
    func resetContentSize() {
        preferredContentSize = .zero
    }
    
    private func updateLaunchAtLoginState() {
        let enabled = cd2Service.getLaunchAtLoginStatus()
        launchAtLoginCheckbox.state = enabled ? .on : .off
    }
    
    @objc private func toggleCD2() {
        if cd2Service.isRunning {
            cd2Service.stopCD2()
        } else {
            cd2Service.startCD2()
        }
    }
    
    @objc private func openWebUI() {
        cd2Service.openWebUI()
    }
    
    @objc private func openCloudFS() {
        cd2Service.openCloudFSRoot()
    }
    
    @objc private func openSettings() {
        showAPITokenDialog()
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let enabled = sender.state == .on
        cd2Service.setLaunchAtLogin(enabled)
    }
    
    private func showAPITokenDialog() {
        if apiTokenPanel != nil {
            apiTokenPanel?.makeKeyAndOrderFront(nil)
            DispatchQueue.main.async {
                self.apiTokenPanel?.makeFirstResponder(self.apiTokenField)
            }
            return
        }
        
        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 180
        
        let window = CD2ConfigWindow(
                contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )

        window.title = Localized.str("API Token Configuration")
        window.level = .floating
        window.center()
        
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
        containerView.wantsLayer = true
        
        let titleLabel = NSTextField(labelWithString: Localized.str("Enter your CloudDrive2 API token to enable mount/unmount functionality."))
        titleLabel.frame = NSRect(x: 20, y: panelHeight - 50, width: panelWidth - 40, height: 20)
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        
        let tokenField = NSTextField(frame: NSRect(x: 20, y: panelHeight - 85, width: panelWidth - 40, height: 24))
        tokenField.placeholderString = Localized.str("Enter API token (e.g., 12313233-b957-4db7-b1d8-1ccfa4957670)")
        tokenField.isEditable = true
        tokenField.isSelectable = true
            // 关键优化：允许使用文本字段的上下文菜单（右键拷贝粘贴）
        tokenField.allowsEditingTextAttributes = true
        tokenField.focusRingType = .default
        tokenField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            // 加载当前 Token
        tokenField.stringValue = cd2Service.apiToken ?? ""
        apiTokenField = tokenField
        
        let helpButton = NSButton(frame: NSRect(x: 20, y: panelHeight - 120, width: 80, height: 24))
        helpButton.title = Localized.str("Help ?")
        helpButton.bezelStyle = .rounded
        helpButton.target = self
        helpButton.action = #selector(showAPIHelp)
        
        let saveButton = NSButton(frame: NSRect(x: panelWidth - 180, y: 20, width: 70, height: 28))
        saveButton.title = Localized.str("Save")
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveAPIToken(_:))
        
        let cancelButton = NSButton(frame: NSRect(x: panelWidth - 100, y: 20, width: 80, height: 28))
        cancelButton.title = Localized.str("Cancel")
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(closeAPITokenPanel(_:))
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(tokenField)
        containerView.addSubview(helpButton)
        containerView.addSubview(saveButton)
        containerView.addSubview(cancelButton)
        
        window.contentView = containerView
        window.delegate = self
        window.isReleasedWhenClosed = false
        
        apiTokenPanel = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(tokenField)
    }
    
    @objc private func showAPIHelp() {
        let helpAlert = NSAlert()
        helpAlert.messageText = Localized.str("How to get API Token")
        helpAlert.informativeText = """
        \(Localized.str("1. Open CloudDrive2 Web UI (click \"Web UI\" button)"))
        \(Localized.str("2. Go to \"System Management\" (系统管理)"))
        \(Localized.str("3. Click \"API Tokens\" (API令牌)"))
        \(Localized.str("4. Click \"Create Token\" (创建令牌)"))
        \(Localized.str("5. Set permissions to include Mount Management (挂载管理)"))
        \(Localized.str("6. Copy the token and paste it here"))
        """
        helpAlert.alertStyle = .informational
        helpAlert.addButton(withTitle: "OK")
        helpAlert.runModal()
    }
    
    @objc private func saveAPIToken(_ sender: NSButton?) {
        guard let tokenField = apiTokenField else {
                closeAPITokenPanel(nil)
                return
            }
            
            // 获取处理后的字符串
            let token = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 修复点：无论是否为空都赋值给 service，这样空字符串才能覆盖旧 Token
            // 如果你的 service 内部有逻辑防止赋空值，请检查 CD2Service 的 apiToken setter
            cd2Service.apiToken = token.isEmpty ? nil : token
            
            closeAPITokenPanel(nil)
    }
    
    @objc private func closeAPITokenPanel(_ sender: Any?) {
        apiTokenPanel?.close()
        apiTokenPanel = nil
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == apiTokenPanel {
            apiTokenPanel = nil
        }
    }
    
    func checkAndPromptAPIToken() {
        if !cd2Service.hasAPIToken {
            DispatchQueue.main.async {
                self.showFirstTimeTokenDialog()
            }
        }
    }
    
    private func showUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = Localized.str("Update Available")
        alert.informativeText = Localized.str("A new version is available. Please download from CloudDrive2 website.")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showFirstTimeTokenDialog() {
        let alert = NSAlert()
        alert.messageText = Localized.str("API Token Required")
        alert.informativeText = Localized.str("Click \"Help\" to see how to create an API token in CloudDrive2 Web UI.")
        alert.alertStyle = .warning
        
        let helpButton = alert.addButton(withTitle: Localized.str("Help"))
        helpButton.action = #selector(showAPIHelp)
        helpButton.target = self
        
        alert.addButton(withTitle: Localized.str("Configure Now"))
        alert.addButton(withTitle: Localized.str("Later"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Help button
            openWebUI()
            showAPITokenDialog()
        } else if response == .alertSecondButtonReturn {
            // Configure Now
            showAPITokenDialog()
        }
        // "Later" does nothing, user can configure later via settings button
    }
}

// MARK: - Mount Row View

class CD2MountRowContainerView: NSView {
    
    var onRowClick: (() -> Void)?
    var onActionClick: (() -> Void)?
    
    private let mountPoint: CD2MountPoint
    private let rowPadding: CGFloat = 12
    private let buttonSize: CGFloat = 28
    
    private lazy var rowView: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        return view
    }()
    
    private lazy var iconView: NSImageView = {
        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        return imageView
    }()
    
    private lazy var nameLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private lazy var pathLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 10)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()
    
    private lazy var statusIndicator: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.cornerRadius = 4
        return view
    }()
    
    private lazy var actionButton: NSButton = {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.isEnabled = true
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.layer?.backgroundColor = NSColor.secondarySystemFill.cgColor
        button.target = self
        button.action = #selector(actionButtonClicked)
        return button
    }()
    
    init(mountPoint: CD2MountPoint) {
        self.mountPoint = mountPoint
        super.init(frame: .zero)
        setupUI()
        updateUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(rowView)
        rowView.addSubview(iconView)
        rowView.addSubview(nameLabel)
        rowView.addSubview(pathLabel)
        rowView.addSubview(statusIndicator)
        addSubview(actionButton)
        
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 48),
            
            rowView.topAnchor.constraint(equalTo: topAnchor),
            rowView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowView.bottomAnchor.constraint(equalTo: bottomAnchor),
            rowView.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -8),
            
            iconView.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: rowPadding),
            iconView.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            nameLabel.topAnchor.constraint(equalTo: rowView.topAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: statusIndicator.leadingAnchor, constant: -10),
            
            pathLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            pathLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            pathLabel.trailingAnchor.constraint(equalTo: statusIndicator.leadingAnchor, constant: -10),
            
            statusIndicator.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -rowPadding),
            statusIndicator.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 8),
            statusIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            actionButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: buttonSize),
            actionButton.heightAnchor.constraint(equalToConstant: buttonSize),
        ])
        
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleRowClick(_:)))
        rowView.addGestureRecognizer(clickGesture)
    }
    
    @objc private func handleRowClick(_ gesture: NSClickGestureRecognizer) {
        onRowClick?()
    }
    
    @objc private func actionButtonClicked() {
        onActionClick?()
    }
    
    private func updateUI() {
        nameLabel.stringValue = mountPoint.id
        pathLabel.stringValue = mountPoint.mountPoint
        
        if mountPoint.isMounted {
            iconView.image = NSImage(systemSymbolName: "externaldrive.fill.badge.checkmark", accessibilityDescription: "Mounted")
            iconView.contentTintColor = .systemBlue
            statusIndicator.layer?.backgroundColor = NSColor.systemGreen.cgColor
            actionButton.image = NSImage(systemSymbolName: "eject.fill", accessibilityDescription: "Unmount")
            actionButton.contentTintColor = .labelColor
            actionButton.layer?.backgroundColor = NSColor.secondarySystemFill.cgColor
        } else {
            iconView.image = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "Unmounted")
            iconView.contentTintColor = .tertiaryLabelColor
            statusIndicator.layer?.backgroundColor = NSColor.separatorColor.cgColor
            actionButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Mount")
            actionButton.contentTintColor = .labelColor
            actionButton.layer?.backgroundColor = NSColor.secondarySystemFill.cgColor
        }
    }
}
// 专门用于处理快捷键的窗口子类
class CD2ConfigWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "x": return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
            case "c": return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            case "v": return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
            case "a": return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
