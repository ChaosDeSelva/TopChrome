import AppKit

final class ChromeVisibility {
    private var browserID: Int?
    private var nativeID: CGWindowID?
    private var processID: pid_t?

    func remember(_ state: ChromeWindowState?) {
        guard let state else { browserID = nil; nativeID = nil; processID = nil; return }
        let processes = Set(NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").map(\.processIdentifier))
        let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        if browserID == state.id, let nativeID, let processID, processes.contains(processID),
           windows.contains(where: { ($0[kCGWindowNumber as String] as? UInt32) == nativeID && ($0[kCGWindowOwnerPID as String] as? Int32) == processID }) { return }
        browserID = state.id
        nativeID = nil
        processID = nil
        guard state.bounds.count == 4 else { return }
        let expected = CGRect(x: state.bounds[0], y: state.bounds[1], width: state.bounds[2] - state.bounds[0], height: state.bounds[3] - state.bounds[1])
        let matches = windows.filter { window in
            guard let pid = window[kCGWindowOwnerPID as String] as? Int32, processes.contains(pid),
                  window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let rectangle = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
            return abs(rectangle.minX - expected.minX) <= 1 && abs(rectangle.minY - expected.minY) <= 1 &&
                abs(rectangle.width - expected.width) <= 1 && abs(rectangle.height - expected.height) <= 1
        }
        guard matches.count == 1 else { return }
        nativeID = matches[0][kCGWindowNumber as String] as? UInt32
        processID = matches[0][kCGWindowOwnerPID as String] as? Int32
    }

    var isOnCurrentDesktop: Bool {
        guard let nativeID, let processID else { return false }
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { ($0[kCGWindowNumber as String] as? UInt32) == nativeID && ($0[kCGWindowOwnerPID as String] as? Int32) == processID }
    }
}
