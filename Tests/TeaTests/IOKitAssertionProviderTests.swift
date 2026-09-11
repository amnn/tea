import Foundation
import IOKit.pwr_mgt
import Testing
@testable import Tea

struct IOKitAssertionProviderTests {
  @Test func groupsEnabledAssertionsByTypeAndPID() {
    var requestedPIDs: [pid_t] = []
    let provider = IOKitAssertionProvider(
      readAssertions: {
        [
          200: [assertion("PreventUserIdleDisplaySleep"), assertion("PreventUserIdleSystemSleep")],
          100: [
            assertion("PreventUserIdleSystemSleep"), assertion("PreventSystemSleep"),
            assertion("PreventUserIdleSystemSleep"),
          ],
        ]
      },
      processName: { pid in
        requestedPIDs.append(pid)
        return pid == 100 ? "caffeinate" : "Vidéos"
      }
    )

    let groups = provider.currentPreventAssertions()
    #expect(groups.map(\.type) == [
      "PreventSystemSleep", "PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep",
    ])
    #expect(groups.map(\.processNames) == [
      ["caffeinate"], ["caffeinate", "caffeinate", "Vidéos"], ["Vidéos"],
    ])
    #expect(requestedPIDs == [100, 200])
  }

  @Test func skipsDisabledUnrelatedAndMalformedAssertions() {
    var requestedPIDs: [pid_t] = []
    let provider = IOKitAssertionProvider(
      readAssertions: {
        [
          42: [
            assertion("PreventSystemSleep", level: Int(kIOPMAssertionLevelOff)),
            assertion("PreventSystemSleep", level: 1),
            assertion("UserIsActive", name: "PreventSystemSleep is not the assertion type"),
            [kIOPMAssertionTypeKey: "PreventSystemSleep"],
            [kIOPMAssertionLevelKey: NSNumber(value: kIOPMAssertionLevelOn)],
            [kIOPMAssertionTypeKey: 123, kIOPMAssertionLevelKey: NSNumber(value: kIOPMAssertionLevelOn)],
            [kIOPMAssertionTypeKey: "PreventSystemSleep", kIOPMAssertionLevelKey: "255"],
            [:],
          ],
          43: [assertion("PreventSystemSleep")],
        ]
      },
      processName: { pid in
        requestedPIDs.append(pid)
        return "kept"
      }
    )

    let groups = provider.currentPreventAssertions()
    #expect(groups.map(\.type) == ["PreventSystemSleep"])
    #expect(groups.map(\.processNames) == [["kept"]])
    #expect(requestedPIDs == [43])
  }

  @Test func preservesUnicodeWithoutParsingAssertionDescriptions() {
    let provider = IOKitAssertionProvider(
      readAssertions: {
        [
          42: [
            assertion("UserIsActive", name: "Test’s Magic Trackpad"),
            assertion("PreventSystemSleep", name: "Lecture — 日本語\nPreventNotAType"),
          ]
        ]
      },
      processName: { _ in "Café 🎬" }
    )

    let groups = provider.currentPreventAssertions()
    #expect(groups.map(\.type) == ["PreventSystemSleep"])
    #expect(groups.map(\.processNames) == [["Café 🎬"]])
  }

  @Test func sortsUnknownPreventTypesAfterKnownTypes() {
    let provider = IOKitAssertionProvider(
      readAssertions: {
        [
          42: [
            assertion("PreventZulu"), assertion("PreventUserIdleDisplaySleep"),
            assertion("PreventAlpha"), assertion("PreventSystemSleep"),
          ]
        ]
      },
      processName: { _ in "owner" }
    )

    let groups = provider.currentPreventAssertions()
    #expect(groups.map(\.type) == [
      "PreventSystemSleep", "PreventUserIdleDisplaySleep", "PreventAlpha", "PreventZulu",
    ])
    #expect(groups.map(\.displayName) == [
      "Prevent System Sleep", "Prevent Display Sleep", "PreventAlpha", "PreventZulu",
    ])
  }

  @Test func nativeProcessLookupReturnsNameOrPIDFallback() throws {
    let pid = getpid()
    let provider = IOKitAssertionProvider(readAssertions: {
      [
        pid: [assertion("PreventSystemSleep")],
        -1: [assertion("PreventSystemSleep")],
      ]
    })

    let group = try #require(provider.currentPreventAssertions().first)
    try #require(group.processNames.count == 2)
    #expect(group.processNames[0] == "PID -1")
    #expect(!group.processNames[1].isEmpty)
    #expect(group.processNames[1] != "PID \(pid)")
  }

  @Test func readsFreshSnapshotsAndHandlesUnavailableData() {
    var snapshot: IOKitAssertionProvider.Snapshot? = [:]
    var readCount = 0
    let provider = IOKitAssertionProvider(
      readAssertions: {
        readCount += 1
        return snapshot
      },
      processName: { _ in "caffeinate" }
    )

    #expect(provider.currentPreventAssertions().isEmpty)
    snapshot = [42: [assertion("PreventSystemSleep")]]
    #expect(provider.currentPreventAssertions().map(\.processNames) == [["caffeinate"]])
    snapshot = [:]
    #expect(provider.currentPreventAssertions().isEmpty)
    snapshot = nil
    #expect(provider.currentPreventAssertions().isEmpty)
    #expect(readCount == 4)
  }
}

private func assertion(
  _ type: String,
  level: Int = Int(kIOPMAssertionLevelOn),
  name: String = ""
) -> [String: Any] {
  [
    kIOPMAssertionTypeKey: type as NSString,
    kIOPMAssertionLevelKey: NSNumber(value: level),
    kIOPMAssertionNameKey: name as NSString,
  ]
}
