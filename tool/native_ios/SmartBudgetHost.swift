import UniformTypeIdentifiers

final class SmartBudgetHost: NSObject, FlutterPlugin, UIDocumentPickerDelegate,
                             UIAdaptivePresentationControllerDelegate {
  private let io = DispatchQueue(label: "com.shiguang.smart-budget.io", qos: .userInitiated)
  private let storage: LedgerStorage
  private var pickerResult: FlutterResult?
  private var exporting = false
  private var exportDirectory: URL?

  init(storage: LedgerStorage) {
    self.storage = storage
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("smart_budget", isDirectory: true)
    let host = SmartBudgetHost(storage: LedgerStorage(directory: root))
    for name in ["smart_budget/storage", "smart_budget/voice"] {
      let channel = FlutterMethodChannel(name: name, binaryMessenger: registrar.messenger())
      registrar.addMethodCallDelegate(host, channel: channel)
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "load", "loadCalendar":
      perform(result, code: "READ_FAILED") { try self.storage.load(calendar: call.method == "loadCalendar") }
    case "save", "saveCalendar":
      guard let raw = call.arguments as? String else {
        result(FlutterError(code: "INVALID_DATA", message: "Expected a JSON string", details: nil))
        return
      }
      perform(result, code: "SAVE_FAILED") {
        try self.storage.save(raw, calendar: call.method == "saveCalendar")
        return nil
      }
    case "pickCsv":
      openPicker(export: false, arguments: nil, result: result)
    case "saveCsv":
      openPicker(export: true, arguments: call.arguments as? [String: Any], result: result)
    case "prepare":
      perform(result, code: "VOICE_MODEL_FAILED") { try self.prepareVoice() }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func perform(_ result: @escaping FlutterResult, code: String,
                       operation: @escaping () throws -> Any?) {
    io.async {
      do {
        let value = try operation()
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: code, message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func prepareVoice() throws -> [String: String] {
    guard let folder = Bundle.main.url(forResource: "VoiceAssets", withExtension: nil) else {
      throw failure("Missing bundled voice model; prepare the iOS model before building")
    }
    let manifest = folder.appendingPathComponent("model.json")
    guard let metadata = try JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any],
          let sizes = metadata["sizes"] as? [String: NSNumber] else {
      throw failure("Invalid voice model manifest")
    }
    for name in ["model.int8.onnx", "tokens.txt"] {
      let url = folder.appendingPathComponent(name)
      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      guard let expected = sizes[name], let actual = attributes[.size] as? NSNumber,
            actual.int64Value == expected.int64Value else {
        throw failure("Incomplete voice model: \(name)")
      }
    }
    let records = FileManager.default.temporaryDirectory
      .appendingPathComponent("voice-recordings", isDirectory: true)
    try FileManager.default.createDirectory(at: records, withIntermediateDirectories: true)
    // A new voice session has not started recording yet. Remove abandoned audio only.
    for url in try FileManager.default.contentsOfDirectory(at: records, includingPropertiesForKeys: nil)
      where url.pathExtension == "wav" {
      try? FileManager.default.removeItem(at: url)
    }
    let paths = ["model": folder.appendingPathComponent("model.int8.onnx").path,
                 "tokens": folder.appendingPathComponent("tokens.txt").path,
                 "recordDir": records.path]
    // ONNX can read the immutable bundle directly; no second 227 MB copy is needed.
    return paths
  }

  private func openPicker(export: Bool, arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard pickerResult == nil else {
      result(FlutterError(code: "BUSY", message: "Another file operation is active", details: nil))
      return
    }
    guard let presenter = presentingController(), presenter.viewIfLoaded?.window != nil else {
      result(FlutterError(code: "NO_PRESENTER", message: "No active app window", details: nil))
      return
    }
    pickerResult = result
    exporting = export
    if export {
      guard let content = arguments?["content"] as? String else {
        finishPicker(FlutterError(code: "INVALID_DATA", message: "Missing CSV content", details: nil))
        return
      }
      let requested = arguments?["filename"] as? String ?? "拾光账本.csv"
      let filename = (requested as NSString).lastPathComponent
      guard !filename.isEmpty, filename != ".", filename != ".." else {
        finishPicker(FlutterError(code: "INVALID_DATA", message: "Invalid filename", details: nil))
        return
      }
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
      exportDirectory = directory
      io.async {
        do {
          try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
          let file = directory.appendingPathComponent(filename)
          try Data(content.utf8).write(to: file, options: .atomic)
          DispatchQueue.main.async {
            self.present(UIDocumentPickerViewController(forExporting: [file], asCopy: true), from: presenter)
          }
        } catch {
          DispatchQueue.main.async {
            self.finishPicker(FlutterError(code: "SAVE_FAILED", message: error.localizedDescription, details: nil))
          }
        }
      }
    } else {
      let types: [UTType] = [.commaSeparatedText, .tabSeparatedText, .plainText, .text]
      present(UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true), from: presenter)
    }
  }

  private func present(_ picker: UIDocumentPickerViewController, from presenter: UIViewController) {
    guard presenter.viewIfLoaded?.window != nil, !presenter.isBeingDismissed else {
      finishPicker(FlutterError(code: "NO_PRESENTER", message: "The app window was closed", details: nil))
      return
    }
    picker.delegate = self
    picker.allowsMultipleSelection = false
    picker.presentationController?.delegate = self
    presenter.present(picker, animated: true)
  }

  private func presentingController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }.first { $0.isKeyWindow }
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard pickerResult != nil else { return }
    if exporting { finishPicker(true); return }
    guard let url = urls.first else { finishPicker(nil); return }
    io.async {
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      do {
        let text = try String(contentsOf: url, encoding: .utf8)
        DispatchQueue.main.async { self.finishPicker(text) }
      } catch {
        DispatchQueue.main.async {
          self.finishPicker(FlutterError(code: "READ_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishPicker(exporting ? false : nil)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    finishPicker(exporting ? false : nil)
  }

  private func finishPicker(_ value: Any?) {
    guard let result = pickerResult else { return }
    pickerResult = nil
    if let directory = exportDirectory {
      exportDirectory = nil
      io.async { try? FileManager.default.removeItem(at: directory) }
    }
    result(value)
  }

  private func failure(_ message: String) -> NSError {
    NSError(domain: "SmartBudget", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
  }
}
