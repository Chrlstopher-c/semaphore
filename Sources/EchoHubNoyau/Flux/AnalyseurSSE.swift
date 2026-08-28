import Foundation

/// Une trame Server-Sent Events complète : le nom d'événement et sa charge.
///
/// EchoHub écrit les deux — `event: fragment` ET `"type": "fragment"` dans le
/// JSON (voir `backend/chat/flux_sse.py`). Ce n'est pas un doublon gratuit :
/// `EventSource` route sur le premier, un client qui lit le corps octet par
/// octet — ce que fait cette app, pour pouvoir annuler — n'a que le second.
/// On garde les deux et c'est le JSON qui tranche : lui seul est présent sur
/// le flux de `/api/inference/generer`, qui n'écrit pas de champ `event:`.
public struct TrameSSE: Sendable, Equatable {
    public let evenement: String?
    /// Les lignes `data:` recollées par des sauts de ligne, comme l'exige la
    /// spécification. Vide quand la trame ne portait que des commentaires.
    public let donnees: String

    public init(evenement: String?, donnees: String) {
        self.evenement = evenement
        self.donnees = donnees
    }
}

/// Découpe un flux SSE reçu par morceaux en trames complètes.
///
/// `☠` Pourquoi un analyseur incrémental et pas un `split` sur la réponse
/// entière : le streaming EST le produit. Un fragment de texte doit s'afficher
/// à l'instant où il arrive, donc l'analyseur reçoit des morceaux de taille
/// arbitraire, coupés N'IMPORTE OÙ — au milieu d'une trame, au milieu d'une
/// ligne, et au milieu d'un caractère UTF-8 multi-octets (un « é » fait deux
/// octets, un emoji quatre). C'est pour ce dernier cas que le tampon est en
/// OCTETS et non en `String` : décoder chaque morceau isolément couperait des
/// caractères en deux et produirait des « � » dans la réponse du modèle.
///
/// Pur, sans réseau, sans `URLSession` : c'est ce qui le rend prouvable par
/// `swift test` sur Linux.
public struct AnalyseurSSE: Sendable {
    /// Séparateur de trames : une ligne vide.
    private static let separateur: [UInt8] = Array("\n\n".utf8)
    /// Garde-fou de boucle bornée : chaque tour consomme au moins un octet de
    /// tampon, donc ce plafond n'est jamais atteint sur un flux sain. Il borne
    /// le pire cas d'un serveur qui inonderait de trames vides.
    private static let tramesMaxParMorceau = 10_000

    private var tampon: [UInt8] = []

    public init() {}

    /// Absorbe un morceau du corps de la réponse et rend les trames devenues
    /// complètes. Rend un tableau vide tant qu'aucune ligne vide n'est arrivée.
    public mutating func absorber(_ octets: some Sequence<UInt8>) -> [TrameSSE] {
        // Les `\r` sont retirés à l'entrée : ils ne servent qu'à la variante
        // CRLF des fins de ligne, et un `\r` littéral ne peut pas apparaître
        // dans une charge JSON (pydantic l'échappe en `\\r`). Les retirer ici
        // dispense de gérer un CRLF coupé entre deux morceaux.
        tampon.append(contentsOf: octets.lazy.filter { $0 != 0x0D })
        var trames: [TrameSSE] = []
        for _ in 0..<Self.tramesMaxParMorceau {
            guard let coupe = premiereCoupe() else { break }
            let brut = Array(tampon[..<coupe])
            tampon.removeFirst(coupe + Self.separateur.count)
            if let trame = Self.analyser(brut) { trames.append(trame) }
        }
        return trames
    }

    /// Rend la trame résiduelle quand le flux se ferme sans ligne vide finale.
    /// Un serveur coupé net ne doit pas faire perdre le dernier fragment reçu.
    public mutating func terminer() -> TrameSSE? {
        defer { tampon.removeAll() }
        return Self.analyser(tampon)
    }

    private func premiereCoupe() -> Int? {
        guard tampon.count >= Self.separateur.count else { return nil }
        for index in 0...(tampon.count - Self.separateur.count)
        where tampon[index] == 0x0A && tampon[index + 1] == 0x0A {
            return index
        }
        return nil
    }

    private static func analyser(_ brut: [UInt8]) -> TrameSSE? {
        guard let texte = String(bytes: brut, encoding: .utf8), !texte.isEmpty else { return nil }
        var evenement: String?
        var donnees: [String] = []
        for ligne in texte.split(separator: "\n", omittingEmptySubsequences: false) {
            // Une ligne commençant par « : » est un commentaire (battement de
            // cœur d'un proxy, typiquement) : ignorée, jamais rendue.
            guard !ligne.hasPrefix(":") else { continue }
            if let valeur = valeur(de: ligne, champ: "event") { evenement = valeur }
            if let valeur = valeur(de: ligne, champ: "data") { donnees.append(valeur) }
        }
        guard evenement != nil || !donnees.isEmpty else { return nil }
        return TrameSSE(evenement: evenement, donnees: donnees.joined(separator: "\n"))
    }

    /// « `champ: valeur` » — l'unique espace qui suit le deux-points appartient
    /// au format, pas à la valeur, et c'est le seul à retirer.
    private static func valeur(de ligne: Substring, champ: String) -> String? {
        guard ligne.hasPrefix(champ + ":") else { return nil }
        let reste = ligne.dropFirst(champ.count + 1)
        return String(reste.hasPrefix(" ") ? reste.dropFirst() : reste)
    }
}
