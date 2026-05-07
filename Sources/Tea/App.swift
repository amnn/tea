import AppKit

/// AppKit delegate for the menu-bar utility.
///
/// This type only participates in the application lifecycle. It creates the
/// coordinator after AppKit finishes launching and gives it a chance to clean
/// up before the process exits.
final class App: NSObject, NSApplicationDelegate {

  /// Runtime object graph for the utility. It is `nil` until launch completes,
  /// then remains alive until termination.
  private var coordinator: AppCoordinator?

  /// Creates the application coordinator once AppKit has finished launching.
  /// The notification is supplied by AppKit and is not inspected.
  func applicationDidFinishLaunching(_ notification: Notification) {
    coordinator = AppCoordinator()
  }

  /// Stops any caffeination process before the application exits. The
  /// notification is supplied by AppKit and is not inspected.
  func applicationWillTerminate(_ notification: Notification) {
    coordinator?.stop()
  }
}
