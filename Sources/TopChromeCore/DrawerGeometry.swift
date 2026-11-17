import Foundation
import CoreGraphics

public enum DrawerGeometry {
    public static let defaultFraction = 0.5
    public static let toolbarHeight = 44.0
    public static let gripHeight = 12.0

    public static func savedFraction(_ value: Double) -> Double {
        value.isFinite ? min(0.95, max(0.3, value)) : defaultFraction
    }

    public static func frame(in visible: CGRect, fraction: Double, expanded: Bool) -> CGRect {
        let height = min(visible.height, expanded ? visible.height : max(360, visible.height * savedFraction(fraction))).rounded()
        return CGRect(x: visible.minX, y: visible.maxY - height, width: visible.width, height: height)
    }

    public static func browser(in drawer: CGRect) -> CGRect {
        CGRect(x: drawer.minX, y: drawer.minY + gripHeight, width: drawer.width,
               height: max(1, drawer.height - toolbarHeight - gripHeight))
    }

    public static func scriptBounds(for frame: CGRect, primaryHeight: Double) -> [Int] {
        [Int(frame.minX.rounded()), Int((primaryHeight - frame.maxY).rounded()),
         Int(frame.maxX.rounded()), Int((primaryHeight - frame.minY).rounded())]
    }

    public static func cocoaFrame(from bounds: [Int], primaryHeight: Double) -> CGRect? {
        guard bounds.count == 4, bounds[2] > bounds[0], bounds[3] > bounds[1] else { return nil }
        return CGRect(x: Double(bounds[0]), y: primaryHeight - Double(bounds[3]),
                      width: Double(bounds[2] - bounds[0]), height: Double(bounds[3] - bounds[1]))
    }

}
