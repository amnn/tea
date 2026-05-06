import AppKit

/// Coordinates application flow between process state and AppKit UI.
///
/// Status-item clicks open the menu or toggle caffeination, menu actions toggle
/// caffeination or quit, and caffeination state changes re-render the UI. The
/// coordinator contains wiring logic only; process, status-item, and menu
/// details live in their respective controllers.
@MainActor
final class AppCoordinator {

  /// Owner of the `/usr/bin/caffeinate` child process. Process lifecycle changes
  /// always go through this controller.
  private let caffeination = CaffeinationController()

  /// Owner of the menu-bar status item. It is rendered from
  /// `caffeination.isCaffeinated` whenever that state may have changed.
  private let statusItem: StatusItemController

  /// Owner of the application menu. Its toggle item is rendered from
  /// `caffeination.isCaffeinated`; its assertion list comes from its provider.
  private let menu: MenuController

  /// Builds the controller graph, installs callbacks, and renders the initial UI.
  /// Call this on the main actor after `NSApplication` has been configured.
  init() {
    statusItem = StatusItemController()
    menu = MenuController(assertionProvider: PmsetAssertionProvider())

    statusItem.onPrimaryClick = { [weak self] in self?.openMenu() }
    statusItem.onSecondaryClick = { [weak self] in self?.toggleCaffeination() }

    menu.onToggle = { [weak self] in self?.toggleCaffeination() }
    menu.onQuit = { NSApp.terminate(nil) }
    menu.onClose = { [weak self] in self?.statusItem.detachMenu() }

    caffeination.onStateChange = { [weak self] in self?.render() }

    render()
  }

  /// Stops caffeination owned by this application. It is safe to call when
  /// already stopped; afterwards this app is no longer preventing sleep.
  func stop() {
    caffeination.stop()
  }

  /// Toggles caffeination in response to a UI event. On success, callbacks from
  /// the caffeination controller re-render the UI; on failure, state remains
  /// unchanged and AppKit presents the error.
  private func toggleCaffeination() {
    do {
      try caffeination.toggle()
    } catch {
      NSApp.presentError(error)
    }
  }

  /// Opens the menu from the status item. The menu remains owned by
  /// `MenuController` and will be detached after AppKit closes it.
  private func openMenu() {
    statusItem.open(menu: menu.menu)
  }

  /// Renders all UI from the current caffeination state.
  private func render() {
    let state = caffeination.isCaffeinated
    statusItem.render(isCaffeinated: state)
    menu.render(isCaffeinated: state)
  }
}
