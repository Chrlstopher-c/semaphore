import Foundation

/// Les trois états qu'un écran dépendant du réseau doit distinguer, et le
/// quatrième qui n'en est pas un : le vide.
///
/// Repris tel quel de la discipline de Sillon (`EtatChargement`) : un écran qui
/// ne sait pas dire « je charge », « c'est vide » et « ça a raté » finit par
/// afficher un tourniquet muet dans les trois cas.
public enum EtatChargement<Contenu: Sendable>: Sendable {
    case chargement
    case pret(Contenu)
    case vide
    case echec(String)

    public var contenu: Contenu? {
        if case .pret(let valeur) = self { return valeur }
        return nil
    }
}
