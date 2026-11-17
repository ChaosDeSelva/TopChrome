import AppKit

let destination = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let background = NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 214, yRadius: 214)
NSColor(srgbRed: 0.055, green: 0.08, blue: 0.14, alpha: 1).setFill()
background.fill()
let screen = NSRect(x: 186, y: 226, width: 652, height: 584)
let screenPath = NSBezierPath(roundedRect: screen, xRadius: 46, yRadius: 46)
NSColor(srgbRed: 0.48, green: 0.71, blue: 1, alpha: 1).setStroke()
screenPath.lineWidth = 27; screenPath.stroke()
NSColor(srgbRed: 0.48, green: 0.71, blue: 1, alpha: 0.22).setFill()
NSBezierPath(roundedRect: NSRect(x: 201, y: 567, width: 622, height: 228), xRadius: 30, yRadius: 30).fill()
let divider = NSBezierPath()
divider.move(to: NSPoint(x: 198, y: 567)); divider.line(to: NSPoint(x: 826, y: 567))
divider.lineWidth = 22; divider.stroke()
let globe = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)!
let configuration = NSImage.SymbolConfiguration(pointSize: 250, weight: .light)
let symbol = globe.withSymbolConfiguration(configuration)!
NSColor(srgbRed: 0.71, green: 0.85, blue: 1, alpha: 1).set()
symbol.draw(in: NSRect(x: 392, y: 579, width: 240, height: 210))
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 432, y: 418)); arrow.line(to: NSPoint(x: 512, y: 338)); arrow.line(to: NSPoint(x: 592, y: 418))
arrow.lineWidth = 30; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round; arrow.stroke()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
