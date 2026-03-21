import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarController: CD2StatusBarController?
    private var cd2Service: CD2Service?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        cd2Service = CD2Service()
        statusBarController = CD2StatusBarController(cd2Service: cd2Service!)
        
        cd2Service?.startMonitoring()
        cd2Service?.restoreStateOnLaunch()
        cd2Service?.checkForUpdates()
        
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        cd2Service?.saveStateForQuit()
        cd2Service?.stopMonitoring()
    }
}
