// PID-scoped native lifecycle operations; never target the frontmost app.
import ApplicationServices
import AppKit
import Foundation
let pid = pid_t(CommandLine.arguments[1])!
let action = CommandLine.arguments[2]
let app = AXUIElementCreateApplication(pid)
var value: CFTypeRef?
guard AXUIElementCopyAttributeValue(app,kAXWindowsAttribute as CFString,&value) == .success,
      let windows = value as? [AXUIElement] else { exit(2) }
let matches = windows.filter { w in
 var title: CFTypeRef?
 return AXUIElementCopyAttributeValue(w,kAXTitleAttribute as CFString,&title) == .success && (title as? String) == "The Last Stop"
}
guard matches.count == 1 else { exit(3) }
let w=matches[0]
switch action {
case "close":
 var button:CFTypeRef?
 guard AXUIElementCopyAttributeValue(w,kAXCloseButtonAttribute as CFString,&button) == .success else { exit(4) }
 guard AXUIElementPerformAction(button as! AXUIElement,kAXPressAction as CFString) == .success else { exit(5) }
case "minimize", "restore":
 guard AXUIElementSetAttributeValue(w,kAXMinimizedAttribute as CFString,(action == "minimize" ? kCFBooleanTrue : kCFBooleanFalse)) == .success else { exit(6) }
case "focus":
 guard let running = NSRunningApplication(processIdentifier:pid) else { exit(7) }
 running.activate(options: [.activateIgnoringOtherApps])
 guard AXUIElementPerformAction(w,kAXRaiseAction as CFString) == .success else { exit(8) }
default:exit(9)
}
print("PID \(pid) \(action)")
