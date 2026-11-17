import Foundation

public struct ChromeReply {
    public let id: Int
    public let minimized: Bool
    public let bounds: [Int]
    public let tabCount: Int
    public let isFront: Bool
    public let visible: Bool

    public static func parse(_ output: String) throws -> ChromeReply? {
        let value = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if value == "{}" { return nil }
        let pattern = #"^\{\s*"?(\d+)"?,\s*(true|false),\s*\{\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+)\s*\},\s*(\d+),\s*"?(\d+)"?,\s*(true|false)\s*\}$"#
        let expression = try NSRegularExpression(pattern: pattern)
        guard let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else {
            throw NSError(domain: "TopChrome.Reply", code: 1, userInfo: [NSLocalizedDescriptionKey: "Chrome returned an unexpected window description."])
        }
        let parts = (1...9).map { (value as NSString).substring(with: match.range(at: $0)) }
        guard let id = Int(parts[0]), let tabCount = Int(parts[6]), let front = Int(parts[7]),
              parts[2...5].allSatisfy({ Int($0) != nil }) else {
            throw NSError(domain: "TopChrome.Reply", code: 2, userInfo: [NSLocalizedDescriptionKey: "Chrome returned invalid window numbers."])
        }
        return ChromeReply(id: id, minimized: parts[1] == "true", bounds: parts[2...5].compactMap(Int.init),
                           tabCount: tabCount, isFront: id == front, visible: parts[8] == "true")
    }
}
