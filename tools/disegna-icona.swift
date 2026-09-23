import AppKit

// Disegna l'icona di Tendina (1024x1024) e la salva come PNG.
// Uso: swift tools/disegna-icona.swift <file.png>
//
// Una finestra con la tendina abbassata a metà, in bianco su fondo blu.
// Il blu è il colore di sistema di macOS 27.0 (NSColor.systemBlue, aspetto
// chiaro, letto il 23/09/2026): #0088FF. La sfumatura va da un po' più chiaro
// in alto al colore pieno in basso, come le icone di Apple.
// Segue la griglia delle icone macOS: forma arrotondata di 824 punti
// centrata in una tela di 1024, con 100 punti di margine per l'ombra.

let lato: CGFloat = 1024
let uscita = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icona.png"
let blu: UInt32 = 0x0088FF

func colore(_ esadecimale: UInt32, _ alfa: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((esadecimale >> 16) & 0xFF) / 255,
            green: CGFloat((esadecimale >> 8) & 0xFF) / 255,
            blue: CGFloat(esadecimale & 0xFF) / 255, alpha: alfa)
}

func mescola(_ a: NSColor, _ b: NSColor, _ quanto: CGFloat) -> NSColor {
    let x = a.usingColorSpace(.sRGB)!, y = b.usingColorSpace(.sRGB)!
    return NSColor(srgbRed: x.redComponent + (y.redComponent - x.redComponent) * quanto,
                   green: x.greenComponent + (y.greenComponent - x.greenComponent) * quanto,
                   blue: x.blueComponent + (y.blueComponent - x.blueComponent) * quanto, alpha: 1)
}

// Coordinate "dall'alto" per ragionare come su un foglio.
func rettangolo(_ x: CGFloat, _ y: CGFloat, _ l: CGFloat, _ a: CGFloat) -> NSRect {
    NSRect(x: x, y: lato - y - a, width: l, height: a)
}

func arrotondato(_ x: CGFloat, _ y: CGFloat, _ l: CGFloat, _ a: CGFloat, _ raggio: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rettangolo(x, y, l, a), xRadius: raggio, yRadius: raggio)
}

let immagine = NSImage(size: NSSize(width: lato, height: lato), flipped: false) { _ in
    let base = colore(blu)
    let forma = arrotondato(100, 100, 824, 824, 185)

    // Ombra sotto la forma
    NSGraphicsContext.saveGraphicsState()
    let ombra = NSShadow()
    ombra.shadowColor = colore(0x000000, 0.30)
    ombra.shadowBlurRadius = 24
    ombra.shadowOffset = NSSize(width: 0, height: -10)
    ombra.set()
    base.setFill()
    forma.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Sfondo: un solo colore, più chiaro in alto, con un leggero riflesso
    NSGraphicsContext.saveGraphicsState()
    forma.addClip()
    NSGradient(starting: mescola(base, .white, 0.28), ending: mescola(base, .black, 0.10))!
        .draw(in: rettangolo(100, 100, 824, 824), angle: -90)
    NSGradient(starting: colore(0xFFFFFF, 0.18), ending: colore(0xFFFFFF, 0))!
        .draw(in: rettangolo(100, 100, 824, 300), angle: -90)

    // Il simbolo, bianco, con un'ombra morbida per staccarlo dal fondo
    let ombraSimbolo = NSShadow()
    ombraSimbolo.shadowColor = colore(0x000000, 0.15)
    ombraSimbolo.shadowBlurRadius = 14
    ombraSimbolo.shadowOffset = NSSize(width: 0, height: -6)
    ombraSimbolo.set()
    let bianco = colore(0xFFFFFF)

    // Telaio della finestra
    bianco.setStroke()
    let telaio = arrotondato(236, 236, 552, 552, 64)
    telaio.lineWidth = 40
    telaio.stroke()

    // Tendina abbassata a metà, con la barra in fondo
    // (ritagliata sulla forma interna del telaio, così gli angoli non sporgono)
    NSGraphicsContext.saveGraphicsState()
    arrotondato(256, 256, 512, 512, 44).addClip()
    bianco.withAlphaComponent(0.9).setFill()
    NSBezierPath(rect: rettangolo(256, 256, 512, 250)).fill()
    NSGraphicsContext.restoreGraphicsState()
    bianco.setFill()
    arrotondato(246, 492, 532, 44, 22).fill()

    // Cordino con l'anello
    let cordino = NSBezierPath()
    cordino.move(to: NSPoint(x: 512, y: lato - 536))
    cordino.line(to: NSPoint(x: 512, y: lato - 590))
    cordino.lineWidth = 16
    cordino.lineCapStyle = .round
    cordino.stroke()
    let anello = NSBezierPath(ovalIn: rettangolo(490, 590, 44, 44))
    anello.lineWidth = 14
    anello.stroke()

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
