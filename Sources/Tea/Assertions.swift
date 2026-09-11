import Darwin
import Foundation
import IOKit.pwr_mgt

/// Preferred display order for known Prevent assertion types.
private let TYPE_ORDER = [
  "PreventSystemSleep",
  "PreventUserIdleSystemSleep",
  "PreventUserIdleDisplaySleep",
]

/// Processes that currently hold an enabled Prevent assertion of the same type.
struct AssertionGroup {
  /// Raw IOKit assertion type, such as `PreventSystemSleep`.
  let type: String

  /// Owning process names, once per assertion. If a process can no longer be
  /// identified, its PID is displayed instead. Assertion names are not retained.
  let processNames: [String]

  /// Human-readable label for the assertion type. Known Prevent assertion types
  /// are expanded for display; unknown types are returned unchanged.
  var displayName: String {
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
}

/// Supplies current Prevent assertion groups for display in the menu.
protocol AssertionProviding {
  /// Returns current Prevent assertions grouped by assertion type. Implementations
  /// should return an empty array when assertions cannot be read or parsed.
  func currentPreventAssertions() -> [AssertionGroup]
}

/// Reads structured assertions directly from IOKit, without spawning `pmset` or
/// interpreting its mixed-encoding text output. Only enabled Prevent assertions
/// and their owning processes are kept for display.
struct IOKitAssertionProvider: AssertionProviding {
  /// IOKit's assertion property dictionaries, keyed by owning PID.
  typealias Snapshot = [pid_t: [[String: Any]]]

  private let readAssertions: () -> Snapshot?
  private let processName: (pid_t) -> String?

  /// Uses the system APIs by default; callers can supply snapshots and process
  /// names independently for testing. A failed snapshot read returns `nil`.
  init(
    readAssertions: @escaping () -> Snapshot? = copyAssertionsByProcess,
    processName: @escaping (pid_t) -> String? = processNameForPID
  ) {
    self.readAssertions = readAssertions
    self.processName = processName
  }

  /// Reads a fresh snapshot and groups enabled assertions by type. Known types
  /// come first, followed by unknown types alphabetically. Owners are ordered by
  /// PID, and a process holding multiple assertions keeps one row per assertion.
  func currentPreventAssertions() -> [AssertionGroup] {
    guard let snapshot = readAssertions() else { return [] }

    var processNamesByType: [String: [String]] = [:]
    for (pid, assertions) in snapshot.sorted(by: { $0.key < $1.key }) {
      let types = assertions.compactMap { assertion -> String? in
        guard
          let type = assertion[kIOPMAssertionTypeKey] as? String,
          type.hasPrefix("Prevent"),
          let level = assertion[kIOPMAssertionLevelKey] as? NSNumber,
          level.intValue == Int(kIOPMAssertionLevelOn)
        else { return nil }
        return type
      }
      guard !types.isEmpty else { continue }

      let name = processName(pid) ?? "PID \(pid)"
      for type in types {
        processNamesByType[type, default: []].append(name)
      }
    }

    return processNamesByType.keys.sorted(by: assertionTypeSort).map { type in
      AssertionGroup(type: type, processNames: processNamesByType[type] ?? [])
    }
  }
}

/// Copies the native snapshot, transferring its Core Foundation ownership to
/// Swift. Returns `nil` when IOKit cannot supply a usable snapshot.
private func copyAssertionsByProcess() -> IOKitAssertionProvider.Snapshot? {
  var raw: Unmanaged<CFDictionary>?
  guard IOPMCopyAssertionsByProcess(&raw) == kIOReturnSuccess else { return nil }
  return raw?.takeRetainedValue() as? IOKitAssertionProvider.Snapshot
}

/// Resolves the executable name using libproc. A process may exit between the
/// assertion snapshot and this lookup; the provider falls back to its PID.
private func processNameForPID(_ pid: pid_t) -> String? {
  var buffer = [UInt8](repeating: 0, count: 1024)
  let length = buffer.withUnsafeMutableBytes {
    proc_name(pid, $0.baseAddress, UInt32($0.count))
  }
  guard length > 0 else { return nil }
  return String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
}

/// Orders assertion types for display. Known high-value types come first;
/// unknown types are sorted lexicographically after them.
private func assertionTypeSort(_ lhs: String, _ rhs: String) -> Bool {
  let li = TYPE_ORDER.firstIndex(of: lhs) ?? Int.max
  let ri = TYPE_ORDER.firstIndex(of: rhs) ?? Int.max
  return li == ri ? lhs < rhs : li < ri
}
