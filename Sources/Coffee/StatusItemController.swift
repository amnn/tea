import AppKit

/// Owns and renders the menu-bar status item.
///
/// This controller creates the `NSStatusItem`, displays the icon/tooltip for
/// the current caffeination state, and translates mouse clicks into callbacks.
/// It does not start processes or build menu contents.
@MainActor
final class StatusItemController: NSObject {

  /// Callback for primary clicks. When set, this is the only action performed
  /// for a primary-click event, and it runs on the main actor.
  var onPrimaryClick: (() -> Void)?

  /// Callback for secondary clicks. When set, this is the only action
  /// performed for a secondary-click event, and it runs on the main actor.
  var onSecondaryClick: (() -> Void)?

  /// AppKit status item owned for this controller's lifetime. After
  /// initialization, its button target/action points at this controller
  /// whenever AppKit provides a button.
  private let statusItem: NSStatusItem

  /// Creates the status item and configures its button to report left- and
  /// right-click mouse-up events. Call on the main actor while `NSApplication`
  /// is running or being launched.
  override init() {
    statusItem = NSStatusBar.system.statusItem(withLength: 28)
    super.init()

    if let button = statusItem.button {
      button.target = self
      button.action = #selector(statusItemClicked)
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
      button.toolTip = "Coffee"
    }
  }

  /// Updates the status item for the current caffeination state.
  ///
  /// `isCaffeinated` is true when this app is preventing sleep via
  /// `caffeinate`. If the status item has a button, its image/title and
  /// tooltip reflect that value after this method returns.
  func render(isCaffeinated: Bool) {
    guard let button = statusItem.button else { return }

    if let image = statusIcon(caffeinated: isCaffeinated) {
      button.image = image
      button.imagePosition = .imageOnly
      button.imageScaling = .scaleNone
      button.title = ""
    } else {
      button.image = nil
      button.title = isCaffeinated ? "☕" : "💤"
    }

    button.contentTintColor = nil
    button.toolTip = isCaffeinated ? "Caffeinated" : "Not caffeinated"
  }

  /// Temporarily attaches and opens a menu from the status item.
  ///
  /// `menu` remains owned by the caller and must stay alive while AppKit
  /// displays it. After this call, `statusItem.menu` is the provided menu
  /// until detached.
  func open(menu: NSMenu) {
    statusItem.menu = menu
    statusItem.button?.performClick(nil)
  }

  /// Detaches any menu from the status item, restoring button click handling.
  /// It is safe to call when no menu is attached.
  func detachMenu() {
    statusItem.menu = nil
  }

  /// Handles AppKit button actions and dispatches to the primary or secondary
  /// click callback based on the current event.
  @objc private func statusItemClicked() {
    if NSApp.currentEvent?.type == .rightMouseUp {
      onSecondaryClick?()
    } else {
      onPrimaryClick?()
    }
  }
}

/// Builds a template image for the status bar. `caffeinated` selects the
/// filled cup symbol when true and the outline cup symbol when false. Returns
/// `nil` when the symbol is unavailable so callers can fall back to text.
private func statusIcon(caffeinated: Bool) -> NSImage? {
  let name = caffeinated ? "cup.and.saucer.fill" : "cup.and.saucer"
  let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)

  guard
    let symbol = NSImage(systemSymbolName: name, accessibilityDescription: "Coffee")?
      .withSymbolConfiguration(config)
  else {
    return nil
  }

  let size = NSSize(width: 21, height: 18)
  let image = NSImage(size: size)

  image.lockFocus()
  symbol.draw(
    at: NSPoint(x: (size.width - symbol.size.width) / 2, y: 2),
    from: NSRect(origin: .zero, size: symbol.size),
    operation: .sourceOver,
    fraction: 1
  )
  image.unlockFocus()

  image.isTemplate = true
  return image
}
