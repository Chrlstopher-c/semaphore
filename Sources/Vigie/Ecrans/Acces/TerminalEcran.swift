// Un vrai terminal sur un appareil du parc, depuis l'iPhone : SwiftTerm (émulateur natif, barre de touches Échap,
// Ctrl, Tab, flèches) relié par WebSocket au relais, qui le branche à un PTY du poste. Shell, ou session tmux.
#if canImport(SwiftUI)
import SwiftTerm
import SwiftUI
import UIKit
import VigieNoyau

struct CibleTerminal: Hashable {
    let machine: String
    var tmux: String?
    var dossier: String?
    let titre: String
}

struct TerminalEcran: View {
    @Environment(ModeleRelais.self) private var modele
    let cible: CibleTerminal
    @State private var lien = LienTerminal()

    var body: some View {
        VueTerminal(lien: lien)
            .background(Color.black)
            .navigationTitle(cible.titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .status) { Text(lien.etat).font(.caption).foregroundStyle(.secondary) }
                ToolbarItem(placement: .primaryAction) {
                    Button("Reconnecter", systemImage: "arrow.clockwise") { lien.ouvrir(modele.client, cible) }
                        .disabled(lien.ouvert)
                }
            }
            .onAppear { lien.ouvrir(modele.client, cible) }
            .onDisappear { lien.fermer() }
    }
}

/// Le fil entre la vue SwiftTerm et le relais. La frappe part en binaire, le redimensionnement en JSON.
@MainActor @Observable
final class LienTerminal {
    private(set) var etat = "connexion…"
    private(set) var ouvert = false
    @ObservationIgnored weak var vue: TerminalView?
    @ObservationIgnored private var tache: URLSessionWebSocketTask?

    func ouvrir(_ client: ClientRelais?, _ cible: CibleTerminal) {
        fermer()
        guard let client else { etat = "non connecté"; return }
        let terminal = vue?.getTerminal()
        let chemin = Route.terminal(cible.machine, tmux: cible.tmux, dossier: cible.dossier,
                                    colonnes: max(terminal?.cols ?? 80, 20), lignes: max(terminal?.rows ?? 24, 5))
        guard let requete = try? client.requeteTerminal(chemin) else { etat = "adresse invalide"; return }
        let tache = client.sessionTerminal.webSocketTask(with: requete)
        self.tache = tache
        etat = "connexion…"
        tache.resume()
        ouvert = true
        Task { await recevoir(tache) }
        Task { await entretenir(tache) }
    }

    /// Un ping toutes les 25 s : sans trafic, le proxy devant le relais coupe la connexion vers 100 s.
    private func entretenir(_ tache: URLSessionWebSocketTask) async {
        while self.tache === tache {
            try? await Task.sleep(for: .seconds(25))
            tache.sendPing { _ in }
        }
    }

    func fermer() {
        tache?.cancel(with: .normalClosure, reason: nil)
        tache = nil
        ouvert = false
    }

    func envoyer(_ octets: ArraySlice<UInt8>) {
        tache?.send(.data(Data(octets))) { erreur in
            if let erreur { Trace.erreur("terminal", "frappe perdue", erreur) }
        }
    }

    func redimensionner(colonnes: Int, lignes: Int) {
        let json = "{\"type\":\"taille\",\"colonnes\":\(colonnes),\"lignes\":\(lignes)}"
        tache?.send(.string(json)) { _ in }
    }

    private func recevoir(_ tache: URLSessionWebSocketTask) async {
        while self.tache === tache {
            do {
                let message = try await tache.receive()
                if etat != "" { etat = "" }
                switch message {
                case .data(let d): vue?.feed(byteArray: [UInt8](d)[...])
                case .string(let s): finir(s)
                @unknown default: break
                }
            } catch {
                if self.tache === tache { etat = "déconnecté"; ouvert = false }
                return
            }
        }
    }

    private func finir(_ json: String) {
        struct Fin: Decodable { let type: String; let message: String?; let code: Int? }
        guard let fin = try? JSONDecoder().decode(Fin.self, from: Data(json.utf8)) else { return }
        etat = fin.type == "fin" ? "terminé (code \(fin.code.map(String.init) ?? "—"))" : (fin.message ?? "erreur")
        ouvert = false
    }
}

private struct VueTerminal: UIViewRepresentable {
    let lien: LienTerminal

    func makeUIView(context: Context) -> TerminalView {
        let vue = TerminalView(frame: .zero, font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular))
        vue.terminalDelegate = context.coordinator
        vue.nativeBackgroundColor = .black
        vue.nativeForegroundColor = UIColor(white: 0.9, alpha: 1)
        lien.vue = vue
        DispatchQueue.main.async { _ = vue.becomeFirstResponder() }
        return vue
    }

    func updateUIView(_ vue: TerminalView, context: Context) {}

    func makeCoordinator() -> Coordinateur { Coordinateur(lien: lien) }

    // SwiftTerm appelle son délégué sur le fil principal (vue UIKit) : la conformité l'affirme au compilateur.
    @MainActor final class Coordinateur: NSObject, @preconcurrency TerminalViewDelegate {
        let lien: LienTerminal
        init(lien: LienTerminal) { self.lien = lien }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            lien.envoyer(data)
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            lien.redimensionner(colonnes: newCols, lignes: newRows)
        }

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            guard let url = URL(string: link) else { return }
            UIApplication.shared.open(url)
        }

        func setTerminalTitle(source: TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func scrolled(source: TerminalView, position: Double) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
        func clipboardCopy(source: TerminalView, content: Data) {
            if let texte = String(data: content, encoding: .utf8) { UIPasteboard.general.string = texte }
        }
    }
}
#endif
