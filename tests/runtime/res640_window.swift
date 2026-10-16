// Resize only the owned game's uniquely named window through Accessibility.
// Usage: res640-window <pid> <client-width> <client-height> <current-client-height>
import ApplicationServices
import CoreGraphics
import Foundation
guard CommandLine.arguments.count == 5 else { exit(2) }
let pid = pid_t(CommandLine.arguments[1])!
let width = Double(CommandLine.arguments[2])!
let height = Double(CommandLine.arguments[3])!
let app = AXUIElementCreateApplication(pid)
var value: CFTypeRef?
guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
      let windows = value as? [AXUIElement] else {
    fputs("Cannot inspect owned game's Accessibility windows\n", stderr); exit(2)
}
let matches = windows.filter { window in
    var title: CFTypeRef?
    return AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title) == .success && (title as? String) == "The Last Stop"
}
guard matches.count == 1 else { fputs("Expected unique owned game window\n", stderr); exit(3) }
// CG height includes title bar. Raylib's requested size is the client area.
let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
guard let cg = all.first(where: { ($0[kCGWindowOwnerPID as String] as? Int) == Int(pid) && ($0[kCGWindowName as String] as? String) == "The Last Stop" }),
      let bounds = cg[kCGWindowBounds as String] as? [String: Double] else { exit(4) }
// Use current content height passed by the caller (initially 720) to derive chrome.
let chrome = bounds["Height"]! - Double(CommandLine.arguments[4])!
var size = CGSize(width: width, height: height + chrome)
let axSize = AXValueCreate(.cgSize, &size)!
let result = AXUIElementSetAttributeValue(matches[0], kAXSizeAttribute as CFString, axSize)
guard result == .success else { fputs("Resize failed: \(result.rawValue)\n", stderr); exit(5) }
print("resized owned PID \(pid) client \(width)x\(height), chrome \(chrome)")
