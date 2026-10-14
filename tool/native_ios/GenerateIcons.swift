import AppKit

// Render the existing Android/SVG design with CoreGraphics, without a new icon design.
struct Branding: Decodable {
  let background: String
  let paths: [[String]]
}

func color(_ hex: String) -> CGColor {
  let value = UInt32(hex.dropFirst(), radix: 16)!
  return CGColor(red: CGFloat((value >> 16) & 255) / 255,
                 green: CGFloat((value >> 8) & 255) / 255,
                 blue: CGFloat(value & 255) / 255, alpha: 1)
}

func path(_ source: String) -> CGPath {
  let regex = try! NSRegularExpression(pattern: "[MLHVQCZ]|[-+]?(?:[0-9]*\\.)?[0-9]+")
  let range = NSRange(source.startIndex..., in: source)
  let tokens = regex.matches(in: source, range: range).map {
    String(source[Range($0.range, in: source)!])
  }
  var i = 0
  var point = CGPoint.zero
  var start = CGPoint.zero
  let result = CGMutablePath()
  func number() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i])!) }
  func coordinate() -> CGPoint { CGPoint(x: number(), y: number()) }
  while i < tokens.count {
    let command = tokens[i]; i += 1
    switch command {
    case "M": point = coordinate(); start = point; result.move(to: point)
    case "L": point = coordinate(); result.addLine(to: point)
    case "H": point.x = number(); result.addLine(to: point)
    case "V": point.y = number(); result.addLine(to: point)
    case "Q": let control = coordinate(); point = coordinate(); result.addQuadCurve(to: point, control: control)
    case "C":
      let first = coordinate(); let second = coordinate(); point = coordinate()
      result.addCurve(to: point, control1: first, control2: second)
    case "Z": result.closeSubpath(); point = start
    default: fatalError("Unsupported SVG command: \(command)")
    }
  }
  return result
}

let branding = try JSONDecoder().decode(Branding.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let specifications = [("20x20", 2, "iphone"), ("20x20", 3, "iphone"),
                      ("29x29", 2, "iphone"), ("29x29", 3, "iphone"),
                      ("40x40", 2, "iphone"), ("40x40", 3, "iphone"),
                      ("60x60", 2, "iphone"), ("60x60", 3, "iphone"),
                      ("1024x1024", 1, "ios-marketing")]
var images = [[String: String]]()
for (size, scale, idiom) in specifications {
  let pixels = Int(size.split(separator: "x")[0])! * scale
  let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
    bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  context.setFillColor(color(branding.background))
  context.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
  context.translateBy(x: 0, y: CGFloat(pixels))
  context.scaleBy(x: CGFloat(pixels) / 108, y: -CGFloat(pixels) / 108)
  for item in branding.paths {
    context.setFillColor(color(item[0])); context.addPath(path(item[1])); context.fillPath()
  }
  let image = NSBitmapImageRep(cgImage: context.makeImage()!)
  let filename = "Icon-\(size)@\(scale)x.png"
  try image.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(filename))
  images.append(["size": size, "scale": "\(scale)x", "idiom": idiom, "filename": filename])
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
  .write(to: output.appendingPathComponent("Contents.json"))
