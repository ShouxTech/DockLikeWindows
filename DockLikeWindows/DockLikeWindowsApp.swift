//
//  DockLikeWindowsApp.swift
//  DockLikeWindows
//
//  Created by CriShoux on 2024-03-01.
//

import SwiftUI
import Cocoa

//@main
//struct DockLikeWindowsApp: App {
//    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
//
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//    }
//}

@main
struct DockLikeWindowsApp {
    static func main() {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
