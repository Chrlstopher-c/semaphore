import Foundation

/// Ce qu'une équipe a consommé : le contexte et l'argent. Les deux chiffres sur
/// lesquels on tranche « est-ce que je la laisse continuer ».
public enum ConsommationEquipe {

    /// Seuils de contexte → ton d'alerte, définis UNE fois.
    ///
    /// `☠` La jauge et la tuile lisent le même chiffre : deux seuils divergents
    /// feraient dire deux choses au même pourcentage, et l'écran perdrait le
    /// droit d'être cru. ≥ 75 % l'atterrissage est urgent, ≥ 50 % il se prépare,
    /// en dessous il n'y a rien à signaler — donc aucune couleur.
    public static func tonContexte(_ pourcentage: Int) -> TonEquipe {
        if pourcentage >= 75 { return .alerte }
        if pourcentage >= 50 { return .veille }
        return .neutre
    }

    /// `☠` Sans relevé, `ctx` vaut 0 côté serveur (`pourcentageContexte` refuse
    /// d'extrapoler). Afficher « 0 % » ferait lire « il reste tout le contexte »
    /// là où la vérité est « on ne sait pas » — et c'est là-dessus qu'on décide
    /// d'un atterrissage. Le mot remplace donc le chiffre.
    public static func mesure(_ tokens: TokensContexteApi) -> Bool {
        tokens.utilises != nil
    }

    public static func contexteLisible(_ mission: MissionApi) -> String {
        mesure(mission.ctxTokens) ? "\(mission.ctx) %" : "non mesuré"
    }

    /// « 24,3 K / 200 K », ou l'absence dite en toutes lettres.
    public static func tokensLisibles(_ tokens: TokensContexteApi) -> String {
        guard let utilises = tokens.utilises else { return "aucun relevé reçu" }
        guard let maximum = tokens.max else { return abrege(utilises) }
        return "\(abrege(utilises)) / \(abrege(maximum))"
    }

    public static func abrege(_ tokens: Int) -> String {
        guard tokens >= 1000 else { return "\(tokens)" }
        let dixiemes = Int((Double(tokens) / 100).rounded())
        let entier = dixiemes / 10
        let reste = dixiemes % 10
        return reste == 0 ? "\(entier) K" : "\(entier),\(reste) K"
    }

    /// Les postes RÉELLEMENT chargés, et à part ceux qui sont annoncés sans
    /// l'être.
    ///
    /// `☠` Un poste DIFFÉRÉ ne compte pas dans le total : les additionner ferait
    /// dépasser le total réel de plus du double. Mesuré le 23/07 : sur une
    /// mission à 10 %, ~24 K sont du socle présent dès le premier token (prompt
    /// système, outils, CLAUDE.md, skills) et le reste est du travail réel.
    /// C'est sur cette distinction qu'on décide d'un atterrissage.
    public static func ventilation(
        _ postes: [PosteContexteApi]
    ) -> (charges: [PosteContexteApi], differes: [PosteContexteApi]) {
        let retenus = postes.filter { $0.tokens > 0 && $0.nom != "Free space" }
        return (retenus.filter { !$0.differe }, retenus.filter(\.differe))
    }

    /// Les paliers auxquels le harness déclenche une inspection (`harness-state.js`).
    public static let seuilsInspection: [Double] = [12, 30, 50, 70, 100, 120, 150, 170, 200]

    /// `nil` = tous les paliers sont passés. Ce n'est pas une alerte : c'est une
    /// échéance, et aucun montant n'est mauvais en soi.
    public static func prochainSeuil(_ cout: Double) -> Double? {
        seuilsInspection.first { $0 > cout }
    }

    /// « 12,34 $ ». `☠` Tolère l'absence de mesure : un montant non fini
    /// s'affiche « — », jamais un faux 0,00 $ qui laisserait croire à une
    /// dépense mesurée.
    public static func montant(_ valeur: Double) -> String {
        guard valeur.isFinite else { return "—" }
        let centimes = Int((valeur * 100).rounded())
        let unites = centimes / 100
        let reste = abs(centimes % 100)
        return "\(unites),\(DureeLisible.deuxChiffres(reste)) $"
    }
}
