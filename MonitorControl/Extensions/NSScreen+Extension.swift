import Cocoa

extension NSScreen {
  public func displayID() -> CGDirectDisplayID {
    return (self.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)!
  }
}
