import AppKit
import Carbon.HIToolbox
import ServiceManagement

// Tendina: nasconde le icone della barra dei menu che stanno a sinistra
// della sua lineetta, e le mostra di nuovo con un clic sulla freccia.
//
// Come funziona su macOS 27 (misurato il 23/09/2026 su macOS 27.0, 26A428):
// * le icone non sono più finestre separate, le disegna MenuBarAgent;
// * quando un'icona non ci sta, macOS la sposta nel suo menu di troppo pieno
//   insieme a TUTTE le icone alla sua sinistra, senza lasciare buchi;
// * un'icona più larga di circa metà schermo viene scartata e ignorata.
// Per nascondere basta quindi allargare il separatore oltre lo spazio libero
// ma sotto la metà dello schermo.
//
// Su macOS 26 e precedenti le icone sono ancora finestre separate e vale il
// metodo classico di Hidden Bar e Ice: separatore largo 10.000 punti, che
// spinge fuori dallo schermo tutto quello che ha a sinistra. NON PROVATO qui
// (questo Mac ha macOS 27): è il metodo che quelle app usavano fino a macOS 26.
//
// Si usano solo funzioni pubbliche di Apple, nessun permesso di Accessibilità
// o di registrazione schermo.

enum Preferenze {
    static let richiudiDaSola = "richiudiDaSola"
    static let primoAvvioFatto = "primoAvvioFatto"
}

final class Tendina: NSObject, NSMenuDelegate {
    // Ordine di creazione importante: macOS mette ogni nuova icona a sinistra
    // delle altre, quindi il separatore nasce subito a sinistra della freccia.
    private let freccia = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let separatore = NSStatusBar.system.statusItem(withLength: 10)

    private(set) var chiusa = false
    private var timerRichiusura: Timer?
    private var scorciatoia: EventHotKeyRef?

    private let secondiRichiusura: TimeInterval = 10
    private let larghezzaAperta: CGFloat = 10

