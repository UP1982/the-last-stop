// Native visual gate: send only to the launched game PID. Key codes use macOS virtual keys.
import AppKit
import CoreGraphics
import Foundation
let pid=pid_t(CommandLine.arguments[1])!
let key=CGKeyCode(CommandLine.arguments[2])!
let duration=Double(CommandLine.arguments[3])!
guard let app=NSRunningApplication(processIdentifier:pid),app.localizedName != nil else {exit(2)}
app.activate(options:[])
Thread.sleep(forTimeInterval:0.1)
let down=CGEvent(keyboardEventSource:nil,virtualKey:key,keyDown:true)!
if key==99 { down.flags=[.maskSecondaryFn] }
down.postToPid(pid)
Thread.sleep(forTimeInterval:duration)
let up=CGEvent(keyboardEventSource:nil,virtualKey:key,keyDown:false)!
if key==99 { up.flags=[.maskSecondaryFn] }
up.postToPid(pid)
print("sent key \(key) to PID \(pid)")
