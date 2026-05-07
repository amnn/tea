import Foundation

/// Owns the `caffeinate` child process used to prevent sleep.
///
/// This controller handles process lifecycle only. It does not know about
/// menus, status items, or error presentation. State changes are serialized on
/// the main actor so UI callbacks can safely read `isCaffeinated`.
@MainActor
final class CaffeinationController {

  /// Called whenever `isCaffeinated` may have changed. The callback runs on
  /// the main actor and should read `isCaffeinated` for the new state.
  var onStateChange: (() -> Void)?

  /// Child process started by this app, or `nil` when this app is not
  /// caffeinating. If non-`nil`, `isCaffeinated` is true only while the
  /// process is still running.
  private var process: Process?

  /// Whether the `caffeinate` process owned by this controller is running.
  var isCaffeinated: Bool {
    process?.isRunning == true
  }

  /// Inverts the current caffeination state. If starting `caffeinate` fails,
  /// the error is thrown and state is left unchanged.
  func toggle() throws {
    if isCaffeinated {
      stop()
    } else {
      try start()
    }
  }

  /// Starts `/usr/bin/caffeinate -is` unless already running. On success,
  /// `process` references the launched child and `onStateChange` is invoked;
  /// on launch failure, `process` remains unchanged and the error is thrown.
  func start() throws {
    guard !isCaffeinated else { return }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
    process.arguments = ["-is"]
    process.terminationHandler = { [weak self] _ in
      DispatchQueue.main.async {
        self?.process = nil
        self?.onStateChange?()
      }
    }

    try process.run()
    self.process = process
    onStateChange?()
  }

  /// Stops the owned `caffeinate` process. Calling this when already stopped
  /// is a no-op; otherwise the process is sent `terminate()`, local state is
  /// cleared, and `onStateChange` is invoked once for the explicit stop.
  func stop() {
    guard let process else { return }
    process.terminationHandler = nil
    process.terminate()
    self.process = nil
    onStateChange?()
  }
}
