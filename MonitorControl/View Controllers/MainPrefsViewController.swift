import Cocoa
import MASPreferences
import ServiceManagement

class MainPrefsViewController: NSViewController, MASPreferencesViewController {
  var viewIdentifier: String = "Main"
  var toolbarItemLabel: String? = NSLocalizedString("General", comment: "Shown in the main prefs window")
  var toolbarItemImage: NSImage? = NSImage(named: NSImage.preferencesGeneralName)
  let prefs = UserDefaults.standard

  @IBOutlet var startAtLogin: NSButton!
  @IBOutlet var showContrastSlider: NSButton!
  @IBOutlet var lowerContrast: NSButton!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.startAtLogin.state = self.prefs.bool(forKey: Utils.PrefKeys.startAtLogin.rawValue) ? .on : .off
    self.showContrastSlider.state = self.prefs.bool(forKey: Utils.PrefKeys.showContrast.rawValue) ? .on : .off
    self.lowerContrast.state = self.prefs.bool(forKey: Utils.PrefKeys.lowerContrast.rawValue) ? .on : .off
  }

  @IBAction func startAtLoginClicked(_ sender: NSButton) {
    let identifier = "me.guillaumeb.MonitorControlHelper" as CFString
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.startAtLogin.rawValue)
      SMLoginItemSetEnabled(identifier, true)
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.startAtLogin.rawValue)
      SMLoginItemSetEnabled(identifier, false)
    default: break
    }

    #if DEBUG
      print("Toggle start at login state -> \(sender.state == .on ? "on" : "off")")
    #endif
  }

  @IBAction func showContrastSliderClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.showContrast.rawValue)
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.showContrast.rawValue)
    default: break
    }

    #if DEBUG
      print("Toggle show contrast slider state -> \(sender.state == .on ? "on" : "off")")
    #endif

    NotificationCenter.default.post(name: Notification.Name(Utils.PrefKeys.showContrast.rawValue), object: nil)
  }

  @IBAction func lowerContrastClicked(_ sender: NSButton) {
    switch sender.state {
    case .on:
      self.prefs.set(true, forKey: Utils.PrefKeys.lowerContrast.rawValue)
    case .off:
      self.prefs.set(false, forKey: Utils.PrefKeys.lowerContrast.rawValue)
    default: break
    }

    #if DEBUG
      print("Toggle lower contrast after brightness state -> \(sender.state == .on ? "on" : "off")")
    #endif
  }
}