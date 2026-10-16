// Native gate helper: list only the launched PID's named, visible game window.
import CoreGraphics
import Foundation
let pid = Int(CommandLine.arguments[1])!
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let matches = windows.filter {
    ($0[kCGWindowOwnerPID as String] as? Int) == pid &&
    ($0[kCGWindowName as String] as? String) == "The Last Stop" &&
    ($0[kCGWindowLayer as String] as? Int) == 0
}
let data = try JSONSerialization.data(withJSONObject: matches, options: [.prettyPrinted, .sortedKeys])
print(String(data: data, encoding: .utf8)!)
