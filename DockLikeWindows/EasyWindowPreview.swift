//
//  EasyWindowPreview.swift
//  DockLikeWindows
//
//  Created by CriShoux on 2024-03-02.
//

import Foundation
import Cocoa

let PREVIEW_SPACING: CGFloat = 5 // Space between previews side by side.
let SCREENSHOT_DIVISION_FACTOR: CGFloat = 6

func takeScreenshot(windowNumber: UInt32) -> NSImage? {
    var windowID = CGWindowID(windowNumber)
    let list = CGSHWCaptureWindowList(CGSMainConnectionID(), &windowID, 1, [.ignoreGlobalClipShape, .nominalResolution]).takeRetainedValue() as! [CGImage]
    return NSImage(cgImage: list.first!, size: .zero)
//    let windowID = CGWindowID(windowNumber)
//    guard let cgImage = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, .boundsIgnoreFraming) else { return nil }
//    
//    let image = NSImage(cgImage: cgImage, size: .zero)
//    return image
}

func getWindowID(_ window: AXUIElement) -> UInt32? {
    var windowID: UInt32 = 0
    _AXUIElementGetWindow(window, &windowID)
    guard windowID != 0 else { return nil }
    return windowID
}

extension NSImage {
    func aspectFit(size: CGSize) -> CGSize {
        let aspectWidth = size.width / self.size.width
        let aspectHeight = size.height / self.size.height
        let aspectRatio = min(aspectWidth, aspectHeight)

        let scaledWidth = self.size.width * aspectRatio
        let scaledHeight = self.size.height * aspectRatio

        return CGSize(width: scaledWidth, height: scaledHeight)
    }
    
    func divideSize(factor: CGFloat) -> CGSize {
        let width = self.size.width / factor
        let height = self.size.height / factor

        return CGSize(width: width, height: height)
    }
}

class OverlayWindow: NSWindow {
    init() {
        let overlayRect = NSScreen.main!.frame
        
        super.init(contentRect: overlayRect, styleMask: .borderless, backing: .buffered, defer: false)
        
        self.backgroundColor = NSColor.clear
        self.isOpaque = false
        self.level = .popUpMenu
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        
        self.contentView = OverlayView(frame: overlayRect)
        
        self.orderFront(nil)
    }
    
    // Prevent window getting focused when preview is clicked.
    override func _isNonactivatingPanel() -> Bool {
        return true
    }
}

class OverlayView: NSView {
    public var app: NSRunningApplication?
    public var previewScreenshots: [NSImage]?
    public var windows: [AXUIElement]?
    public var position: CGPoint?
    
    private var previewClickMonitor: Any?
    private var outsideClickMonitor: Any?
    private var hoveringScreenshotRect: CGRect?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if let previewClickMonitor = previewClickMonitor {
            NSEvent.removeMonitor(previewClickMonitor)
            self.previewClickMonitor = nil
        }
        if let outsideClickMonitor = outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        
        guard let app = app else { return }
        guard let previewScreenshots = previewScreenshots else { return }
        guard let windows = windows else { return }
        guard let position = position else { return }
        
        let widthSum = previewScreenshots.reduce(0) { partialResult, screenshot in
            return partialResult + screenshot.divideSize(factor: SCREENSHOT_DIVISION_FACTOR).width
        }
        guard let heightMax = (previewScreenshots.map { $0.divideSize(factor: SCREENSHOT_DIVISION_FACTOR).height }.max { $0 < $1 }) else { return }
        
        let bodySize = CGSize(width: widthSum + (CGFloat(previewScreenshots.count - 1) * PREVIEW_SPACING), height: heightMax + 10)
        let bodyRect = CGRect(
            x: position.x - (bodySize.width / 2),
            y: fixY(position.y, nil),
            width: bodySize.width,
            height: bodySize.height
        )

