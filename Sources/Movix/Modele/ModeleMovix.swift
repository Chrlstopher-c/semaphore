// L'état du monde Movix : l'adresse configurée, persistée. Un seul réglage, pas
// de secret (une adresse LAN n'en est pas un) — donc `UserDefaults` suffit,
// sans le magasin chiffré des mondes qui portent un jeton.
#if canImport(SwiftUI)
import Foundation
import MovixNoyau
import Observation

@Observable
public final class ModeleMovix {
    public private(set) var reglages: ReglagesMovix

    private let cle = "movix.adresse"

    public init() {
        let stockee = UserDefaults.standard.string(forKey: "movix.adresse")
        reglages = ReglagesMovix(adresse: stockee ?? ReglagesMovix.adresseParDefaut)
    }

    /// L'URL à charger, ou `nil` si l'adresse configurée est invalide (l'écran
    /// invite alors à la corriger dans les réglages).
    public var url: URL? { reglages.url }

    public func definir(adresse: String) {
        reglages = ReglagesMovix(adresse: adresse)
        UserDefaults.standard.set(adresse, forKey: cle)
    }
}
#endif
