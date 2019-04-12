import Cocoa

extension NSScreen {
  public var displayID: CGDirectDisplayID {
    return (self.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)!
  }
}
