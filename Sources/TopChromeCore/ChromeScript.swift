import Foundation

public enum ChromeAction {
    case show(bounds: [Int])
    case openURLs([String], bounds: [Int])
    case resize(bounds: [Int])
    case hide
    case release(bounds: [Int])
    case close(bounds: [Int])
    case newTab(bounds: [Int])
    case inspect
}

public enum ChromeScript {
    public static func quoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ") + "\""
    }

    public static func source(owner: String, action: ChromeAction) -> String {
        var body = """
        set matches to every window whose given name is \(quoted(owner))
        if (count of matches) > 1 then error "More than one drawer window has this name." number -2700
        """
        let createsDrawer: Bool
        switch action {
        case .show, .openURLs, .newTab: createsDrawer = true
        default: createsDrawer = false
        }
        if createsDrawer {
            body += """

            set createdDrawer to false
            if (count of matches) is 0 then
                set drawer to make new window with properties {mode:"normal"}
                try
                    set given name of drawer to \(quoted(owner))
                on error errorMessage number errorNumber
                    close drawer
                    error errorMessage number errorNumber
                end try
                set createdDrawer to true
            else
                set drawer to item 1 of matches
            end if
            """
        } else {
            body += "\nif (count of matches) is 0 then return {}\nset drawer to item 1 of matches\n"
        }
        switch action {
        case .openURLs(let urls, let bounds):
            precondition(bounds.count == 4 && !urls.isEmpty)
            body += "\nset addresses to {\(urls.map(quoted).joined(separator: ", "))}\n"
            body += """
            repeat with address in addresses
                if createdDrawer then
                    set URL of active tab of drawer to (address as text)
                    set createdDrawer to false
                else
                    make new tab at end of tabs of drawer with properties {URL:(address as text)}
                end if
            end repeat
            set active tab index of drawer to count of tabs of drawer
            set bounds of drawer to {\(bounds.map(String.init).joined(separator: ", "))}
            set minimized of drawer to false
            set visible of drawer to true
            set index of drawer to 1
            activate

            """
        case .show(let bounds), .resize(let bounds):
            precondition(bounds.count == 4)
            body += "\nset bounds of drawer to {\(bounds.map(String.init).joined(separator: ", "))}\n"
            if case .show = action {
                body += "set minimized of drawer to false\nset visible of drawer to true\nset index of drawer to 1\nactivate\n"
            }
        case .hide:
            body += "\nset visible of drawer to false\n"
        case .newTab(let bounds):
            body += "\nif not createdDrawer then make new tab at end of tabs of drawer\nset active tab index of drawer to count of tabs of drawer\n"
            body += "set bounds of drawer to {\(bounds.map(String.init).joined(separator: ", "))}\nset minimized of drawer to false\nset visible of drawer to true\nset index of drawer to 1\nactivate\n"
        case .release(let bounds):
            body += "\nset bounds of drawer to {\(bounds.map(String.init).joined(separator: ", "))}\nset minimized of drawer to false\nset visible of drawer to true\nreturn {}\n"
        case .close(let bounds):
            body += "\nset bounds of drawer to {\(bounds.map(String.init).joined(separator: ", "))}\nset minimized of drawer to false\nset visible of drawer to true\nclose drawer\nreturn {}\n"
        case .inspect: break
        }
        body += "\nreturn {id of drawer, minimized of drawer, bounds of drawer, count of tabs of drawer, id of front window, visible of drawer}\n"
        return "with timeout of 12 seconds\ntell application id \"com.google.Chrome\"\n" + body + "\nend tell\nend timeout"
    }
}
