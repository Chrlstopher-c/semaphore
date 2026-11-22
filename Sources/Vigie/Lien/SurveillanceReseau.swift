// Le chemin réseau de l'iPhone (Network.framework) : tout changement de chemin (Wi-Fi ↔ cellulaire, perte puis
// retour) rappelle `surChangement`, une fois par changement réel. La première lecture n'est qu'une référence.
#if canImport(SwiftUI)
import Foundation
import Network
import VigieNoyau

final class SurveillanceReseau: @unchecked Sendable {
    // `@unchecked` : le moniteur ne reçoit ses mises à jour que sur sa file ; `signatureVue` n'est touché que là.
    private let moniteur = NWPathMonitor()
    private let file = DispatchQueue(label: "vigie.surveillance-reseau")
    private var signatureVue: String?

    init(surChangement: @escaping @Sendable () -> Void) {
        moniteur.pathUpdateHandler = { [weak self] chemin in
            guard let self else { return }
            let nouvelle = Self.signature(chemin)
            let ancienne = self.signatureVue
            self.signatureVue = nouvelle
            if let ancienne, ancienne != nouvelle {
                Trace.info("reseau", "chemin changé (\(nouvelle))")
                surChangement()
            }
        }
        moniteur.start(queue: file)
    }

    deinit {
        moniteur.cancel()
    }

    private static func signature(_ chemin: NWPath) -> String {
        let interfaces = [NWInterface.InterfaceType.wifi, .cellular, .wiredEthernet]
            .filter { chemin.usesInterfaceType($0) }
            .map { "\($0)" }
            .joined(separator: ",")
        return "\(chemin.status)|\(interfaces)"
    }
}
#endif
