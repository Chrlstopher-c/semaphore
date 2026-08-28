import Foundation

/// Ce qu'un état d'équipe APPELLE, jamais s'il est « bon ».
///
/// `running`, `idle` et `terminee` n'appellent rien : ils restent neutres, et
/// c'est ce qui rend les trois autres lisibles d'un coup d'œil.
public enum TonEquipe: String, Sendable, Hashable {
    /// Attend une décision humaine.
    case attente
    /// Travaille.
    case actif
    /// Suspendu — ne repartira pas seul.
    case veille
    /// Terminal et subi.
    case alerte
    /// Terminal et voulu.
    case clos
    case neutre
}

/// La lecture d'un `EtatMissionApi`, et rien d'autre.
///
/// `☠` `brut` vient du serveur TEL QUEL et n'est jamais recalculé ici. Le Pi
/// croise `etatHarness` (son autorité) et `etatSdk` (celle du PC) pour le
/// produire ; refaire ce croisement côté client rejoue la panne #30 du projet —
/// deux machines à états qu'on croise dans un client n'ont aucune chance de
/// rester d'accord avec celle qui fait autorité.
public struct EtatEquipe: Sendable, Hashable {
    public let brut: EtatMissionApi

    public init(_ brut: EtatMissionApi) {
        self.brut = brut
    }

    /// En français, pour être lu. Un état inconnu se rend TEL QUEL plutôt que
    /// de disparaître : la liste des états est ouverte côté serveur.
    public var libelle: String {
        switch brut {
        case .requiertAction: return "attend une autorisation"
        case .enCours: return "en cours"
        case .auRepos: return "au repos"
        case .enPause: return "en pause"
        case .echec: return "en échec"
        case .terminee: return "terminée"
        default: return brut.rawValue
        }
    }

    public var ton: TonEquipe {
        switch brut {
        case .requiertAction: return .attente
        case .enCours: return .actif
        case .enPause: return .veille
        case .echec: return .alerte
        case .terminee: return .clos
        default: return .neutre
        }
    }

    /// Le point d'état respire-t-il ? Seul un tour réellement en vol le mérite.
    public var respire: Bool { brut == .enCours }

    /// Un geste de pilotage a-t-il encore un sens ? Une équipe morte n'écoute
    /// plus rien, et un bouton actif dessus ment sur ce qu'il peut faire.
    public var pilotable: Bool { brut != .echec && brut != .terminee }

    public var enPause: Bool { brut == .enPause }

    /// `☠` `requires_action` compte comme un tour EN VOL : le SDK pose cet état
    /// sur une demande d'autorisation, le tour n'est pas fini
    /// (« requires_action on permission prompt, idle on turn end »). C'est même
    /// le cas où couper presse le plus — un lead figé sur une permission qu'on
    /// ne veut pas donner.
    public var tourEnVol: Bool { brut == .enCours || brut == .requiertAction }
}

extension EtatEquipe {
    /// L'âge affiché avec l'état. Un seul des quatre champs est renseigné à la
    /// fois — celui qui correspond à `state` — et ils sont déjà relatifs et
    /// déjà en français côté serveur. On ne fait que leur donner leur verbe.
    public static func anciennete(_ mission: MissionApi) -> String? {
        if let bloque = mission.blockedSince, !bloque.isEmpty {
            return "bloquée depuis \(bloque)"
        }
        if let pause = mission.pausedAgo, !pause.isEmpty {
            return "pausée il y a \(pause)"
        }
        if let repos = mission.idleAgo, !repos.isEmpty {
            return "dernier tour il y a \(repos)"
        }
        if let fin = mission.doneAgo, !fin.isEmpty {
            return "terminée il y a \(fin)"
        }
        return nil
    }
}
