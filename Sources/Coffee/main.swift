import AppKit

private struct AssertionGroup {
  let type: String
  let entries: [AssertionEntry]
}

private struct AssertionEntry {
  let type: String
  let pid: pid_t
  let process: String
  let name: String

  var displayName: String {
    NSRunningApplication(processIdentifier: pid)?.localizedName ?? process
  }
}

@main
final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private var statusItem: NSStatusItem!
  private var menu: NSMenu!
  private var toggleMenuItem: NSMenuItem!
  private var caffeinate: Process?

  private var isCaffeinated: Bool {
    caffeinate?.isRunning == true
  }

  static func main() {
    let app = NSApplication.shared
    let delegate = App()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: 28)

    toggleMenuItem = NSMenuItem(
      title: "Turn On", action: #selector(toggleCaffeination), keyEquivalent: "")
    toggleMenuItem.target = self

    menu = NSMenu()
    menu.delegate = self
    rebuildMenu()

    if let button = statusItem.button {
      button.target = self
      button.action = #selector(statusItemClicked)
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
      button.toolTip = "Coffee"
    }

    updateStatusItem()
  }

  func applicationWillTerminate(_ notification: Notification) {
    stopCaffeinate()
  }

  func menuWillOpen(_ menu: NSMenu) {
    rebuildMenu()
  }

  func menuDidClose(_ menu: NSMenu) {
    statusItem.menu = nil
  }

  @objc private func statusItemClicked() {
    if NSApp.currentEvent?.type == .rightMouseUp {
      toggleCaffeination()
      return
    }

    // Temporarily attach the menu and ask AppKit to open it. This keeps the
    // standard menu-bar menu positioning/appearance while still letting us
    // use right-click as a one-click caffeinate toggle.
    statusItem.menu = menu
    statusItem.button?.performClick(nil)
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  @objc private func toggleCaffeination() {
    if isCaffeinated {
      stopCaffeinate()
    } else {
      startCaffeinate()
    }

    updateStatusItem()
  }

  private func startCaffeinate() {
    guard !isCaffeinated else { return }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
    process.arguments = ["-is"]
    process.terminationHandler = { [weak self] _ in
      DispatchQueue.main.async {
        self?.caffeinate = nil
        self?.updateStatusItem()
      }
    }

    do {
      try process.run()
      caffeinate = process
    } catch {
      NSApp.presentError(error)
    }
  }

  private func stopCaffeinate() {
    guard let process = caffeinate else { return }
    process.terminationHandler = nil
    process.terminate()
    caffeinate = nil
  }

  private func updateStatusItem() {
    guard let button = statusItem?.button else { return }

    if let image = statusIconImage(caffeinated: isCaffeinated) {
      image.isTemplate = true
      button.image = image
      button.imagePosition = .imageOnly
      button.imageScaling = .scaleNone
      button.title = ""
    } else {
      button.image = nil
      button.title = isCaffeinated ? "☕" : "♨︎"
    }
    button.contentTintColor = nil
    button.toolTip = isCaffeinated ? "Caffeinated" : "Not caffeinated"
    updateMenuItems()
  }

  private func updateMenuItems() {
    toggleMenuItem?.title = isCaffeinated ? "Turn Off" : "Turn On"
  }

  private func rebuildMenu() {
    updateMenuItems()
    menu.removeAllItems()
    menu.addItem(toggleMenuItem)
    menu.addItem(.separator())

    let assertions = currentPreventAssertions()
    if assertions.isEmpty {
      let item = NSMenuItem(title: "No active Prevent assertions", action: nil, keyEquivalent: "")
      item.isEnabled = false
      menu.addItem(item)
    } else {
      for (index, assertion) in assertions.enumerated() {
        if index > 0 {
          menu.addItem(.separator())
        }

        let heading = NSMenuItem(
          title: prettyAssertionName(assertion.type), action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)

        for entry in assertion.entries {
          let item = NSMenuItem(title: "  \(entry.displayName)", action: nil, keyEquivalent: "")
          item.toolTip = entry.name
          item.isEnabled = false
          menu.addItem(item)
        }
      }
    }

    menu.addItem(.separator())
    let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)
  }

  private func currentPreventAssertions() -> [AssertionGroup] {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["-g", "assertions"]
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      return []
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else { return [] }

    var entriesByType: [String: [AssertionEntry]] = [:]
    for line in output.components(separatedBy: .newlines) {
      guard let entry = parseAssertionEntry(line), entry.type.hasPrefix("Prevent") else {
        continue
      }
      entriesByType[entry.type, default: []].append(entry)
    }

    let typeOrder = [
      "PreventSystemSleep", "PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep",
    ]
    return entriesByType.keys.sorted { lhs, rhs in
      (typeOrder.firstIndex(of: lhs) ?? Int.max, lhs) < (
        typeOrder.firstIndex(of: rhs) ?? Int.max, rhs
      )
    }.map { type in
      AssertionGroup(type: type, entries: entriesByType[type] ?? [])
    }
  }

  private func parseAssertionEntry(_ line: String) -> AssertionEntry? {
    let pattern = #"^\s*pid\s+(\d+)\(([^)]+)\):\s+\[[^\]]+\]\s+\S+\s+(\S+)\s+named:\s+\"([^\"]+)\""#
    guard let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
      match.numberOfRanges == 5,
      let pidRange = Range(match.range(at: 1), in: line),
      let processRange = Range(match.range(at: 2), in: line),
      let typeRange = Range(match.range(at: 3), in: line),
      let nameRange = Range(match.range(at: 4), in: line),
      let pid = pid_t(String(line[pidRange]))
    else {
      return nil
    }

    return AssertionEntry(
      type: String(line[typeRange]),
      pid: pid,
      process: String(line[processRange]),
      name: String(line[nameRange])
    )
  }

  private func prettyAssertionName(_ type: String) -> String {
    switch type {
    case "PreventSystemSleep":
      return "Prevent System Sleep"
    case "PreventUserIdleSystemSleep":
      return "Prevent Idle System Sleep"
    case "PreventUserIdleDisplaySleep":
      return "Prevent Display Sleep"
    default:
      return type
    }
  }

  private func statusIconImage(caffeinated: Bool) -> NSImage? {
    let symbol = caffeinated ? "cup.and.saucer.fill" : "cup.and.saucer"
    let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)

    guard
      let symbol = NSImage(systemSymbolName: symbol, accessibilityDescription: "Coffee")?
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
}
