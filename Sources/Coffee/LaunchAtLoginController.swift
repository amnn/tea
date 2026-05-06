import ServiceManagement

/// Owns the app's “Open at Login” registration.
///
/// This controller is the only component that talks to ServiceManagement. It
/// exposes the current registration status, and toggles whether the app should
/// be launched the next time the user logs in.
@MainActor
final class LaunchAtLoginController {
  /// Called after registration status may have changed. The callback runs on the
  /// main actor and should read `isEnabled` for the new state.
  var onStateChange: (() -> Void)?

  /// Whether this app is currently registered to open when the user logs in.
  var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  /// Inverts the current “Open at Login” registration. On success,
  /// `onStateChange` is invoked. On failure, the ServiceManagement error is
  /// thrown and registration state is left to the system.
  func toggle() throws {
    if isEnabled {
      try SMAppService.mainApp.unregister()
    } else {
      try SMAppService.mainApp.register()
    }

    onStateChange?()
  }
}
