import Foundation

/// Ce que `GET /health` permet de conclure — et la divergence qu'il révèle.
///
/// `☠` Deux sources parlent du poste de travail et ne disent pas la même chose.
/// `/api/status` l'interroge directement par le websocket du serveur de
/// sessions ; `/health` rend ce que le **control plane** croit du lien H-75
/// (la machine initie, le Pi héberge). Quand elles divergent, ce n'est pas un
/// bruit à lisser : la machine est allumée et son superviseur est tombé — tout
/// le harness répondra « machine absente » sur une machine parfaitement vivante,
/// et l'interface se videra sans dire pourquoi.
public enum EtatChaine: Sendable, Hashable {
    /// La sonde n'a pas abouti : ne rien affirmer.
    case inconnu
    /// Le control plane ne répond pas. Fils, équipes et parc sont hors
    /// d'atteinte quel que soit l'état des machines.
    case controlPlaneMuet
    /// Le poste répond en direct, le control plane ne le voit pas.
    case superviseurTombe
    /// Le control plane répond, le poste n'est pas relié. Régime nominal des
    /// nuits : le poste est simplement éteint.
    case posteDetache
    /// Rien à signaler.
    case saine

    /// Le verdict à partir des deux sources. `posteJoignable` vient de
    /// `/api/status`, `sante` de `/health` — jamais l'inverse.
    public static func lire(sante: SanteApi?, posteJoignable: Bool?) -> EtatChaine {
        guard let sante else { return .inconnu }
        guard sante.ok else { return .controlPlaneMuet }
        guard !sante.pcOnline else { return .saine }
        return posteJoignable == true ? .superviseurTombe : .posteDetache
    }

    /// Le texte à poser sous les yeux, ou `nil` quand il n'y a rien à dire.
    ///
    /// `☠` `.posteDetache` se tait délibérément : un poste éteint la nuit est le
    /// régime attendu, et `SectionPoste` le dit déjà à sa place. Un bandeau de
    /// plus chaque nuit apprend à ne plus lire les bandeaux.
    public var alerte: String? {
        switch self {
        case .controlPlaneMuet:
            return "Le control plane du Pi ne répond pas — fils, équipes et parc "
                + "sont hors d'atteinte tant qu'il est muet."
        case .superviseurTombe:
            return "Le poste répond, mais le control plane ne le voit pas : son "
                + "superviseur est tombé. Le harness dira « machine absente » d'une machine allumée."
        case .inconnu, .posteDetache, .saine:
            return nil
        }
    }
}
