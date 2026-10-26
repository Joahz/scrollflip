// ScrollFlip — reverse mouse-wheel scrolling only; trackpad stays natural.
//
// macOS has one global "natural scrolling" switch shared by mouse and trackpad.
// Every scroll event carries an "is continuous" flag: trackpads (and Magic Mouse)
// send continuous events, notched mouse wheels send discrete ones. We tap the
// event stream and negate only the discrete ones, so the system setting stays
// natural for the trackpad and the wheel scrolls Windows-style.

import Cocoa
import ApplicationServices

let defaults = UserDefaults.standard
let enabledKey = "enabled"
let agentLabel = "com.josh.scrollflip"
let agentPath = NSString(string: "~/Library/LaunchAgents/\(agentLabel).plist").expandingTildeInPath

var flipEnabled: Bool {
    get { defaults.object(forKey: enabledKey) as? Bool ?? true }
    set { defaults.set(newValue, forKey: enabledKey) }
}

var eventTap: CFMachPort?


func isMouseWheel(_ event: CGEvent) -> Bool {
    // Discrete wheel = not continuous and no gesture phases (trackpad always has phases).
    event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0
        && event.getIntegerValueField(.scrollWheelEventScrollPhase) == 0
        && event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0
}

func flip(_ event: CGEvent) {
    // Read everything before writing: setting DeltaAxis makes macOS recompute the
    // FixedPt/Point deltas, so negating field-by-field would flip them back.
    let d1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
    let d2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
    let f1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
    let f2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
    let p1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
    let p2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
    event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -d1)
    event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -d2)
    event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -f1)
    event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -f2)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -p1)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -p2)
}

let callback: CGEventTapCallBack = { _, type, event, _ in
    // macOS disables slow/idle taps; turn ours back on.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    if type == .scrollWheel && flipEnabled && isMouseWheel(event) { flip(event) }
    return Unmanaged.passUnretained(event)
}

func installTap() -> Bool {
    let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
    guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                      options: .defaultTap, eventsOfInterest: mask,
                                      callback: callback, userInfo: nil) else { return false }
    eventTap = tap
    let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    return true
}

// Launch at login via a per-user LaunchAgent (works for an ad-hoc signed app).
var launchAtLogin: Bool { FileManager.default.fileExists(atPath: agentPath) }

func setLaunchAtLogin(_ on: Bool) {
    if on {
        let exe = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": [exe],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
        ]
        try? FileManager.default.createDirectory(atPath: (agentPath as NSString).deletingLastPathComponent,
                                                 withIntermediateDirectories: true)
        (plist as NSDictionary).write(toFile: agentPath, atomically: true)
    } else {
        try? FileManager.default.removeItem(atPath: agentPath)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var toggleItem: NSMenuItem!
    var loginItem: NSMenuItem!
    var retryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        toggleItem = NSMenuItem(title: "Reverse Mouse Wheel", action: #selector(toggle), keyEquivalent: "")
        loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        menu.addItem(toggleItem)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ScrollFlip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        refresh()

        // Prompt for Accessibility once, then keep retrying until it's granted.
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts) && installTap() { return refresh() }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
            if AXIsProcessTrusted() && installTap() { t.invalidate(); self?.refresh() }
        }
    }

    @objc func toggle() { flipEnabled.toggle(); refresh() }
    @objc func toggleLogin() { setLaunchAtLogin(!launchAtLogin); refresh() }

    func refresh() {
        let active = eventTap != nil
        toggleItem.state = flipEnabled ? .on : .off
        loginItem.state = launchAtLogin ? .on : .off
        let symbol = !active ? "exclamationmark.triangle" : (flipEnabled ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "ScrollFlip")
        statusItem.button?.toolTip = active ? "ScrollFlip" : "ScrollFlip — needs Accessibility permission"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