        let backgroundSize = CGSize(width: bodySize.width + 10, height: heightMax + 10)
        let backgroundRect = CGRect(
            x: position.x - (backgroundSize.width / 2),
            y: fixY(position.y, nil),
            width: backgroundSize.width,
            height: backgroundSize.height
        )
        let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 6, yRadius: 6)
        NSColor.darkGray.withAlphaComponent(0.5).setFill()
        backgroundPath.fill()
        
        NSColor.lightGray.withAlphaComponent(0.7).setStroke()
        backgroundPath.lineWidth = 0.5
        backgroundPath.stroke()
        
        var previewRects: [CGRect] = []
        
        var currentX: CGFloat = bodyRect.origin.x
        for screenshot in previewScreenshots {
            let previewRect = CGRect(
                origin: CGPoint(x: currentX, y: fixY(position.y - 5, nil)),
                size: screenshot.divideSize(factor: SCREENSHOT_DIVISION_FACTOR)
            )
            screenshot.draw(in: previewRect)
            currentX += previewRect.width + PREVIEW_SPACING
            
            if let hoveringScreenshotRect = hoveringScreenshotRect {
                if hoveringScreenshotRect == previewRect {
                    let borderPath = NSBezierPath(rect: previewRect)
                    NSColor.white.withAlphaComponent(0.9).setStroke()
                    borderPath.lineWidth = 0.5
                    borderPath.stroke()
                }
            }

            previewRects.append(previewRect)
            self.addTrackingArea(NSTrackingArea(rect: previewRect, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: ["previewRect": previewRect]))
        }
        
        previewClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { event in
            guard let previewRect = (previewRects.first { rect in
                return rect.contains(event.locationInWindow)
            }) else { return event }
            
            guard let windowIndex = previewRects.firstIndex(of: previewRect) else { return event }
            let window = windows[windowIndex]
            
            setApplicationFrontmost(app)
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(window, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            self.hide()
            
            return event
        }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { event in
            self.hide()
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo as? [String: Any] else { return }
        guard let screenshotRect = userInfo["previewRect"] as? CGRect else { return }
        
        hoveringScreenshotRect = screenshotRect
        self.needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        hoveringScreenshotRect = nil
        self.needsDisplay = true
    }
    
    func fixY(_ targetY: CGFloat, _ elementHeight: CGFloat?) -> CGFloat {
        if let elementHeight = elementHeight {
            return frame.size.height - targetY - elementHeight
        } else {
            return frame.size.height - targetY
        }
    }
    
    func hide() {
        for trackingArea in trackingAreas {
            self.removeTrackingArea(trackingArea)
        }

        self.app = nil
        self.previewScreenshots = nil
        self.windows = nil
        self.position = nil
        self.hoveringScreenshotRect = nil
        self.needsDisplay = true
    }
}

class EasyWindowPreview {
    static let instance = EasyWindowPreview()
    
    let overlayWindow = OverlayWindow()
    
    private init() {}
    
    func onDockIconClick(app: NSRunningApplication, dockIconRect: CGRect) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        let isFinder = app.bundleIdentifier == "com.apple.finder"
        let minimumWindowsForPreview = isFinder ? 3 : 2
        
        guard let windows = AXUIElementHelpers.getElementAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else { return false }
        guard windows.count >= minimumWindowsForPreview else { return false }
        
        let sortedWindows = windows.filter { return getWindowID($0) != nil }
            .sorted { getWindowID($0)! < getWindowID($1)! } // Prevent preview order changing.
        
        var screenshots: [NSImage] = []
        var validWindows: [AXUIElement] = []

        for window in sortedWindows {
            guard let windowID = getWindowID(window) else { continue }
            guard let screenshot = takeScreenshot(windowNumber: windowID) else { continue }
            screenshots.append(screenshot)
            validWindows.append(window)
        }
        
        let overlayView = overlayWindow.contentView as! OverlayView
        overlayView.app = app
        overlayView.previewScreenshots = screenshots
        overlayView.windows = validWindows
        overlayView.position = dockIconRect.offsetBy(dx: dockIconRect.size.width / 2, dy: 0).origin
        overlayView.needsDisplay = true
        
        return true
    }
}
