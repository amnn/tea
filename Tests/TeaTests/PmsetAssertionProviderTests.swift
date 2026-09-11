import Foundation
import Testing
@testable import Tea

struct PmsetAssertionProviderTests {
  @Test(arguments: [Array("'".utf8), Array("’".utf8), [0xD5]])
  func parsesAssertionsDespiteDeviceNameEncoding(_ apostrophe: [UInt8]) {
    let groups = PmsetAssertionProvider.parsePreventAssertions(
      assertionsOutput(apostrophe: apostrophe))

    #expect(groups.map(\.type) == [
      "PreventSystemSleep", "PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep",
    ])
    #expect(groups.map(\.processNames) == [
      ["caffeinate"], ["powerd", "caffeinate"], ["Vidéos"],
    ])
  }

  @Test func replacesMalformedBytesInProcessNames() {
    var output = Data("   pid 123(Test".utf8)
    output.append(0xFF)
    output.append(contentsOf: "App): [0x123] 00:00:01 PreventSystemSleep named: \"test\"".utf8)

    let groups = PmsetAssertionProvider.parsePreventAssertions(output)
    #expect(groups.map(\.type) == ["PreventSystemSleep"])
    #expect(groups.map(\.processNames) == [["Test\u{FFFD}App"]])
  }

  @Test func ignoresOutputWithoutPreventAssertions() {
    #expect(PmsetAssertionProvider.parsePreventAssertions(Data()).isEmpty)
    let output = Data("""
      Assertion status system-wide:
         PreventSystemSleep             0
      Listed by owning process:
         pid 42(WindowServer): [0x123] 00:00:01 UserIsActive named: "HID Activity"
      Kernel Assertions: 0x4=USB
      """.utf8)
    #expect(PmsetAssertionProvider.parsePreventAssertions(output).isEmpty)
  }
}

/// `pmset` can emit a MacRoman apostrophe (0xD5) in a trackpad name on a
/// WindowServer line, even though other fields contain valid UTF-8.
private func assertionsOutput(apostrophe: [UInt8]) -> Data {
  var output = Data("""
    Assertion status system-wide:
       UserIsActive                   1
       PreventSystemSleep             1
       PreventUserIdleSystemSleep     1
       PreventUserIdleDisplaySleep    1
    Listed by owning process:
       pid 42(WindowServer): [0x123] 00:00:01 UserIsActive named: "product:Test
    """.utf8)
  output.append(contentsOf: apostrophe)
  output.append(contentsOf: """
    s Magic Trackpad eventType:11"
      Timeout will fire in 600 secs Action=TimeoutActionRelease
       pid 100(powerd): [0x124] 00:03:07 PreventUserIdleSystemSleep named: "Display is on"
       pid 123(caffeinate): [0x125] 00:01:07 PreventUserIdleSystemSleep named: "caffeinate command-line tool"
      Details: caffeinate asserting forever
       pid 123(caffeinate): [0x126] 00:01:07 PreventSystemSleep named: "caffeinate command-line tool"
       pid 456(Vidéos): [0x127] 00:00:10 PreventUserIdleDisplaySleep named: "Playback"
    Kernel Assertions: 0x4=USB
    """.utf8)
  return output
}
