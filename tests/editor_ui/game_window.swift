// Print only the single visible, normal window belonging to the preview PID.
// Usage: swift tests/editor_ui/game_window.swift <owned-preview-pid>
import Foundation
import CoreGraphics

guard CommandLine.arguments.count == 2, let pid = Int(CommandLine.arguments[1]) else { exit(2) }
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let matches = windows.filter {
    ($0[kCGWindowOwnerPID as String] as? Int) == pid &&
    ($0[kCGWindowLayer as String] as? Int) == 0 &&
    (($0[kCGWindowBounds as String] as? [String: Any])?["Width"] as? Double ?? 0) >= 640 &&
    (($0[kCGWindowBounds as String] as? [String: Any])?["Height"] as? Double ?? 0) >= 360
}
guard matches.count == 1 else {
    fputs("Expected exactly one game window for the owned preview PID; found \(matches.count)\n", stderr)
    exit(3)
}
let bytes = try JSONSerialization.data(withJSONObject: matches[0], options: [.prettyPrinted, .sortedKeys])
print(String(data: bytes, encoding: .utf8)!)
