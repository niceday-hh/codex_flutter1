import Foundation

// Accessed on one serial background queue by the platform host.
final class LedgerStorage {
  let directory: URL

  init(directory: URL) {
    self.directory = directory
  }

  func file(calendar: Bool) -> URL {
    directory.appendingPathComponent(calendar ? "calendar_state.json" : "app_state.json")
  }

  func load(calendar: Bool) throws -> String? {
    let url = file(calendar: calendar)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try String(contentsOf: url, encoding: .utf8)
  }

  func save(_ raw: String, calendar: Bool) throws {
    let data = Data(raw.utf8)
    guard try JSONSerialization.jsonObject(with: data) is [String: Any] else {
      throw NSError(domain: "SmartBudget", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Expected a JSON object"])
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    // Atomic replacement leaves the previous ledger intact if a write fails.
    try data.write(to: file(calendar: calendar), options: .atomic)
  }
}

