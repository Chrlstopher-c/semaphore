import Foundation

// Responsabilité : fusion pure des événements d'un fil (ajout en direct, rattrapage, page ancienne), sans doublon,
// dans l'ordre des `seq`. Aucun état : le modèle de l'app garde le résultat.

public enum FusionFil {
    /// Ajoute `evt` en queue si son `seq` dépasse le dernier du fil ; sinon le fil rend tel quel.
    public static func ajouter(_ evt: EvenementDate, au fil: [EvenementDate]) -> [EvenementDate] {
        guard evt.seq > (fil.last?.seq ?? Int.min) else { return fil }
        return fil + [evt]
    }

    /// Réunit deux listes : un exemplaire par `seq` (le premier rencontré gagne), trié par `seq`.
    public static func fusionner(_ fil: [EvenementDate], _ suite: [EvenementDate]) -> [EvenementDate] {
        var parSeq: [Int: EvenementDate] = [:]
        for evt in fil + suite where parSeq[evt.seq] == nil {
            parSeq[evt.seq] = evt
        }
        return parSeq.keys.sorted().compactMap { parSeq[$0] }
    }
}
