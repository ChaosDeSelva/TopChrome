#if DEBUG
import AppKit
import Carbon
import TopChromeCore

enum AppChecks {
    static func run() -> Int32 {
        do {
            let suite = "local.topchrome.check.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let prefs = Preferences(defaults: defaults)
            try check(prefs.heightFraction == 0.5, "new installations start at 50%")
            try check(!prefs.followAllChromeWindows, "moving regular Chrome windows requires an explicit choice")
            prefs.followAllChromeWindows = true
            prefs.heightFraction = 0.75
            let binding = KeyBinding(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey), keyLabel: "Space")
            prefs.keyBinding = binding
            prefs.hidden = true
            prefs.lastVisibleBounds = [0, 44, 1512, 500]
            let reloaded = Preferences(defaults: defaults)
            try check(reloaded.heightFraction == 0.75 && reloaded.keyBinding == binding, "height and shortcut survive relaunch")
            try check(prefs.ownerName == reloaded.ownerName, "owned window identity survives relaunch")
            try check(reloaded.followAllChromeWindows, "desktop following choice survives relaunch")
            try check(reloaded.hidden && reloaded.lastVisibleBounds == [0, 44, 1512, 500], "hidden window recovery survives a controller relaunch")
            try check(!KeyBinding(keyCode: 0, modifiers: 0, keyLabel: "A").isValid, "ordinary typing cannot become a global shortcut")
            let first = GlobalShortcut(), second = GlobalShortcut()
            let modifiers = UInt32(cmdKey | optionKey | controlKey | shiftKey)
            let one = KeyBinding(keyCode: UInt32(kVK_F18), modifiers: modifiers, keyLabel: "F18")
            let two = KeyBinding(keyCode: UInt32(kVK_F19), modifiers: modifiers, keyLabel: "F19")
            try check(first.register(one) && second.register(two), "global shortcuts register")
            try check(!first.register(two) && first.binding == one, "shortcut conflict keeps the previous binding")
            for action in [ChromeAction.prepare(bounds: [0, 44, 1000, 500]), .show(bounds: [0, 44, 1000, 500]), .resize(bounds: [0, 44, 1000, 900]), .hide, .newTab(bounds: [0, 44, 1000, 500]), .inspect, .release(bounds: [0, 44, 1000, 500]), .close(bounds: [0, 44, 1000, 500])] {
                var error: NSDictionary?
                let script = NSAppleScript(source: ChromeScript.source(owner: "TopChrome · compile check", action: action))!
                try check(script.compileAndReturnError(&error), "Chrome command compiles: \(String(describing: error))")
            }
            var linkError: NSDictionary?
            let linkScript = NSAppleScript(source: ChromeScript.source(owner: "TopChrome · compile check", action: .openURLs(["https://example.com/?q=%22hello%22&x=1#part"], bounds: [0, 44, 1000, 500])))!
            try check(linkScript.compileAndReturnError(&linkError), "link-opening command compiles: \(String(describing: linkError))")
            try checkDesktopFollowing()
            print("PASS: all app checks; no Chrome commands executed")
            return 0
        } catch { print("FAIL: \(error.localizedDescription)"); return 1 }
    }
    private static func check(_ condition: Bool, _ name: String) throws {
        guard condition else { throw NSError(domain: "TopChrome.Check", code: 1, userInfo: [NSLocalizedDescriptionKey: name]) }
        print("PASS: \(name)")
    }

    private static func checkDesktopFollowing() throws {
        var desktop: UInt64? = 2
        var belongsToChrome = true
        var landed = false
        var assignments = 0
        var pending: [() -> Void] = []
        var results: [ChromeDesktopFollower.Outcome] = []
        let access = ChromeDesktopAccess(currentDesktop: { desktop }, ownsWindow: { _ in belongsToChrome },
            containsWindow: { _, _ in landed }, assign: { _, _ in assignments += 1; return true })
        let follower = ChromeDesktopFollower(access: access, later: { pending.append($0) })
        let window = ChromeNativeWindow(number: 100, process: 200)
        follower.bring(window) { results.append($0) }
        try check(results.isEmpty && assignments == 1, "move success waits for actual drawer membership")
        landed = true
        pending.removeFirst()()
        try check(results == [.ready], "delayed window-server confirmation permits activation")

        results = []; landed = false
        follower.bring(window) { results.append($0) }
        follower.cancel()
        pending.removeFirst()()
        try check(results.isEmpty, "hide or replacement cancels a stale desktop completion")

        follower.bring(window) { results.append($0) }
        desktop = 3
        pending.removeFirst()()
        try check(results == [.cancelled], "a second swipe cannot activate Chrome on the previous desktop")

        results = []
        follower.bring(window) { results.append($0) }
        var steps = 0
        while !pending.isEmpty && steps < 30 { steps += 1; pending.removeFirst()() }
        try check(results == [.rejected] && pending.isEmpty, "a no-op native move times out without activating Chrome")

        results = []; belongsToChrome = false
        let previousAssignments = assignments
        follower.bring(window) { results.append($0) }
        try check(results == [.rejected] && assignments == previousAssignments, "stale or foreign window ownership prevents process movement")

        results = []; belongsToChrome = true; desktop = nil
        follower.bring(window) { results.append($0) }
        try check(results == [.unavailable] && assignments == previousAssignments, "full-screen or unknown desktops prevent process movement")
    }
}
#endif
