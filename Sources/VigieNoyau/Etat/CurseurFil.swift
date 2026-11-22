import Foundation

// Responsabilité : les règles pures du curseur d'un fil (le dernier `seq` vu) face au relais. Chaque nœud numérote
// ses fils à sa façon : un curseur venu d'un autre nœud ne veut rien dire chez celui-ci. Sans réseau ni état.

public enum CurseurFil {
    /// La source qui numérote les fils : le lien direct, ou le nœud visé par l'aiguilleur.
    public static func origine(noeud: String?) -> String {
        guard let noeud else { return "direct" }
        return "noeud:\(noeud)"
    }

    /// La session a été mise à jour après le dernier événement connu : un relais en retard est alors possible.
    public static func sessionPlusRecente(majLe: String, que ts: String) -> Bool {
        guard let session = Format.dateISO(majLe), let dernier = Format.dateISO(ts) else { return false }
        return session > dernier
    }

    /// Le relais a-t-il ce même événement (même `seq`, même `ts`) ? Sinon il a numéroté le fil autrement.
    public static func coherent(_ curseur: EvenementDate, avec relais: [EvenementDate]) -> Bool {
        relais.contains { $0.seq == curseur.seq && $0.ts == curseur.ts }
    }
}
