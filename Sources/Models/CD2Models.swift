import Foundation

struct CD2MountPoint: Identifiable, Codable {
    let id: String
    let mountPoint: String
    let sourceDir: String
    let localMount: Bool
    let autoMount: Bool
    let isMounted: Bool
    
    var displayName: String {
        let components = mountPoint.components(separatedBy: "/")
        return components.last ?? mountPoint
    }
}

struct CD2SystemInfo: Codable {
    let isLogin: Bool
    let userName: String
    let systemReady: Bool
    let systemMessage: String?
    let hasError: Bool
}

struct CD2MountPointsResponse: Codable {
    let mountPoints: [CD2MountPoint]
}
