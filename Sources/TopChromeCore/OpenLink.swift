import Foundation

public enum OpenLink {
    public enum InvalidLink: LocalizedError {
        case invalid
        public var errorDescription: String? { "TopChrome can only open a valid http or https link without embedded credentials." }
    }

    public static func address(from link: URL) throws -> String {
        guard let envelope = URLComponents(url: link, resolvingAgainstBaseURL: false),
              envelope.scheme == "topchrome", envelope.host == "open",
              envelope.user == nil, envelope.password == nil, envelope.port == nil,
              envelope.path.isEmpty, envelope.fragment == nil,
              let items = envelope.queryItems, items.count == 1, items[0].name == "url",
              let address = items[0].value, address.utf8.count <= 16_384,
              !address.contains("\\"), let decoded = address.removingPercentEncoding,
              !decoded.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              let destination = URLComponents(string: address),
              let scheme = destination.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = destination.host, !host.isEmpty, !host.contains(where: { $0.isWhitespace }),
              destination.user == nil, destination.password == nil,
              destination.port.map({ (1...65535).contains($0) }) ?? true,
              let url = destination.url else { throw InvalidLink.invalid }
        return url.absoluteString
    }
}
