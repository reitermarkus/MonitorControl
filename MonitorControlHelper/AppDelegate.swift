//
//  AppDelegate.swift
//  MonitorControlHelper
//
//  Created by Guillaume BRODER on 13/01/2018.
//  Copyright © 2018 Mathew Kurian. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
  @IBOutlet var window: NSWindow!

  func applicationDidFinishLaunching(_: Notification) {
    let bundlePath = Bundle.main.bundlePath as NSString
    var pathComponents = bundlePath.pathComponents
    for _ in 0...4 {
      pathComponents.removeLast()
    }

    let path = NSString.path(withComponents: pathComponents)
    NSWorkspace.shared.launchApplication(path)
    NSApp.terminate(nil)
  }

  func applicationWillTerminate(_: Notification) {
    // Insert code here to tear down your application
  }
}
