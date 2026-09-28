/// La régulation d'une liaison vers un PC : ce qui décide d'envoyer ou de
/// sauter une image quand le réseau ne suit plus.
///
/// `☠` On ne saute jamais une image au milieu d'un groupe : une image P posée
/// sur une référence manquante se décode en bouillie verte jusqu'à la clé
/// suivante. Dès qu'on saute, on attend la prochaine image clé — et celle-ci
/// passe même un peu en retard, sauf si la liaison est franchement morte.
public struct Regulateur: Sendable, Equatable {
    /// Octets confiés au réseau et pas encore acquittés.
    public private(set) var enVol = 0
    /// Vrai au départ : le PC ne peut rien décoder avant une image clé.
    public private(set) var attendCle = true
    public let plafond: Int

    /// ~1 s de flux au débit le plus haut : au-delà, la latence se voit.
    public init(plafond: Int = 1_000_000) {
        self.plafond = plafond
    }

    public mutating func decider(taille: Int, cle: Bool) -> Bool {
        if cle {
            guard enVol <= plafond * 2 else { return false }
            attendCle = false
        } else {
            guard !attendCle else { return false }
            guard enVol + taille <= plafond else {
                attendCle = true
                return false
            }
        }
        enVol += taille
        return true
    }

    public mutating func acquitter(_ taille: Int) {
        enVol = max(0, enVol - taille)
    }
}
