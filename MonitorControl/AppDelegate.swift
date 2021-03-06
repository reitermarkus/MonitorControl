import Cocoa
import DDC
import Foundation
import MASPreferences
import MediaKeyTap

var app: AppDelegate!
let prefs = UserDefaults.standard

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, MediaKeyTapDelegate {
  @IBOutlet var statusMenu: NSMenu!
  @IBOutlet var window: NSWindow!

  let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

  var monitorItems: [NSMenuItem] = []
  var displays: [Display] = []

  let step = 100 / 16

  var mediaKeyTap: MediaKeyTap?
  var prefsController: NSWindowController?

  func applicationDidFinishLaunching(_: Notification) {
    app = self

    let storyboard: NSStoryboard = NSStoryboard(name: "Main", bundle: Bundle.main)
    let views = [
      storyboard.instantiateController(withIdentifier: "MainPrefsVC"),
      storyboard.instantiateController(withIdentifier: "KeysPrefsVC"),
      storyboard.instantiateController(withIdentifier: "DisplayPrefsVC"),
    ]
    prefsController = MASPreferencesWindowController(viewControllers: views, title: NSLocalizedString("Preferences", comment: "Shown in Preferences window"))

    NotificationCenter.default.addObserver(self, selector: #selector(self.handleListenForChanged), name: NSNotification.Name(Utils.PrefKeys.listenFor.rawValue), object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(self.handleShowContrastChanged), name: NSNotification.Name(Utils.PrefKeys.showContrast.rawValue), object: nil)

    self.statusItem.image = NSImage(named: "status")
    self.statusItem.menu = self.statusMenu

    self.setDefaultPrefs()

    Utils.acquirePrivileges()

    CGDisplayRegisterReconfigurationCallback({ _, _, _ in app.updateDisplays() }, nil)
    self.updateDisplays()

    self.startOrRestartMediaKeyTap()

    AudioOutput.startListener()
    NotificationCenter.default.addObserver(self, selector: #selector(self.handleAudioOutputChanged), name: AudioOutput.changedNotification, object: nil)
  }

  func applicationWillTerminate(_: Notification) {
    AudioOutput.removeListener()
  }

  @IBAction func quitClicked(_: AnyObject) {
    NSApplication.shared.terminate(self)
  }

  @IBAction func prefsClicked(_ sender: AnyObject) {
    if let prefsController = prefsController {
      prefsController.showWindow(sender)
      NSApp.activate(ignoringOtherApps: true)
      prefsController.window?.makeKeyAndOrderFront(sender)
    }
  }

  /// Set the default prefs of the app
  func setDefaultPrefs() {
    let prefs = UserDefaults.standard
    if !prefs.bool(forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue) {
      prefs.set(true, forKey: Utils.PrefKeys.appAlreadyLaunched.rawValue)
      prefs.set(false, forKey: Utils.PrefKeys.showContrast.rawValue)
      prefs.set(false, forKey: Utils.PrefKeys.lowerContrast.rawValue)
    }
  }

  // MARK: - Menu

  func clearDisplays() {
    if self.statusMenu.items.count > 2 {
      var items: [NSMenuItem] = []
      for i in 0..<self.statusMenu.items.count - 2 {
        items.append(self.statusMenu.items[i])
      }

      for item in items {
        self.statusMenu.removeItem(item)
      }
    }

    self.monitorItems = []
    self.displays = []
  }

  func updateDisplays() {
    self.clearDisplays()

    var filteredScreens = NSScreen.screens.filter { screen -> Bool in
      let id = screen.displayID

      // Is Built In Screen (e.g. MBP/iMac Screen)
      if CGDisplayIsBuiltin(id) != 0 {
        return false
      }

      return DDC(for: id)?.edid() != nil
    }

    if filteredScreens.count == 1 {
      self.addScreenToMenu(screen: filteredScreens[0], asSubMenu: false)
    } else {
      for screen in filteredScreens {
        self.addScreenToMenu(screen: screen, asSubMenu: true)
      }
    }

    if filteredScreens.count == 0 {
      // If no DDC capable display was detected
      let item = NSMenuItem()
      item.title = NSLocalizedString("No supported display found", comment: "Shown in menu")
      item.isEnabled = false
      self.monitorItems.append(item)
      self.statusMenu.insertItem(item, at: 0)
      self.statusMenu.insertItem(NSMenuItem.separator(), at: 1)
    }
  }

  /// Add a screen to the menu
  ///
  /// - Parameters:
  ///   - screen: The screen to add
  ///   - asSubMenu: Display in a sub menu or directly in menu
  private func addScreenToMenu(screen: NSScreen, asSubMenu: Bool) {
    let id = screen.displayID
    let ddc = DDC(for: id)

    if let edid = ddc?.edid() {
      let name = Utils.getDisplayName(forEdid: edid)

      let display = Display(id, name: name)

      let monitorSubMenu: NSMenu = asSubMenu ? NSMenu() : self.statusMenu

      self.statusMenu.insertItem(NSMenuItem.separator(), at: 0)

      let volumeSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
                                                        forDisplay: display,
                                                        command: .audioSpeakerVolume,
                                                        title: NSLocalizedString("Volume", comment: "Shown in menu"))
      let brightnessSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
                                                            forDisplay: display,
                                                            command: .brightness,
                                                            title: NSLocalizedString("Brightness", comment: "Shown in menu"))
      if prefs.bool(forKey: Utils.PrefKeys.showContrast.rawValue) {
        let contrastSliderHandler = Utils.addSliderMenuItem(toMenu: monitorSubMenu,
                                                            forDisplay: display,
                                                            command: .contrast,
                                                            title: NSLocalizedString("Contrast", comment: "Shown in menu"))
        display.contrastSliderHandler = contrastSliderHandler
      }

      display.volumeSliderHandler = volumeSliderHandler
      display.brightnessSliderHandler = brightnessSliderHandler
      self.displays.append(display)

      let monitorMenuItem = NSMenuItem()
      monitorMenuItem.title = "\(name)"
      if asSubMenu {
        monitorMenuItem.submenu = monitorSubMenu
      }

      self.monitorItems.append(monitorMenuItem)
      self.statusMenu.insertItem(monitorMenuItem, at: 0)
    }
  }

  // MARK: - Media Key Tap delegate

  func handle(mediaKey: MediaKey, event _: KeyEvent?) {
    guard let currentDisplay = Utils.getCurrentDisplay(from: displays) else { return }
    let allDisplays = prefs.bool(forKey: Utils.PrefKeys.allScreens.rawValue) ? self.displays : [currentDisplay]
    for display in allDisplays {
      if (prefs.object(forKey: "\(display.identifier)-state") as? Bool) ?? true {
        switch mediaKey {
        case .brightnessUp:
          let value = display.calcNewValue(for: .brightness, withRel: +self.step)
          display.setBrightness(to: value)
        case .brightnessDown:
          let value = currentDisplay.calcNewValue(for: .brightness, withRel: -self.step)
          display.setBrightness(to: value)
        case .mute:
          display.mute()
        case .volumeUp:
          let value = display.calcNewValue(for: .audioSpeakerVolume, withRel: +self.step)
          display.setVolume(to: value)
        case .volumeDown:
          let value = display.calcNewValue(for: .audioSpeakerVolume, withRel: -self.step)
          display.setVolume(to: value)
        default:
          return
        }
      }
    }
  }

  // MARK: - Prefs notification

  @objc func handleListenForChanged() {
    self.startOrRestartMediaKeyTap()
  }

  @objc func startOrRestartMediaKeyTap() {
    let listenFor = prefs.integer(forKey: Utils.PrefKeys.listenFor.rawValue)

    var keysListenedFor: [MediaKey]!

    if listenFor == Utils.ListenForKeys.brightnessOnlyKeys.rawValue {
      keysListenedFor = [.brightnessUp, .brightnessDown]
    } else if listenFor == Utils.ListenForKeys.volumeOnlyKeys.rawValue {
      keysListenedFor = [.mute, .volumeUp, .volumeDown]
    } else {
      keysListenedFor = [.brightnessUp, .brightnessDown, .mute, .volumeUp, .volumeDown]
    }

    let useVolumeControlForAllDisplays = self.displays.allSatisfy {
      if let audioDeviceName = AudioOutput.current()?.name() {
        return $0.name == audioDeviceName
      } else {
        return false
      }
    }

    if useVolumeControlForAllDisplays {
      #if DEBUG
        print("Volume control for all displays is now on.")
      #endif
    } else {
      #if DEBUG
        print("Volume control for all displays is now off.")
      #endif

      keysListenedFor = [.brightnessUp, .brightnessDown]
    }

    self.mediaKeyTap?.stop()
    self.mediaKeyTap = MediaKeyTap(delegate: self, for: keysListenedFor, observeBuiltIn: false)
    self.mediaKeyTap?.start()
  }

  @objc func handleShowContrastChanged() {
    self.updateDisplays()
  }

  @objc func handleAudioOutputChanged() {
    self.startOrRestartMediaKeyTap()
  }
}
