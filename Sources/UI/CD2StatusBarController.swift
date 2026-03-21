import AppKit
import Combine

class CD2StatusBarController {
    
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var cd2Service: CD2Service
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    
    init(cd2Service: CD2Service) {
        self.cd2Service = cd2Service
        
        // Use variable length so the icon has proper space
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        
        setupStatusItem()
        setupPopover()
        observeCD2Changes()
        
        print("CD2StatusBarController initialized")
    }
    
    private func setupStatusItem() {
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            // Set initial icon
            updateStatusItemIcon()
        }
    }
    
    private func setupPopover() {
        let popoverVC = CD2PopoverViewController(cd2Service: cd2Service)
        popover.contentViewController = popoverVC
        popover.behavior = .transient
        popover.animates = true
    }
    
    private func observeCD2Changes() {
        // Subscribe to both isRunning AND mountPoints changes
        cd2Service.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemIcon()
            }
            .store(in: &cancellables)
        
        cd2Service.$mountPoints
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemIcon()
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusItemIcon() {
        guard let button = statusItem.button else { return }
        
        let symbolName: String
        let accessibilityLabel: String
        
        if cd2Service.isRunning {
            let mountedCount = cd2Service.mountPoints.filter { $0.isMounted }.count
            if mountedCount > 0 {
                symbolName = "cloud.fill"
                accessibilityLabel = "CloudDrive2 - \(mountedCount) " + Localized.str("Mounted")
            } else {
                symbolName = "cloud"
                accessibilityLabel = "CloudDrive2 - " + Localized.str("No mounts")
            }
        } else {
            symbolName = "exclamationmark.icloud"
            accessibilityLabel = "CloudDrive2 - " + Localized.str("Stopped")
        }
        
        // Create template image from SF Symbol — works on macOS 11+
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            // Fallback: use unicode text if SF Symbols unavailable
            button.image = nil
            if cd2Service.isRunning {
                let mountedCount = cd2Service.mountPoints.filter { $0.isMounted }.count
                button.title = mountedCount > 0 ? "☁️✓" : "☁️"
            } else {
                button.title = "☁️✕"
            }
        }
    }
    
    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            if popover.isShown {
                closePopover()
            } else {
                showPopover()
            }
        }
    }
    
    private func showPopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            }
            
            if let contentVC = popover.contentViewController as? CD2PopoverViewController {
                contentVC.resetContentSize()
            }
            
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            setupEventMonitor()
        }
    }
    
    private func closePopover() {
        popover.performClose(nil)
        removeEventMonitor()
    }
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }
    
    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        if cd2Service.isRunning {
            menu.addItem(NSMenuItem(title: Localized.str("Web UI"), action: #selector(openWebUI), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: Localized.str("Stop"), action: #selector(stopCD2), keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: Localized.str("Start"), action: #selector(startCD2), keyEquivalent: ""))
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: Localized.str("Quit CD2Launcher"), action: #selector(quitApp), keyEquivalent: "q"))
        
        for item in menu.items {
            item.target = self
        }
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc private func startCD2() {
        cd2Service.startCD2()
    }
    
    @objc private func stopCD2() {
        cd2Service.stopCD2()
    }
    
    @objc private func openWebUI() {
        cd2Service.openWebUI()
    }
    
    @objc private func quitApp() {
        cd2Service.stopCD2()
        NSApp.terminate(nil)
    }
}
