import Foundation
import Cocoa

class ClickListener {
    let callback: CGEventTapCallBack
    private var eventTap: CFMachPort?
    
    init(callback: CGEventTapCallBack) {
        self.callback = callback
    }
    
    func startListening() {
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue)
        
        guard let dockPID = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" })?.processIdentifier else {
            print("Dock process not found! Failed to start click listener.")
            return
        }
        
//        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(eventMask), callback: callback, userInfo: nil)
        eventTap = CGEvent.tapCreateForPid(pid: dockPID, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(eventMask), callback: callback, userInfo: nil)
        guard let eventTap = eventTap else {
            print("Failed to create event tap.")
            return
        }
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        CFRunLoopRun()
    }
    
    func stopListening() {
        guard let eventTap = eventTap else { return }
        
        CFRunLoopStop(CFRunLoopGetCurrent())
        CGEvent.tapEnable(tap: eventTap, enable: false)
        self.eventTap = nil
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var dockIcons: NSMutableDictionary = NSMutableDictionary()
    static var updateDockIconsTimer: Timer?
    static var lastDockWidth: CGFloat = 0
    
    static var menuButton: MenuButton?
    
    static func getRunningApp(path: String) -> NSRunningApplication? {
        return NSWorkspace.shared.runningApplications.first { app in
            return app.bundleURL?.path == path
        }
    }
    
    static func updateDockIcons(dockList: AXUIElement) {
        let dockListChildren = AXUIElementHelpers.getElementChildren(dockList)
        guard let dockListChildren = dockListChildren else { return }
        
        AppDelegate.dockIcons = NSMutableDictionary()

        for element in dockListChildren {
            guard let title = AXUIElementHelpers.getElementAttribute(element, kAXTitleAttribute) as? String else { continue }
            guard let axURL = AXUIElementHelpers.getElementAttribute(element, kAXURLAttribute) as? NSURL else { continue }
            guard let filePath = axURL.path else { continue }
            guard let position = AXUIElementHelpers.getElementPosition(element) else { continue }
            guard let size = AXUIElementHelpers.getElementSize(element) else { continue }
            
            AppDelegate.dockIcons[title] = [
                "path": filePath,
                "rect": CGRect(x: position.x, y: position.y, width: size.width, height: size.height),
            ]
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Static fields are lazy loaded in Swift, so the singleton classes we want to load are being loaded here.
        _ = EasyWindowHide.instance
        _ = EasyWindowPreview.instance

        guard let dockPID = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" })?.processIdentifier else {
            print("Dock process not found! Stopping DockLikeWindows...")
            exit(0)
        }

        let dock = AXUIElementCreateApplication(dockPID)

        let dockChildren = AXUIElementHelpers.getElementChildren(dock)
        guard let dockChildren = dockChildren else { return }
        
        let dockList = dockChildren[0]
        
        AppDelegate.updateDockIcons(dockList: dockList)
        AppDelegate.updateDockIconsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            guard let dockSize = AXUIElementHelpers.getElementSize(dockList) else { return }
            let dockWidth = dockSize.width
            guard dockWidth != AppDelegate.lastDockWidth else { return }
            
            AppDelegate.lastDockWidth = dockWidth
            AppDelegate.updateDockIcons(dockList: dockList)
        }

        let clickListener = ClickListener(callback: { proxy, type, event, refcon in
            let flags = event.flags.rawValue
            let isCmdPressed = flags & CGEventFlags.maskCommand.rawValue != 0
            let isCtrlPressed = flags & CGEventFlags.maskControl.rawValue != 0
            let isAltPressed = flags & CGEventFlags.maskAlternate.rawValue != 0
            
            if isCmdPressed || isCtrlPressed || isAltPressed { return Unmanaged.passUnretained(event) }
            
            for (title, dockIcon) in AppDelegate.dockIcons {
                guard let dockIcon = dockIcon as? [String: Any],
                      let path = dockIcon["path"] as? String,
//                      let title = title as? String,
                      let iconRect = dockIcon["rect"] as? CGRect
                else { continue }
                
                if !iconRect.contains(event.location) { continue }
                
                guard let app = AppDelegate.getRunningApp(path: path) else { return Unmanaged.passUnretained(event) }
                
                if EasyWindowPreview.instance.onDockIconClick(app: app, dockIconRect: iconRect) {
                    return nil
                }
                
                let isFinder = app.bundleIdentifier == "com.apple.finder" // Finder causes issues with EasyWindowHide.
                if isFinder { return Unmanaged.passUnretained(event) }

                if EasyWindowHide.instance.onDockIconClick(app: app) {
                    return nil
                }
            }
            
            return Unmanaged.passUnretained(event)
        })
        clickListener.startListening()
        
        AppDelegate.menuButton = MenuButton()
        
        print("DockLikeWindows loaded.")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        AppDelegate.updateDockIconsTimer?.invalidate()
    }
}
