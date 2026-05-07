import Foundation

/// Preferred display order for known Prevent assertion types.
private let TYPE_ORDER = [
  "PreventSystemSleep",
  "PreventUserIdleSystemSleep",
  "PreventUserIdleDisplaySleep",
]

/// Processes that currently hold a Prevent assertion of the same `pmset` type.
struct AssertionGroup {
  /// Raw assertion type from `pmset`, such as `PreventSystemSleep`. All process
  /// names in `processNames` were reported on lines containing this type.
  let type: String

  /// Process names reported by `pmset` for `type`. Only the process name is kept;
  /// PID and assertion names are intentionally discarded.
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

/// Reads and parses `/usr/bin/pmset -g assertions` output.
///
/// This provider keeps only the data needed by the UI: Prevent assertion type and
/// process name. It intentionally ignores PID, assertion ID, and assertion name.
struct PmsetAssertionProvider: AssertionProviding {
  /// Runs `pmset`, extracts Prevent assertion lines, and groups process names by
  /// assertion type. Groups are returned in a stable display order, with unknown
  /// types sorted after known types by their raw name.
  func currentPreventAssertions() -> [AssertionGroup] {
    guard let output = pmsetAssertionsOutput() else { return [] }

    var processNamesByType: [String: [String]] = [:]
    for line in output.components(separatedBy: .newlines) {
      guard let entry = parsePreventAssertion(line) else { continue }
      processNamesByType[entry.type, default: []].append(entry.processName)
    }

    return processNamesByType.keys.sorted(by: assertionTypeSort).map { type in
      AssertionGroup(type: type, processNames: processNamesByType[type] ?? [])
    }
  }
}

/// Returns stdout from `/usr/bin/pmset -g assertions`, or `nil` if the command
/// cannot be launched or its output is not UTF-8.
private func pmsetAssertionsOutput() -> String? {
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
    return nil
  }

  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  return String(data: data, encoding: .utf8)
}

/// Parses a single `pmset` assertion line. The line may contain leading
/// whitespace, but must be a `pid ... (process): ... Prevent...` line. Returns
/// the Prevent assertion type and process name, or `nil` for unrelated lines.
private func parsePreventAssertion(_ line: String) -> (type: String, processName: String)? {
  let trimmed = line.trimmingCharacters(in: .whitespaces)

  guard trimmed.hasPrefix("pid "),
    let lo = trimmed.firstIndex(of: "("),
    let hi = trimmed.range(of: "):")?.lowerBound,
    lo < hi,
    let type = trimmed.split(whereSeparator: { $0.isWhitespace }).first(where: {
      $0.hasPrefix("Prevent")
    })
  else {
    return nil
  }

  return (
    type: String(type),
    processName: String(trimmed[trimmed.index(after: lo)..<hi])
  )
}

/// Orders assertion types for display. Known high-value types come first;
/// unknown types are sorted lexicographically after them.
private func assertionTypeSort(_ lhs: String, _ rhs: String) -> Bool {
  let li = TYPE_ORDER.firstIndex(of: lhs) ?? Int.max
  let ri = TYPE_ORDER.firstIndex(of: rhs) ?? Int.max
  return li < ri
}
