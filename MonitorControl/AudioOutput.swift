import AVKit

class AudioOutput {
  static let changedNotification = NSNotification.Name("audioOutputChanged")

  static var audioOutputListenerProc: AudioObjectPropertyListenerProc = { _, _, _, _ in
    NotificationCenter.default.post(name: AudioOutput.changedNotification, object: nil)
    return kAudioHardwareNoError
  }

  static func startListener() {
    var address = AudioObjectPropertyAddress.init(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)

    AudioObjectAddPropertyListener(AudioObjectID(kAudioObjectSystemObject), &address, audioOutputListenerProc, nil)
  }

  static func removeListener() {
    var address = AudioObjectPropertyAddress.init(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)

    AudioObjectRemovePropertyListener(AudioObjectID(kAudioObjectSystemObject), &address, audioOutputListenerProc, nil)
  }

  let deviceID: AudioDeviceID

  static func current() -> AudioOutput? {
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout.size(ofValue: deviceID))
    var address  = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)

    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID) == kAudioHardwareNoError else {
      return nil
    }

    return AudioOutput(id: deviceID)
  }

  init(id: AudioDeviceID) {
    self.deviceID = id
  }

  func name() -> String? {
    return AudioOutput.getOutputDataSourceID(for: self.deviceID).map { AudioOutput.getDataSourceName(for: $0, deviceID: self.deviceID) } ??
      AudioOutput.getDeviceName(for: self.deviceID)
  }

  static func getOutputDataSources(for deviceID: UInt32) -> [OSType]? {
    var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDataSources, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMaster)
    var size = UInt32(0)

    guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == kAudioHardwareNoError else {
      return nil
    }

    let count = Int(size) / MemoryLayout<OSType>.size
    let sources = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(size))

    guard AudioObjectGetPropertyData (deviceID, &address, 0, nil, &size, sources) == kAudioHardwareNoError else {
      return nil
    }

    let dataSources = sources.withMemoryRebound(to: OSType.self, capacity: count) {
      Array(UnsafeBufferPointer(start: $0, count: count))
    }

    return dataSources
  }

  static func getDeviceName(for deviceID: AudioDeviceID) -> String? {
    var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceName, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMaster)

    var size = UInt32(0)

    guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == kAudioHardwareNoError else {
      return nil
    }

    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(size))

    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, buffer) == kAudioHardwareNoError else {
      return nil
    }

    return String.init(cString: buffer)
  }

  static func getDataSourceName(for dataSourceID: OSType, deviceID: AudioDeviceID) -> String? {
    var dataSourceID = dataSourceID

    var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDataSourceNameForID, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMaster)

    var size = UInt32(0)

    guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == kAudioHardwareNoError else {
      return nil
    }

    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(size))

    var avt = AudioValueTranslation(mInputData: &dataSourceID, mInputDataSize: UInt32(MemoryLayout.size(ofValue: dataSourceID)), mOutputData: buffer, mOutputDataSize: size)

    var transSize = UInt32(MemoryLayout.size(ofValue: avt))

    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &transSize, &avt) == kAudioHardwareNoError else {
      return nil
    }

    return String.init(cString: buffer)
  }

  static func getOutputDataSourceID(for deviceID: AudioDeviceID) -> OSType? {
    var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDataSource, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMaster)

    var dataSourceID = OSType(0)
    var dataSourceIDSize = UInt32(MemoryLayout<OSType>.size)

    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSourceIDSize, &dataSourceID) == kAudioHardwareNoError else {
      return nil
    }

    return dataSourceID
  }
}
