// Renders the ismux app icon: a dark squircle holding a miniature of the
// workspace rail — dim slots, an active pill with a glowing agent badge.
// Usage: swift assets/make-icon.swift assets/icon-1024.png
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let size = NSSize(width: 1024, height: 1024)

let image = NSImage(size: size)
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// Squircle canvas (Apple's icon grid: ~100px transparent margin).
let iconRect = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: iconRect, xRadius: 185, yRadius: 185)
NSGradient(
    starting: NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.19, alpha: 1),
    ending: NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.07, alpha: 1)
)?.draw(in: squircle, angle: -90)
NSColor(calibratedWhite: 1, alpha: 0.07).setStroke()
squircle.lineWidth = 4
squircle.stroke()

// The rail capsule.
let capsule = NSBezierPath(
    roundedRect: NSRect(x: 362, y: 208, width: 300, height: 608),
    xRadius: 150, yRadius: 150
)
NSColor(calibratedWhite: 1, alpha: 0.07).setFill()
capsule.fill()
NSColor(calibratedWhite: 1, alpha: 0.10).setStroke()
capsule.lineWidth = 6
capsule.stroke()

func dot(centerX: CGFloat, centerY: CGFloat, diameter: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: NSRect(
        x: centerX - diameter / 2, y: centerY - diameter / 2,
        width: diameter, height: diameter
    )).fill()
}

// Inactive slots above and below.
dot(centerX: 512, centerY: 728, diameter: 64, color: NSColor(calibratedWhite: 1, alpha: 0.25))
dot(centerX: 512, centerY: 296, diameter: 64, color: NSColor(calibratedWhite: 1, alpha: 0.25))

// Active workspace pill.
let pillRect = NSRect(x: 404, y: 404, width: 216, height: 216)
NSColor(calibratedWhite: 1, alpha: 0.16).setFill()
NSBezierPath(roundedRect: pillRect, xRadius: 64, yRadius: 64).fill()

// Its digit.
let rounded = NSFont.systemFont(ofSize: 148, weight: .bold).fontDescriptor.withDesign(.rounded)
let font = rounded.flatMap { NSFont(descriptor: $0, size: 148) }
    ?? NSFont.systemFont(ofSize: 148, weight: .bold)
let digit = NSAttributedString(string: "2", attributes: [
    .font: font,
    .foregroundColor: NSColor.white,
])
let digitSize = digit.size()
digit.draw(at: NSPoint(x: 512 - digitSize.width / 2, y: 512 - digitSize.height / 2))

// Glowing "agent working" badge on the pill's corner.
ctx.saveGState()
let badgeColor = NSColor(calibratedRed: 0.45, green: 0.68, blue: 1.0, alpha: 1)
ctx.setShadow(offset: .zero, blur: 40, color: badgeColor.withAlphaComponent(0.9).cgColor)
dot(centerX: 626, centerY: 626, diameter: 76, color: badgeColor)
ctx.restoreGState()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else { exit(1) }
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
