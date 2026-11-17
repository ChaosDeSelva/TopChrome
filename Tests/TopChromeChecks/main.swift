import Foundation
import TopChromeCore

func check(_ condition: Bool, _ name: String) {
    guard condition else { fputs("FAIL: \(name)\n", stderr); exit(1) }
    print("PASS: \(name)")
}

let visible = CGRect(x: 0, y: 30, width: 1512, height: 920)
let half = DrawerGeometry.frame(in: visible, fraction: 0.5, expanded: false)
check(half.height == 460 && half.maxY == visible.maxY && half.width == visible.width, "full width, top anchored, 50% default")
let full = DrawerGeometry.frame(in: visible, fraction: 0.63, expanded: true)
check(full == visible, "full height uses the available screen")
let saved = DrawerGeometry.frame(in: visible, fraction: 0.63, expanded: false)
check(saved.height == 580, "saved height survives expansion")
let upperScreen = CGRect(x: -1920, y: 980, width: 1920, height: 1080)
let upperDrawer = DrawerGeometry.frame(in: upperScreen, fraction: 0.5, expanded: false)
let browser = DrawerGeometry.browser(in: upperDrawer)
let script = DrawerGeometry.scriptBounds(for: browser, primaryHeight: 982)
check(script[0] == -1920 && script[1] < 0, "AppleScript coordinates support displays above and left")
check(DrawerGeometry.cocoaFrame(from: script, primaryHeight: 982) == browser, "screen coordinates round trip")
check(browser.height + DrawerGeometry.toolbarHeight + DrawerGeometry.gripHeight == upperDrawer.height, "controls fit inside the requested drawer height")
check(DrawerGeometry.savedFraction(.nan) == 0.5 && DrawerGeometry.savedFraction(3) == 0.95, "invalid stored heights are bounded")
check(DrawerGeometry.cocoaFrame(from: [0, 0, 0, 1], primaryHeight: 982) == nil, "invalid Chrome rectangles are rejected")
check(ChromeScript.quoted("a\"b\\c\nd") == "\"a\\\"b\\\\c d\"", "window identifiers are escaped as AppleScript strings")
for action in [ChromeAction.prepare(bounds: [0, 40, 1512, 480]), .show(bounds: [0, 40, 1512, 480]), .resize(bounds: [0, 40, 1512, 900]), .hide, .newTab(bounds: [0, 44, 1000, 500]), .inspect, .release(bounds: [0, 44, 1000, 500]), .close(bounds: [0, 44, 1000, 500])] {
    let source = ChromeScript.source(owner: "TopChrome · test", action: action)
    check(source.contains("whose given name is \"TopChrome · test\"") && !source.contains("quit") && !source.contains("close front window"), "actions remain scoped to the owned window")
}
check(!ChromeScript.source(owner: "test", action: .inspect).contains("make new window"), "polling cannot create windows")
check(!ChromeScript.source(owner: "test", action: .hide).contains("set minimized of drawer to true"), "hiding never creates a minimized Dock tile")
let prepared = ChromeScript.source(owner: "test", action: .prepare(bounds: [0, 40, 1512, 480]))
check(prepared.contains("set visible of drawer to true") && !prepared.contains("activate") && !prepared.contains("set index"), "restoring an existing drawer does not activate its old desktop")
print("PASS: all core checks")

func link(_ address: String) -> URL {
    var parts = URLComponents()
    parts.scheme = "topchrome"
    parts.host = "open"
    parts.queryItems = [URLQueryItem(name: "url", value: address)]
    return parts.url!
}
let nestedAddress = "https://example.com/a%2Fb?q=a%20b&next=https%3A%2F%2Fother.example%2F#section"
check((try? OpenLink.address(from: link(nestedAddress))) == nestedAddress, "handoff preserves URL query, escapes, and fragment")
for address in ["javascript:alert(1)", "file:///tmp/private", "chrome://settings", "https://user:secret@example.com/", "https://example.com/%0Aattack", "https://", "https://example.com:99999/"] {
    check((try? OpenLink.address(from: link(address))) == nil, "unsafe handoff destination rejected")
}
for value in ["topchrome://open", "topchrome://other?url=https://example.com", "topchrome://open?url=https://example.com&url=https://other.example", "topchrome://open?url=https://example.com&extra=1", "topchrome://open?url=https://example.com#fragment"] {
    check((try? OpenLink.address(from: URL(string: value)!)) == nil, "malformed handoff envelope rejected")
}
let opening = ChromeScript.source(owner: "TopChrome · test", action: .openURLs([nestedAddress, "https://example.com/second"], bounds: [0, 44, 1000, 500]))
check(opening.contains("whose given name is \"TopChrome · test\"") && opening.contains("make new tab at end of tabs of drawer"), "incoming links append only to the owned drawer")
check(opening.contains("if createdDrawer then") && !opening.contains("URL of active tab of front window"), "only a newly created drawer has its initial blank page replaced")
print("PASS: all link handoff checks")

let reply = try ChromeReply.parse("{123, false, {-1920, 44, 0, 600}, 3, 123, true}\n")
check(reply?.id == 123 && reply?.bounds == [-1920, 44, 0, 600] && reply?.tabCount == 3 && reply?.isFront == true, "Chrome reply preserves window identity, negative coordinates, and tabs")
check(try ChromeReply.parse("{}") == nil, "missing drawer is distinct from a malformed response")
for malformed in ["", "123", "{123, true}", "{123, false, {0, 0, 0}, 3, 123, true}"] {
    do { _ = try ChromeReply.parse(malformed); check(false, "malformed Chrome reply rejected") }
    catch { check(true, "malformed Chrome reply rejected") }
}
let creation = ChromeScript.source(owner: "test", action: .show(bounds: [0, 44, 1000, 500]))
check(creation.contains("on error errorMessage number errorNumber") && creation.contains("close drawer\n        error errorMessage"), "failed window naming rolls back only the newly created drawer")

check(try ChromeReply.parse(#"{"123", false, {0, 44, 1000, 600}, 2, "123", true}"#)?.tabCount == 2, "Chrome string window IDs are accepted")
