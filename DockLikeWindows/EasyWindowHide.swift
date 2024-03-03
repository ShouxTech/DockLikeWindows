//
//  EasyWindowHide.swift
//  DockLikeWindows
//
//  Created by CriShoux on 2024-03-02.
//

import Foundation
import Cocoa

class EasyWindowHide {
    static let instance = EasyWindowHide()
    
    private init() {
        
    }
    
    func onDockIconClick(app: NSRunningApplication) -> Bool {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication, frontmostApp == app {
            app.hide()
            return true
        }
        
        return false
    }
}