    override init() {
        super.init()
        UserDefaults.standard.register(defaults: [Preferenze.richiudiDaSola: true])

        // I nomi fissi fanno ricordare a macOS la posizione scelta dall'utente.
        freccia.autosaveName = "tendina_freccia"
        separatore.autosaveName = "tendina_separatore"

        if let bottone = freccia.button {
            bottone.target = self
            bottone.action = #selector(clicSullaFreccia(_:))
            bottone.sendAction(on: [.leftMouseUp, .rightMouseUp])
            bottone.toolTip = "Tendina: clic per mostrare o nascondere, clic destro per le opzioni"
        }
        separatore.button?.toolTip = "Tendina: le icone a sinistra di questa lineetta vengono nascoste"

        aggiornaAspetto()
        registraScorciatoia()

        NotificationCenter.default.addObserver(
            self, selector: #selector(schermiCambiati),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    // MARK: Aprire e chiudere

    func alterna() {
        chiusa ? apri() : chiudi()
    }

    func apri() {
        timerRichiusura?.invalidate()
        chiusa = false
        aggiornaAspetto()
        if UserDefaults.standard.bool(forKey: Preferenze.richiudiDaSola) {
            programmaRichiusura(fra: secondiRichiusura)
        }
    }

    func chiudi() {
        timerRichiusura?.invalidate()
        guard ordineCorretto() else {
            avviso("La lineetta è a destra della freccia",
                   testo: "Per sicurezza non nascondo niente, altrimenti sparirebbe anche la freccia.\n\nTieni premuto ⌘ e trascina la lineetta │ a sinistra della freccia, poi riprova.")
            return
        }
        chiusa = true
        aggiornaAspetto()
    }

    private func aggiornaAspetto() {
        if chiusa {
            separatore.length = larghezzaChiusa()
            separatore.button?.image = nil
            freccia.button?.image = simbolo("chevron.left", descrizione: "Mostra le icone nascoste")
        } else {
            separatore.length = larghezzaAperta
            separatore.button?.image = lineetta()
            freccia.button?.image = simbolo("chevron.right", descrizione: "Nascondi le icone")
        }
    }

    private func larghezzaChiusa() -> CGFloat {
        if #available(macOS 27, *) {
            // Più largo dello spazio libero accanto alla tacca, ma sotto la metà
            // dello schermo più stretto: oltre quella soglia macOS 27 scarta
            // l'icona (misurato: su 1800 punti funziona a 850, scartata a 950).
            let piuStretto = NSScreen.screens.map { $0.frame.width }.min() ?? 1440
            return (piuStretto * 0.44).rounded()
        } else {
            // Metodo classico fino a macOS 26: fuori da qualunque schermo.
            return 10_000
        }
    }

    // Se la lineetta finisse a destra della freccia, chiudere nasconderebbe
    // anche la freccia. Le posizioni lette sono affidabili solo a tendina aperta.
    private func ordineCorretto() -> Bool {
        guard let lineetta = separatore.button?.window?.frame,
              let bottone = freccia.button?.window?.frame else { return true }
        return lineetta.midX < bottone.midX
    }

    private func programmaRichiusura(fra secondi: TimeInterval) {
        timerRichiusura?.invalidate()
        timerRichiusura = Timer.scheduledTimer(withTimeInterval: secondi, repeats: false) { [weak self] _ in
            guard let self, !self.chiusa else { return }
            // Non chiudere mentre si sta usando un menu o il mouse è sulla barra.
            if self.menuAperto() || self.mouseSullaBarra() {
                self.programmaRichiusura(fra: 3)
            } else {
                self.chiudi()
            }
        }
    }

    private func menuAperto() -> Bool {
        guard let finestre = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let livelloMenu = Int(CGWindowLevelForKey(.popUpMenuWindow))
        return finestre.contains { ($0[kCGWindowLayer as String] as? Int) == livelloMenu }
    }

    private func mouseSullaBarra() -> Bool {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.contains { schermo in
            schermo.frame.contains(mouse) && mouse.y >= schermo.visibleFrame.maxY
        }
    }

    @objc private func schermiCambiati() {
        if chiusa { separatore.length = larghezzaChiusa() }
    }

    // MARK: Clic e menu

    @objc private func clicSullaFreccia(_ sender: Any?) {
        guard let evento = NSApp.currentEvent else { return alterna() }
        let clicDestro = evento.type == .rightMouseUp
            || evento.modifierFlags.contains(.control)
            || evento.modifierFlags.contains(.option)
        if clicDestro {
            mostraMenu()
        } else {
            alterna()
        }
    }

    private func mostraMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let voceAlterna = NSMenuItem(title: chiusa ? "Mostra le icone nascoste" : "Nascondi le icone",
                                     action: #selector(voceAlterna), keyEquivalent: "")
        voceAlterna.target = self
        menu.addItem(voceAlterna)
        menu.addItem(.separator())

        let voceRichiudi = NSMenuItem(title: "Richiudi da sola dopo \(Int(secondiRichiusura)) secondi",
                                      action: #selector(alternaRichiusura), keyEquivalent: "")
        voceRichiudi.target = self
        voceRichiudi.state = UserDefaults.standard.bool(forKey: Preferenze.richiudiDaSola) ? .on : .off
        menu.addItem(voceRichiudi)

        let voceLogin = NSMenuItem(title: "Apri all'accensione del Mac",
                                   action: #selector(alternaAvvioAlLogin), keyEquivalent: "")
        voceLogin.target = self
        voceLogin.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(voceLogin)

        menu.addItem(.separator())
        let voceAiuto = NSMenuItem(title: "Come si usa…", action: #selector(mostraIstruzioni), keyEquivalent: "")
        voceAiuto.target = self
        menu.addItem(voceAiuto)
        let voceEsci = NSMenuItem(title: "Esci da Tendina", action: #selector(esci), keyEquivalent: "q")
        voceEsci.target = self
        menu.addItem(voceEsci)

        // Il menu si aggancia solo per questo clic, poi si stacca:
        // così il clic sinistro resta libero per aprire e chiudere.
        freccia.menu = menu
        freccia.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        freccia.menu = nil
    }

    @objc private func voceAlterna() { alterna() }

    @objc private func alternaRichiusura() {
        let attiva = !UserDefaults.standard.bool(forKey: Preferenze.richiudiDaSola)
        UserDefaults.standard.set(attiva, forKey: Preferenze.richiudiDaSola)
        if attiva, !chiusa { programmaRichiusura(fra: secondiRichiusura) }
        if !attiva { timerRichiusura?.invalidate() }
    }

    @objc private func alternaAvvioAlLogin() {
        let servizio = SMAppService.mainApp
        do {
            if servizio.status == .enabled {
                try servizio.unregister()
            } else {
                try servizio.register()
            }
        } catch {
            avviso("Non riesco a cambiare l'apertura all'accensione",
                   testo: "Tendina deve stare nella cartella Applicazioni.\n\nDettaglio: \(error.localizedDescription)")
        }
    }

    @objc func mostraIstruzioni() {
        avviso("Come si usa Tendina", testo: """
        1. Tieni premuto ⌘ e trascina nella barra le icone che vuoi nascondere, mettendole a sinistra della lineetta │.
        2. Clicca la freccia per nasconderle o mostrarle. Da tastiera: ⌃⌥⌘B.
        3. Clic destro sulla freccia per le opzioni.

        Se la barra è piena, anche a tendina aperta le icone che non ci stanno restano nascoste da macOS (su macOS 27 le trovi nella sua «).

        Se la freccia sparisce: premi ⌃⌥⌘B, oppure riapri Tendina da Spotlight.
        """)
    }

    @objc private func esci() {
        NSApp.terminate(nil)
    }

    // MARK: Scorciatoia da tastiera ⌃⌥⌘B

    // L'API Carbon è vecchia ma è l'unica che registra una scorciatoia
    // globale senza chiedere il permesso di Accessibilità.
    private func registraScorciatoia() {
        var tipo = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let io = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, dati in
            guard let dati else { return noErr }
            let tendina = Unmanaged<Tendina>.fromOpaque(dati).takeUnretainedValue()
            DispatchQueue.main.async { tendina.alterna() }
            return noErr
        }, 1, &tipo, io, nil)

        let id = EventHotKeyID(signature: OSType(0x5444_4E41), id: 1) // "TDNA"
        let esito = RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(cmdKey | optionKey | controlKey),
                                        id, GetApplicationEventTarget(), 0, &scorciatoia)
        if esito != noErr {
            NSLog("Tendina: scorciatoia ⌃⌥⌘B non registrata (errore \(esito))")
        }
    }

    // MARK: Grafica

    private func simbolo(_ nome: String, descrizione: String) -> NSImage? {
        let configurazione = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let immagine = NSImage(systemSymbolName: nome, accessibilityDescription: descrizione)?
            .withSymbolConfiguration(configurazione)
        immagine?.isTemplate = true
        return immagine
    }

    private func lineetta() -> NSImage {
        let immagine = NSImage(size: NSSize(width: 2, height: 14), flipped: false) { area in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: area, xRadius: 1, yRadius: 1).fill()
            return true
        }
        immagine.isTemplate = true
        return immagine
    }

    private func avviso(_ titolo: String, testo: String) {
        NSApp.activate(ignoringOtherApps: true)
        let finestra = NSAlert()
        finestra.messageText = titolo
        finestra.informativeText = testo
        finestra.addButton(withTitle: "OK")
        finestra.runModal()
    }
}

final class Applicazione: NSObject, NSApplicationDelegate {
    private var tendina: Tendina?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let tendina = Tendina()
        self.tendina = tendina

        if !UserDefaults.standard.bool(forKey: Preferenze.primoAvvioFatto) {
            UserDefaults.standard.set(true, forKey: Preferenze.primoAvvioFatto)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { tendina.mostraIstruzioni() }
        } else {
            // Si parte chiusi, dopo che macOS ha sistemato le icone nella barra.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { tendina.chiudi() }
        }
    }

    // Riaprire Tendina mentre è già aperta (Spotlight, Finder) mostra tutto:
    // è la via d'uscita se la freccia è finita tra le icone nascoste.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        tendina?.apri()
        return false
    }
}

let app = NSApplication.shared
let delegato = Applicazione()
app.delegate = delegato
app.setActivationPolicy(.accessory)
app.run()
