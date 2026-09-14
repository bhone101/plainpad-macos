import AppKit
import Foundation
let folder = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let pixels = size*scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,pixelsWide: pixels,pixelsHigh: pixels,bitsPerSample: 8,samplesPerPixel: 4,hasAlpha: true,isPlanar: false,colorSpaceName: .deviceRGB,bytesPerRow: 0,bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let transform = AffineTransform(scale: CGFloat(pixels)/1024); (transform as NSAffineTransform).concat()
        NSColor(calibratedRed: 0.13,green: 0.34,blue: 0.39,alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 40,y: 40,width: 944,height: 944),xRadius: 210,yRadius: 210).fill()
        NSColor(calibratedWhite: 0.98,alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 228,y: 158,width: 568,height: 708),xRadius: 38,yRadius: 38).fill()
        NSColor(calibratedRed: 0.18,green: 0.46,blue: 0.49,alpha: 1).setStroke()
        for (y,width) in [(690,390),(570,390),(450,390),(330,230)] {
            let p = NSBezierPath(); p.lineWidth = 26; p.lineCapStyle = .round
            p.move(to: NSPoint(x: 318,y: y)); p.line(to: NSPoint(x: 318+width,y: y)); p.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png,properties: [:])!.write(to: URL(fileURLWithPath: folder).appendingPathComponent(name))
    }
}
