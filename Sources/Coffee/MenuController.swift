import AppKit

/// Owns and renders the application's menu.
///
/// This controller constructs the `NSMenu`, refreshes the caffeination toggle
/// label, and lists current Prevent assertions. It delegates actions through
/// callbacks and delegates assertion lookup to an `AssertionProviding` value.
@MainActor
final class MenuController: NSObject, NSMenuDelegate {

  /// Callback invoked by the Turn On/Turn Off item. The menu never starts or
  /// stops caffeination directly and does not assume the state actually changed.
  var onToggle: (() -> Void)?

  /// Callback invoked by the Quit item. The menu does not terminate the app
  /// directly.
  var onQuit: (() -> Void)?

  /// Callback invoked after AppKit closes the menu. The coordinator uses this to
  /// detach the menu from the status item.
  var onClose: (() -> Void)?

  /// Menu owned and rebuilt by this controller. Its delegate is this controller
  /// for the controller's lifetime.
  let menu = NSMenu()

  /// Source of Prevent assertion groups. It is fixed after initialization and is
  /// queried each time the menu is rebuilt.
  private let assertionProvider: AssertionProviding

  /// Last rendered caffeination state. The toggle menu item title is rebuilt
  /// from this value.
  private var isCaffeinated = false

  /// Creates a menu controller backed by an assertion provider. The provider is
  /// queried whenever the menu is rebuilt; after initialization the menu has this
  /// controller as its delegate and contains an initial stopped-state rendering.
  init(assertionProvider: AssertionProviding) {
    self.assertionProvider = assertionProvider
    super.init()
    menu.delegate = self
    rebuildMenu()
  }

  /// Updates and rebuilds the menu for a caffeination state. `isCaffeinated` is
  /// true when this app is currently preventing sleep via `caffeinate`; after the
  /// call, the toggle item title reflects that value.
  func render(isCaffeinated: Bool) {
    self.isCaffeinated = isCaffeinated
    rebuildMenu()
  }

  /// Refreshes menu contents immediately before AppKit displays the menu. AppKit
  /// supplies `menu`; it is expected to be this controller's menu. The visible
  /// assertion list is fresh after this method returns.
  func menuWillOpen(_ menu: NSMenu) {
    rebuildMenu()
  }

  /// Notifies the owner that AppKit has closed the menu. AppKit supplies `menu`;
  /// it is expected to be this controller's menu.
  func menuDidClose(_ menu: NSMenu) {
    onClose?()
  }

  /// Handles selection of the caffeination toggle item by invoking `onToggle`.
  @objc private func toggleCaffeination() {
    onToggle?()
  }

  /// Handles selection of the Quit item by invoking `onQuit`.
  @objc private func quit() {
    onQuit?()
  }

  /// Rebuilds the entire menu from current state, replacing existing items with
  /// toggle, assertions, separator, and quit sections.
  private func rebuildMenu() {
    menu.removeAllItems()
    menu.addItem(toggleMenuItem())
    menu.addItem(.separator())
    addAssertions()
    menu.addItem(.separator())
    menu.addItem(quitMenuItem())
  }

  /// Builds an enabled Turn On/Turn Off item targeting this controller. The
  /// title is derived from the last rendered caffeination state.
  private func toggleMenuItem() -> NSMenuItem {
    let item = NSMenuItem(
      title: isCaffeinated ? "Turn Off" : "Turn On",
      action: #selector(toggleCaffeination),
      keyEquivalent: "")
    item.target = self
    return item
  }

  /// Builds an enabled Quit item targeting this controller with `q` as the
  /// keyboard equivalent.
  private func quitMenuItem() -> NSMenuItem {
    let item = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
    item.target = self
    return item
  }

  /// Appends the Prevent assertion section to `menu`. If assertions exist,
  /// disabled headings and disabled process-name rows are appended; otherwise a
  /// single disabled placeholder item is appended.
  private func addAssertions() {
    let assertions = assertionProvider.currentPreventAssertions()
    guard !assertions.isEmpty else {
      return
    }

    for (index, assertion) in assertions.enumerated() {
      if index > 0 {
        menu.addItem(.separator())
      }

      let heading = NSMenuItem(
        title: assertion.displayName,
        action: nil,
        keyEquivalent: "")
      heading.isEnabled = false
      menu.addItem(heading)

      for processName in assertion.processNames {
        let item = NSMenuItem(title: "  \(processName)", action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
      }
    }
  }
}
