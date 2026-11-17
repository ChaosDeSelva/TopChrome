import AppKit

struct ChromeNativeWindow {
    let number: CGWindowID
    let process: pid_t
}

struct ChromeDesktopAccess {
    var currentDesktop: () -> UInt64?
    var ownsWindow: (ChromeNativeWindow) -> Bool
    var containsWindow: (ChromeNativeWindow, UInt64) -> Bool
    var assign: (pid_t, UInt64) -> Bool
}

final class ChromeDesktopFollower {
    enum Outcome: Equatable { case ready, unavailable, rejected, cancelled }
    private let access: ChromeDesktopAccess?
    private let later: (@escaping () -> Void) -> Void
    private var generation = 0

    init(access: ChromeDesktopAccess? = ChromeSpaces.access,
         later: @escaping (@escaping () -> Void) -> Void = { work in
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.025, execute: work)
         }) {
        self.access = access
        self.later = later
    }

    var isAvailable: Bool { access != nil }
    func cancel() { generation += 1 }

    func bring(_ window: ChromeNativeWindow, completion: @escaping (Outcome) -> Void) {
        cancel()
        let token = generation
        guard let access, let destination = access.currentDesktop() else { completion(.unavailable); return }
        guard access.ownsWindow(window) else { completion(.rejected); return }
        if access.containsWindow(window, destination) { completion(.ready); return }
        guard access.assign(window.process, destination) else { completion(.rejected); return }
        verify(window, destination: destination, token: token, attempts: 24, completion: completion)
    }

    private func verify(_ window: ChromeNativeWindow, destination: UInt64, token: Int,
                        attempts: Int, completion: @escaping (Outcome) -> Void) {
        guard token == generation else { return }
        guard let access, access.currentDesktop() == destination else { completion(.cancelled); return }
        guard access.ownsWindow(window) else { completion(.rejected); return }
        if access.containsWindow(window, destination) { completion(.ready); return }
        guard attempts > 0 else { completion(.rejected); return }
        // Space assignment settles asynchronously; a successful call alone does not prove the drawer moved.
        later { [weak self] in
            self?.verify(window, destination: destination, token: token, attempts: attempts - 1, completion: completion)
        }
    }
}

private enum ChromeSpaces {
    typealias Connection = @convention(c) () -> Int32
    typealias ActiveSpace = @convention(c) (Int32) -> UInt64
    typealias Displays = @convention(c) (Int32) -> Unmanaged<CFArray>?
    typealias Membership = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    typealias Assignment = @convention(c) (Int32, pid_t, UInt64) -> Int32
    private static let library = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static func symbol<T>(_ name: String, _ type: T.Type) -> T? {
        guard let library, let address = dlsym(library, name) else { return nil }
        return unsafeBitCast(address, to: type)
    }

    static let access: ChromeDesktopAccess? = {
        guard let connect = symbol("SLSMainConnectionID", Connection.self),
              let active = symbol("SLSGetActiveSpace", ActiveSpace.self),
              let displays = symbol("SLSCopyManagedDisplaySpaces", Displays.self),
              let membership = symbol("SLSCopySpacesForWindows", Membership.self),
              let assign = symbol("SLSProcessAssignToSpace", Assignment.self) else { return nil }
        let connection = connect()
        return ChromeDesktopAccess(currentDesktop: {
            let current = active(connection)
            guard current != 0,
                  let screens = displays(connection)?.takeRetainedValue() as? [[String: Any]] else { return nil }
            for screen in screens {
                for space in screen["Spaces"] as? [[String: Any]] ?? [] {
                    let number = (space["ManagedSpaceID"] ?? space["id64"]) as? NSNumber
                    if number?.uint64Value == current, (space["type"] as? NSNumber)?.intValue == 0 { return current }
                }
            }
            return nil
        }, ownsWindow: { window in
            guard NSRunningApplication(processIdentifier: window.process)?.bundleIdentifier == "com.google.Chrome" else { return false }
            let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
            return windows.contains {
                ($0[kCGWindowNumber as String] as? UInt32) == window.number &&
                ($0[kCGWindowOwnerPID as String] as? Int32) == window.process
            }
        }, containsWindow: { window, desktop in
            let numbers = [NSNumber(value: window.number)] as CFArray
            let spaces = membership(connection, 7, numbers)?.takeRetainedValue() as? [NSNumber] ?? []
            return spaces.contains { $0.uint64Value == desktop }
        }, assign: { process, desktop in
            guard NSRunningApplication(processIdentifier: process)?.bundleIdentifier == "com.google.Chrome" else { return false }
            return assign(connection, process, desktop) == 0
        })
    }()
}
