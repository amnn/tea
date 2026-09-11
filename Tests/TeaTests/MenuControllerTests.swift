import AppKit
import Testing
@testable import Tea

@MainActor
struct MenuControllerTests {
  @Test func menuNeedsUpdateDisplaysNewAssertions() {
    let provider = StubAssertionProvider()
    let controller = MenuController(assertionProvider: provider)

    provider.assertions = [
      AssertionGroup(type: "PreventSystemSleep", processNames: ["caffeinate"]),
      AssertionGroup(type: "PreventUserIdleSystemSleep", processNames: ["powerd", "caffeinate"]),
    ]
    controller.menu.delegate?.menuNeedsUpdate?(controller.menu)

    #expect(controller.menu.items.map(\.title) == [
      "Turn On", "",
      "Prevent System Sleep", "  caffeinate", "",
      "Prevent Idle System Sleep", "  powerd", "  caffeinate", "",
      "Open at Login", "", "Quit",
    ])
    // Once AppKit starts opening the menu, its item instances must stay put.
    let items = controller.menu.items
    controller.menu.delegate?.menuWillOpen?(controller.menu)
    #expect(controller.menu.items == items)
    #expect(provider.readCount == 2)
    for item in controller.menu.items where item.title.hasPrefix("Prevent")
      || item.title.hasPrefix("  ")
    {
      #expect(!item.isEnabled)
      #expect(item.action == nil)
    }
  }

  @Test func menuNeedsUpdateReplacesAndRemovesStaleAssertions() {
    let provider = StubAssertionProvider()
    provider.assertions = [
      AssertionGroup(type: "PreventUserIdleSystemSleep", processNames: ["caffeinate"])
    ]
    let controller = MenuController(assertionProvider: provider)

    provider.assertions = [
      AssertionGroup(type: "PreventUserIdleDisplaySleep", processNames: ["Safari"])
    ]
    controller.menu.delegate?.menuNeedsUpdate?(controller.menu)
    #expect(controller.menu.items.map(\.title) == [
      "Turn On", "", "Prevent Display Sleep", "  Safari", "", "Open at Login", "", "Quit",
    ])

    provider.assertions = []
    controller.menu.delegate?.menuNeedsUpdate?(controller.menu)
    #expect(controller.menu.items.map(\.title) == [
      "Turn On", "", "", "Open at Login", "", "Quit",
    ])
    #expect(provider.readCount == 3)
  }

  @Test func menuRefreshPreservesAppStateAndActions() throws {
    let provider = StubAssertionProvider()
    let controller = MenuController(assertionProvider: provider)
    controller.render(isCaffeinated: true, opensAtLogin: true)

    var actions: [String] = []
    controller.onToggleCaffeination = { actions.append("caffeination") }
    controller.onToggleOpenAtLogin = { actions.append("login") }
    controller.onQuit = { actions.append("quit") }
    controller.menu.delegate?.menuNeedsUpdate?(controller.menu)

    #expect(controller.menu.item(withTitle: "Open at Login")?.state == .on)
    for title in ["Turn Off", "Open at Login", "Quit"] {
      let item = try #require(controller.menu.item(withTitle: title))
      #expect(item.isEnabled)
      #expect(item.target === controller)
      let action = try #require(item.action)
      #expect(NSApplication.shared.sendAction(action, to: item.target, from: item))
    }
    #expect(actions == ["caffeination", "login", "quit"])
  }
}

private final class StubAssertionProvider: AssertionProviding {
  var assertions: [AssertionGroup] = []
  private(set) var readCount = 0

  func currentPreventAssertions() -> [AssertionGroup] {
    readCount += 1
    return assertions
  }
}
