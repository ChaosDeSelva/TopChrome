import AppKit
import TopChromeCore

typealias ChromeWindowState = ChromeReply

struct ChromeFailure: LocalizedError {
    let code: Int
    let detail: String
    var errorDescription: String? {
        if code == -1743 { return "Allow TopChrome to control Google Chrome in System Settings → Privacy & Security → Automation, then try again." }
        if code == -1712 { return "Chrome took too long to respond. Resolve any Chrome or macOS permission dialog, then try again." }
        return detail
    }
}

final class ChromeController {
    private let queue = DispatchQueue(label: "local.topchrome.apple-events", qos: .userInitiated)
    private let owner: String
    init(owner: String) { self.owner = owner }

    var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty }

    func perform(_ action: ChromeAction, completion: @escaping (Result<ChromeWindowState?, Error>) -> Void) {
        let source = ChromeScript.source(owner: owner, action: action)
        queue.async {
            let result: Result<ChromeWindowState?, Error>
            let process = Process()
            let input = Pipe(), output = Pipe(), errors = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-s", "s", "-"]
            process.standardInput = input
            process.standardOutput = output
            process.standardError = errors
            do {
                try process.run()
                input.fileHandleForWriting.write(Data(source.utf8))
                try input.fileHandleForWriting.close()
                let response = output.fileHandleForReading.readDataToEndOfFile()
                let errorData = errors.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    result = .success(try ChromeReply.parse(String(decoding: response, as: UTF8.self)))
                } else {
                    let detail = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    let code = detail.contains("(-1743)") ? -1743 : (detail.contains("(-1712)") ? -1712 : -1)
                    result = .failure(ChromeFailure(code: code, detail: detail.isEmpty ? "Chrome could not complete this action." : detail))
                }
            } catch { result = .failure(error) }
            DispatchQueue.main.async { completion(result) }
        }
    }
}
