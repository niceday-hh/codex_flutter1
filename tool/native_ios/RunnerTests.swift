import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  private var root: URL!
  private var storage: LedgerStorage!

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    storage = LedgerStorage(directory: root)
  }

  override func tearDownWithError() throws {
    if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
  }

  func testLedgerSurvivesNewStorageInstanceAndKeepsCalendarSeparate() throws {
    XCTAssertNil(try storage.load(calendar: false))
    let ledger = #"{"entries":[{"note":"午饭，牛肉面\n加辣","amount":28.5}],"monthlyBudget":3000}"#
    let calendar = #"{"automatic":true,"holidays":{}}"#
    try storage.save(ledger, calendar: false)
    try storage.save(calendar, calendar: true)
    let reopened = LedgerStorage(directory: root)
    XCTAssertEqual(try reopened.load(calendar: false), ledger)
    XCTAssertEqual(try reopened.load(calendar: true), calendar)
  }

  func testInvalidSaveLeavesPreviousLedgerIntact() throws {
    let original = #"{"entries":[],"hideAmounts":true}"#
    try storage.save(original, calendar: false)
    for invalid in ["{broken", "[]", "null"] {
      XCTAssertThrowsError(try storage.save(invalid, calendar: false))
      XCTAssertEqual(try storage.load(calendar: false), original)
    }
  }

  func testWriteFailureIsReported() throws {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let file = root.appendingPathComponent("not-a-directory")
    try Data().write(to: file)
    XCTAssertThrowsError(try LedgerStorage(directory: file).save("{}", calendar: false))
  }
}
