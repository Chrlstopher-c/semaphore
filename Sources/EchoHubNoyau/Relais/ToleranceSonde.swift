import Foundation

/// Décide, sur un relevé de statut raté, s'il faut afficher l'échec ou garder
/// le dernier état connu.
///
/// `☠` Pourquoi ce type existe : le bandeau « Machine injoignable » se levait
/// au PREMIER relevé raté, sans mémoire de l'état d'avant. Or le tunnel et le
/// réseau mobile ont des à-coups — un timeout isolé pendant que le PC répond
/// encore affichait une panne qui n'existait pas. Ce défaut préexistait à la
/// fusion dans Echo ; Chris l'a signalé comme « perte de connexion alors qu'il
/// n'y a aucune perte palpable ».
///
/// La règle : une panne PASSAGÈRE (`ErreurRelais.estTransitoire`) n'efface un
/// état déjà connu qu'après `seuil` échecs d'affilée. Une panne durable (jeton
/// refusé, PC éteint, 4xx) s'affiche tout de suite — la relever ne changerait
/// rien. Au démarrage, sans état connu, le premier échec s'affiche aussi :
/// masquer « injoignable » quand on n'a jamais rien su ne rassurerait personne.
///
/// Pur et sans état : toute la mémoire (le compteur) vit chez l'appelant, ce
/// qui rend la décision éprouvable par `swift test`, sans réseau ni appareil.
public enum ToleranceSonde {
    /// Nombre d'échecs transitoires consécutifs tolérés avant de lever le
    /// bandeau. Deux : un à-coup isolé passe inaperçu, une vraie panne se voit
    /// au relevé suivant.
    public static let seuil = 2

    /// Faut-il GARDER le dernier état connu plutôt qu'afficher cet échec ?
    ///
    /// - Parameters:
    ///   - erreurEstTransitoire: l'erreur est-elle une panne passagère de transport.
    ///   - aUnEtatConnu: un statut « prêt » a-t-il déjà été observé.
    ///   - echecsConsecutifs: nombre d'échecs d'affilée, CET échec compris.
    public static func garderDernierEtat(
        erreurEstTransitoire: Bool, aUnEtatConnu: Bool, echecsConsecutifs: Int
    ) -> Bool {
        erreurEstTransitoire && aUnEtatConnu && echecsConsecutifs < seuil
    }
}
