//
//  MenuButton.swift
//  DockLikeWindows
//
//  Created by CriShoux on 2024-03-03.
//

import Foundation

class MenuButton {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    
    init() {
        menu = NSMenu()
        menu.title = "DockLikeWindows"
//        menu.addItem(
//            withTitle: "test",
//            action: #selector(MenuButton.menuItemClicked),
//            keyEquivalent: "").target = self
        menu.addItem(
            withTitle: "DockLikeWindows",
            action: nil,
            keyEquivalent: "").target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            withTitle: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button!.target = self
        statusItem.button!.image = NSImage(named: "AppIcon")
        statusItem.button!.imageScaling = .scaleProportionallyUpOrDown
        statusItem.menu = menu
    }
    
//    @objc func menuItemClicked(_ sender: Any?) {
//        print("Clicked")
//    }
}
