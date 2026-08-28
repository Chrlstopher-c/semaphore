// La garde biométrique des gestes engageants.
//
// `☠` C'est un garde d'INTERFACE, pas une clé : rien n'est chiffré derrière,
// et le miroir reste lisible dès l'appareil déverrouillé. Sa seule fonction est
// d'empêcher qu'un mandat parte d'une poche ou d'une main tierce. C'est aussi
// pourquoi Vigie ne demande PAS Face ID au lancement — ça annulerait l'ouverture
// instantanée sur un téléphone consulté trente fois par jour, sans rien protéger
// de plus.
#if canImport(SwiftUI)
import Foundation
import LocalAuthentication
import VigieNoyau

enum GardeFaceID {

    enum Verdict: Sendable, Equatable {
        case accordee
        /// Refus explicite, ou biométrie indisponible sur cet appareil.
        case refusee(String)
    }

    /// `☠` `deviceOwnerAuthentication` et non `…WithBiometrics` : le repli code
    /// est indispensable. Face ID échoue derrière un masque, dans le noir, ou
    /// après cinq essais — et une décision doit rester possible dans ces cas.
    static func exiger(_ motif: String) async -> Verdict {
        let contexte = LAContext()
        contexte.localizedCancelTitle = "Annuler"
        var probleme: NSError?
        guard contexte.canEvaluatePolicy(.deviceOwnerAuthentication, error: &probleme) else {
            let raison = probleme?.localizedDescription ?? "aucune garde disponible sur cet appareil"
            Trace.info("decisions", "garde indisponible : \(raison)")
            return .refusee(raison)
        }
        do {
            let accordee = try await contexte.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: motif)
            return accordee ? .accordee : .refusee("authentification refusée")
        } catch {
            return .refusee(error.localizedDescription)
        }
    }
}
#endif
