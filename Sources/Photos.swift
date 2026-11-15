import AppKit
import CoreGraphics

enum Photos {
    static var folder: URL {
        dataDirectory().appendingPathComponent("snake_photos", isDirectory: true)
    }

    static func load(_ url: URL) -> CGImage? {
        guard let ns = NSImage(contentsOf: url) else { return nil }
        var rect = CGRect(origin: .zero, size: ns.size)
        guard let cg = ns.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
        return draw(cg, width: cg.width, height: cg.height, into: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
    }

    private static func draw(_ img: CGImage, width: Int, height: Int, into rect: CGRect) -> CGImage? {
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.interpolationQuality = .high
        ctx.draw(img, in: rect)
        return ctx.makeImage()
    }

    static func cover(_ img: CGImage, width: Int, height: Int) -> CGImage? {
        let iw = Double(img.width)
        let ih = Double(img.height)
        let s = max(Double(width) / iw, Double(height) / ih)
        let sw = iw * s
        let sh = ih * s
        let rect = CGRect(x: (Double(width) - sw) / 2, y: (Double(height) - sh) / 2, width: sw, height: sh)
        return draw(img, width: width, height: height, into: rect)
    }

    static func prepare(_ kind: String, _ img: CGImage) -> CGImage? {
        if kind == "head_photo" || kind == "fruit_photo" {
            let side = min(kind == "head_photo" ? 512 : 256, img.width, img.height)
            return cover(img, width: side, height: side)
        }
        let longest = max(img.width, img.height)
        if longest > 1920 {
            let s = 1920.0 / Double(longest)
            let w = max(1, Int((Double(img.width) * s).rounded()))
            let h = max(1, Int((Double(img.height) * s).rounded()))
            return draw(img, width: w, height: h, into: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return img
    }

    static func loadSaved(_ kind: String) -> CGImage? {
        guard let name = PHOTO_FILES[kind] else { return nil }
        let url = folder.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path), let img = load(url) else { return nil }
        return prepare(kind, img)
    }

    static func save(_ img: CGImage, _ kind: String) {
        guard let name = PHOTO_FILES[kind] else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let rep = NSBitmapImageRep(cgImage: img)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: folder.appendingPathComponent(name), options: .atomic)
        }
    }
}
