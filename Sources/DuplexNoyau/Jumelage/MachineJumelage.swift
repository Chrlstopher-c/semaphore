import Foundation

/// Où en est la liaison avec un PC. C'est ce que l'écran lit pour savoir quoi
/// montrer : une liste, un champ de code, ou un bouton d'écoute.
public enum EtapeLiaison: Sendable, Equatable {
    /// Rien n'est tenté.
    case repos
    /// `jumelage.demande` envoyé — le PC va afficher un code.
    case demandeEnvoyee
    /// Le PC affiche son code ; Chris le recopie. Le compte d'essais restants
    /// s'affiche à partir du premier refus, pas avant : annoncer « 3 essais » à
    /// quelqu'un qui n'a pas encore tapé, c'est le mettre sous pression pour rien.
    case codeAttendu(essaisRestants: Int)
    case codeEnVerification
    /// `bonjour` envoyé, on attend `bienvenue`.
    case authentification
    case liee(nom: String, sources: [SourceAudio])
    /// Refus définitif : trois codes faux, ou un refus hors jumelage.
    case refusee(raison: String)
    case fermee
}

/// Ce qui arrive à la machine.
public enum EvenementJumelage: Sendable, Equatable {
    /// Le socket vient de s'ouvrir. `jetonConnu` est celui gardé pour CE PC.
    case canalOuvert(jetonConnu: String?)
    case recu(MessagePoste)
    case codeSaisi(String)
    case canalFerme
}

/// Ce que la machine demande au monde extérieur. Elle n'émet rien elle-même :
/// elle est pure, et c'est ce qui la rend éprouvable sous `swift test`.
public enum ActionJumelage: Sendable, Equatable {
    case emettre(MessageTelephone)
    /// Le jeton est à écrire sur le disque, indexé par l'id du PC.
    case conserverJeton(String)
    /// Le jeton gardé ne vaut plus rien — le PC l'a refusé.
    case oublierJeton
    case fermerCanal
}

/// La machine à états du jumelage, telle que `PROTOCOLE.md` la décrit.
///
/// Elle est PURE : elle ne connaît ni socket, ni disque, ni horloge. On lui
/// donne un événement, elle avance son étape et rend la liste des actions à
/// exécuter. Toute la subtilité du jumelage — trois essais, réutilisation du
/// jeton, ré-appariement quand le PC a oublié — se vérifie donc sans appareil.
///
/// `☠` Deux points que le protocole laisse implicites, et qu'on tranche ici SANS
/// inventer de message :
///
/// 1. Après `jumelage.accepte`, on enchaîne sur `bonjour` avec le jeton tout
///    neuf. C'est la seule voie définie vers `bienvenue`, donc vers le nom du PC
///    et la liste de ses sources ; inventer un raccourci créerait une divergence
///    entre les deux implémentations.
/// 2. Un `jumelage.refuse` reçu pendant l'authentification se lit comme « ce
///    jeton ne vaut plus rien » : on l'oublie et on relance un jumelage complet.
///    Sans cette bascule, un PC réinstallé laisserait l'app coincée sur un jeton
///    mort, sans aucun moyen d'en redemander un.
public struct MachineJumelage: Sendable, Equatable {

    /// Trois codes faux consécutifs ferment la connexion.
    public static let essaisAutorises = 3

    public private(set) var etape: EtapeLiaison = .repos
    /// Le nom que le téléphone donne de lui-même au PC, dans `jumelage.demande`.
    public let appareil: String

    private var essaisRestants = MachineJumelage.essaisAutorises

    public init(appareil: String) {
        self.appareil = appareil
    }

    /// Vrai quand la liaison est établie et qu'on peut demander le flux.
    public var etablie: Bool {
        if case .liee = etape { return true }
        return false
    }

    public mutating func recevoir(_ evenement: EvenementJumelage) -> [ActionJumelage] {
        switch evenement {
        case let .canalOuvert(jetonConnu):
            return ouvrir(jetonConnu)
        case let .recu(message):
            return traiter(message)
        case let .codeSaisi(code):
            return saisir(code)
        case .canalFerme:
            if case .refusee = etape { return [] }
            etape = .fermee
            return []
        }
    }

    // MARK: - Les trois entrées

    private mutating func ouvrir(_ jetonConnu: String?) -> [ActionJumelage] {
        essaisRestants = Self.essaisAutorises
        guard let jeton = jetonConnu, !jeton.isEmpty else {
            etape = .demandeEnvoyee
            return [.emettre(.jumelageDemande(appareil: appareil))]
        }
        etape = .authentification
        return [.emettre(.bonjour(jeton: jeton))]
    }

    /// `☠` Le code est normalisé AVANT d'être envoyé : un clavier iOS glisse
    /// volontiers une espace ou un chiffre arabe oriental. Un code mal formé
    /// consommerait un des trois essais pour rien — on le refuse ici, sans
    /// toucher au compteur.
    private mutating func saisir(_ code: String) -> [ActionJumelage] {
        guard case .codeAttendu = etape else { return [] }
        let propre = code.filter(\.isNumber)
        guard propre.count == Cadence.longueurCode else { return [] }
        etape = .codeEnVerification
        return [.emettre(.jumelageCode(code: propre))]
    }

    private mutating func traiter(_ message: MessagePoste) -> [ActionJumelage] {
        switch message {
        case .jumelageAttente:
            etape = .codeAttendu(essaisRestants: essaisRestants)
            return []
        case let .jumelageAccepte(jeton):
            etape = .authentification
            return [.conserverJeton(jeton), .emettre(.bonjour(jeton: jeton))]
        case let .jumelageRefuse(raison):
            return refuser(raison)
        case let .bienvenue(nom, sources):
            etape = .liee(nom: nom, sources: sources)
            return []
        case .etat, .battement:
            return []
        }
    }

    /// Le refus n'a pas le même sens selon l'étape : pendant la vérification
    /// d'un code il coûte un essai, pendant l'authentification il condamne le
    /// jeton, ailleurs il est définitif.
    private mutating func refuser(_ raison: String) -> [ActionJumelage] {
        switch etape {
        case .codeEnVerification:
            essaisRestants -= 1
            guard essaisRestants > 0 else {
                etape = .refusee(raison: raison)
                return [.fermerCanal]
            }
            etape = .codeAttendu(essaisRestants: essaisRestants)
            return []
        case .authentification:
            etape = .demandeEnvoyee
            return [.oublierJeton, .emettre(.jumelageDemande(appareil: appareil))]
        default:
            etape = .refusee(raison: raison)
            return [.fermerCanal]
        }
    }
}
