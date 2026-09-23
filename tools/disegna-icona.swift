import AppKit

// Disegna l'icona di Tendina (1024x1024) e la salva come PNG.
// Uso: swift tools/disegna-icona.swift <file.png>
// Segue la griglia delle icone macOS: forma arrotondata di 824 punti
// centrata in una tela di 1024, con 100 punti di margine per l'ombra.

let lato: CGFloat = 1024
let uscita = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icona.png"

func colore(_ esadecimale: UInt32, _ alfa: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((esadecimale >> 16) & 0xFF) / 255,
            green: CGFloat((esadecimale >> 8) & 0xFF) / 255,
            blue: CGFloat(esadecimale & 0xFF) / 255, alpha: alfa)
}

// Coordinate "dall'alto" per ragionare come su un foglio.
func rettangolo(_ x: CGFloat, _ y: CGFloat, _ l: CGFloat, _ a: CGFloat) -> NSRect {
    NSRect(x: x, y: lato - y - a, width: l, height: a)
}

let immagine = NSImage(size: NSSize(width: lato, height: lato), flipped: false) { _ in
    let forma = NSBezierPath(roundedRect: rettangolo(100, 100, 824, 824), xRadius: 185, yRadius: 185)

    // Ombra sotto la forma
    NSGraphicsContext.saveGraphicsState()
    let ombra = NSShadow()
    ombra.shadowColor = colore(0x000000, 0.35)
    ombra.shadowBlurRadius = 28
    ombra.shadowOffset = NSSize(width: 0, height: -12)
    ombra.set()
    colore(0x1D3557).setFill()
    forma.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Sfondo: finestra sul cielo
    NSGraphicsContext.saveGraphicsState()
    forma.addClip()
    NSGradient(starting: colore(0x2F5D9E), ending: colore(0x7FB2F0))!
        .draw(in: rettangolo(100, 100, 824, 824), angle: -90)

    // Tutto il disegno scende di 40 punti per bilanciare il vuoto in basso
    let spostamento = NSAffineTransform()
    spostamento.translateX(by: 0, yBy: -40)
    spostamento.concat()

    // Barra dei menu che passa dietro la tendina: a destra le icone ancora
    // visibili, la prima è la freccia di Tendina
    colore(0x0F1B2D, 0.55).setFill()
    NSBezierPath(rect: rettangolo(100, 352, 824, 104)).fill()
    colore(0xFFFFFF, 0.95).setStroke()
    let freccia = NSBezierPath()
    freccia.move(to: NSPoint(x: 612, y: lato - 380))
    freccia.line(to: NSPoint(x: 586, y: lato - 404))
    freccia.line(to: NSPoint(x: 612, y: lato - 428))
    freccia.lineWidth = 11
    freccia.lineCapStyle = .round
    freccia.lineJoinStyle = .round
    freccia.stroke()
    for x in [668, 760] {
        colore(0xFFFFFF, 0.9).setFill()
        NSBezierPath(roundedRect: rettangolo(CGFloat(x), 380, 48, 48), xRadius: 13, yRadius: 13).fill()
    }

    // Tessuto della tendina, abbassato sulla parte sinistra
    let tessuto = rettangolo(160, 200, 380, 430)
    NSGraphicsContext.saveGraphicsState()
    let ombraTenda = NSShadow()
    ombraTenda.shadowColor = colore(0x0A1426, 0.35)
    ombraTenda.shadowBlurRadius = 24
    ombraTenda.shadowOffset = NSSize(width: 10, height: -6)
    ombraTenda.set()
    colore(0xE9B547).setFill()
    NSBezierPath(rect: tessuto).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: colore(0xF8DC7E), ending: colore(0xE9B547))!
        .draw(in: tessuto, angle: -90)
    colore(0xC9932E, 0.40).setStroke()
    for y in stride(from: 286, through: 580, by: 86) {
        let riga = NSBezierPath()
        riga.move(to: NSPoint(x: 160, y: lato - CGFloat(y)))
        riga.line(to: NSPoint(x: 540, y: lato - CGFloat(y)))
        riga.lineWidth = 5
        riga.stroke()
    }

    // Barra in fondo al tessuto e cordino
    colore(0xA8711C).setFill()
    NSBezierPath(roundedRect: rettangolo(148, 616, 404, 36), xRadius: 18, yRadius: 18).fill()
    colore(0xF4EBDD).setStroke()
    let cordino = NSBezierPath()
    cordino.move(to: NSPoint(x: 350, y: lato - 652))
    cordino.line(to: NSPoint(x: 350, y: lato - 712))
    cordino.lineWidth = 8
    cordino.stroke()
    colore(0xF4EBDD).setFill()
    NSBezierPath(ovalIn: rettangolo(328, 704, 44, 44)).fill()

    // Rullo in alto, su tutta la larghezza
    NSGradient(colors: [colore(0x4A4F5A), colore(0x8A909C), colore(0x3A3E47)])!
        .draw(in: NSBezierPath(roundedRect: rettangolo(140, 160, 744, 64), xRadius: 32, yRadius: 32), angle: -90)

    NSGraphicsContext.restoreGraphicsState()
    return true
}

guard let dati = immagine.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: dati),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Impossibile creare il PNG")
}
try! png.write(to: URL(fileURLWithPath: uscita))
print("Icona salvata in \(uscita)")
