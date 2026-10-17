// Icono de PoxiDrop con la receta de los logos Poxi: baldosa oscura, «P» gruesa de bloques con ojo
// cuadrado, sombra escalonada en dos capas y un objeto pixel-art abajo a la derecha (una bandeja).
// Se dibuja en un lienzo de 512 con la cuadrícula del logo de PoxiClicker y se guarda a 1024.
import AppKit

let canvas = 1024
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas, bitsPerSample: 8,
                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("sin contexto") }

func rgb(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func fill(_ pattern: [String], at x0: CGFloat, _ y0: CGFloat, cell: CGFloat, color: NSColor, keys: Set<Character> = ["X"]) {
    let path = NSBezierPath()
    for (y, row) in pattern.enumerated() {
        for (x, char) in row.enumerated() where keys.contains(char) {
            path.appendRect(NSRect(x: x0 + CGFloat(x) * cell, y: y0 + CGFloat(y) * cell, width: cell, height: cell))
        }
    }
    color.setFill()
    path.fill()
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let transform = NSAffineTransform()
transform.translateX(by: 100, yBy: 924)
transform.scaleX(by: 824.0 / 512.0, yBy: -824.0 / 512.0)
transform.concat()

rgb(0x0A111F).setFill()
NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 512, height: 512), xRadius: 92, yRadius: 92).fill()

let unit: CGFloat = 25.6
let p = [
    "XXXXXXXXXX", "XXXXXXXXXX", "XXX....XXX", "XXX....XXX", "XXX....XXX", "XXXXXXXXXX",
    "XXXXXXXXXX", "XXX.......", "XXX.......", "XXX.......", "XXX.......", "XXX.......",
]
fill(p, at: 4 * unit + 24, 3 * unit + 24, cell: unit, color: rgb(0x0F5A44))
fill(p, at: 4 * unit + 12, 3 * unit + 12, cell: unit, color: rgb(0x1E9C74))
fill(p, at: 4 * unit, 3 * unit, cell: unit, color: rgb(0x34E0A8))

// Bandeja con flecha: «A» flecha, «T» bandeja, «D» borde inferior de la bandeja.
let tray = [
    "....A....",
    "....A....",
    "....A....",
    "..AAAAA..",
    "...AAA...",
    "....A....",
    "T.......T",
    "T.......T",
    "TTTTTTTTT",
    "DDDDDDDDD",
]
let cell: CGFloat = 15
let trayX: CGFloat = 318, trayY: CGFloat = 318
fill(tray, at: trayX + 8, trayY + 8, cell: cell, color: rgb(0x2A3350), keys: ["A", "T", "D"])
fill(tray, at: trayX, trayY, cell: cell, color: rgb(0xFFFFFF), keys: ["A"])
fill(tray, at: trayX, trayY, cell: cell, color: rgb(0xD4DEF0), keys: ["T"])
fill(tray, at: trayX, trayY, cell: cell, color: rgb(0x8A9BBE), keys: ["D"])

NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
