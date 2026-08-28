import Foundation

/// Ce qu'un refus du serveur veut dire, une fois classé.
///
/// La classification existe pour une seule raison : décider quoi FAIRE. Le texte
/// à montrer, lui, ne se reformule jamais — voir `ErreurApi.message`.
public enum GenreErreur: Sendable, Equatable {
    /// Aucune réponse : DNS, tunnel coupé, délai dépassé. Le miroir prend la main.
    case transport
    /// 401, ou la redirection 303 de `check_session` suivie jusqu'à `/login`.
    /// Impose de ressaisir le mot de passe — jamais un simple « réessayer ».
    case authentification
    case requeteInvalide
    case introuvable
    case conflit(ConflitMetier)
    /// 501 — la route existe mais rien n'est câblé derrière. Le geste doit
    /// disparaître de l'écran, pas échouer en silence.
    case nonCable
    case interne
    /// 502 rendu par `harness_proxy.py` : le control plane ne tourne plus sur le
    /// Pi. À ne JAMAIS confondre avec un PC éteint — le message serveur est
    /// rédigé pour l'interdire.
    case harnessInjoignable
    /// Le corps ne correspond pas au contrat. Une panne de client, pas de serveur.
    case contratRompu
    case autre
}

/// Les conflits 409 que le control plane distingue. Chacun appelle une conduite
/// différente à l'écran ; les fondre ferait proposer « réessayer » là où le geste
/// est simplement arrivé trop tard.
public enum ConflitMetier: Sendable, Equatable {
    /// H-56, projet non-git : une équipe est déjà active dessus.
    case projetOccupe
    /// Le mandat a été tranché entre l'affichage de la carte et le clic
    /// (auto-approbation, ou décision depuis un autre écran).
    case mandatDejaTranche
    /// Le projet visé n'existe pas sur la machine du fil.
    case projetAbsentDeLaMachine
    /// La machine est hors ligne, inconnue, ou le fil n'est rattaché à aucune.
    case routageMachine
    case rallongeDejaTranchee
    case rappelIncompatible
    case inspection
    case indetermine
}

/// Un refus du serveur, prêt à afficher.
///
/// `message` est le texte du serveur, MOT POUR MOT. Il nomme le projet, la
/// machine, l'état, et il est écrit pour être lu par un humain devant l'écran.
/// Le remplacer par « une erreur est survenue » a déjà coûté des heures sur ce
/// produit : le mécanisme du refus marchait, sa transmission n'existait pas.
public struct ErreurApi: Error, Sendable, Equatable {
    /// Code HTTP. `0` quand rien n'est revenu (voir `.transport`).
    public let statut: Int
    public let message: String
    public let genre: GenreErreur

    public init(statut: Int, message: String, genre: GenreErreur) {
        self.statut = statut
        self.message = message
        self.genre = genre
    }

    public static func transport(_ message: String) -> ErreurApi {
        ErreurApi(statut: 0, message: message, genre: .transport)
    }

    public static func contratRompu(_ message: String) -> ErreurApi {
        ErreurApi(statut: 0, message: message, genre: .contratRompu)
    }
}

/// Corps d'erreur du control plane (`{ error }`) et du relais (`{ error, message }`).
struct CorpsErreurApi: Decodable {
    let error: String?
    let message: String?

    /// Le relais met la phrase lisible dans `message` et le code dans `error` ;
    /// le control plane, lui, n'a que `error`. Priorité à la phrase.
    var texte: String? {
        if let message, !message.isEmpty { return message }
        if let error, !error.isEmpty { return error }
        return nil
    }
}

public enum ClassementErreur {
    /// Classe une réponse en échec. `corps` peut être vide (502 nu, HTML de login).
    public static func classer(statut: Int, corps: Data) -> ErreurApi {
        let decode = try? JSONDecoder().decode(CorpsErreurApi.self, from: corps)
        let code = decode?.error
        let texte = decode?.texte ?? "HTTP \(statut)"
        return ErreurApi(statut: statut, message: texte, genre: genre(statut: statut, code: code, texte: texte))
    }

    private static func genre(statut: Int, code: String?, texte: String) -> GenreErreur {
        switch statut {
        case 400: return .requeteInvalide
        case 401, 403: return .authentification
        case 404: return .introuvable
        case 409: return .conflit(conflit(texte))
        case 501: return .nonCable
        case 500: return .interne
        case 502: return code == "harness_injoignable" ? .harnessInjoignable : .autre
        default: return .autre
        }
    }

    /// Distingue les conflits sur le TEXTE parce que c'est tout ce que le
    /// serveur envoie : `ErreurApi` côté Bun ne sérialise que `{ error }`, sans
    /// code machine.
    ///
    /// `☠` L'ORDRE EST LA CORRECTION, pas un détail. Un refus de routage est
    /// préfixé par son contexte — « mandat p-1 : la machine « vps » est hors
    /// ligne » — donc un test sur « mandat » placé trop haut l'avalerait et
    /// afficherait « déjà autorisé » sur une équipe qui n'est jamais partie.
    /// Les motifs vont du plus spécifique au plus général, et le mot « machine »
    /// passe AVANT « mandat ».
    public static func conflit(_ brut: String) -> ConflitMetier {
        let t = normaliser(brut)
        if t.contains("h-56") || t.contains("n'est pas un depot git") { return .projetOccupe }
        if t.contains("n'est pas exploitable sur la machine") { return .projetAbsentDeLaMachine }
        if t.contains("machine") || t.contains("inconnue du registre") || t.contains("racine des projets") {
            return .routageMachine
        }
        if t.contains("rallonge") { return .rallongeDejaTranchee }
        if t.contains("rappel") { return .rappelIncompatible }
        if t.contains("mandat") { return .mandatDejaTranche }
        if t.contains("inspection") || t.contains("verdict") { return .inspection }
        return .indetermine
    }

    /// Minuscules, apostrophes unifiées, accents retirés.
    ///
    /// Le serveur mélange `'` et `’` dans une même phrase (`ErreurProjetOccupe`
    /// en porte des deux sortes) et les accents diffèrent selon le message
    /// (« dépôt », « déjà »). Comparer du texte brut casserait au premier
    /// caractère typographique changé côté Pi.
    public static func normaliser(_ brut: String) -> String {
        let sansAccent = brut.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return sansAccent.replacingOccurrences(of: "\u{2019}", with: "'")
    }
}
