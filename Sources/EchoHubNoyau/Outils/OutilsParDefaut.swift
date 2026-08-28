import Foundation

/// La sélection d'outils appliquée aux conversations NEUVES.
///
/// `☠` Ce défaut n'existe PAS côté serveur, et ce module ne prétend pas le
/// contraire : `outils_actifs` est une colonne de `chat_reglages`, strictement
/// par conversation. Aucun réglage global nulle part dans le backend. Ce qui
/// existe, c'est que `POST /chat/conversations` accepte un objet `reglages` à
/// la création — l'app pose donc SA sélection au moment où elle crée la
/// conversation, et le serveur n'a rien appris de nouveau. C'est ce qui permet
/// de tenir la contrainte sans toucher à EchoHub v2.
///
/// `☠` Les TROIS états du contrat sont préservés tels quels :
/// `nil` = hériter du registre du PC, `[]` = aucun outil, une liste = ceux-là.
/// Les confondre priverait d'outils une conversation qui n'a jamais choisi, ou
/// en rendrait dix à celle qui les a toutes coupées.
///
/// Une conversation déjà créée n'est jamais touchée : changer le défaut ne
/// réécrit pas l'histoire, il ne vaut que pour la suivante.
public protocol MagasinOutilsParDefaut: Sendable {
    func charger() -> SelectionOutils
    func sauvegarder(_ selection: SelectionOutils)
}

/// Le magasin réel : un fichier JSON à côté des réglages du relais.
///
/// Aucun secret ici, contrairement au jeton : la protection d'écriture est donc
/// la protection ordinaire. Même contrat d'échec que les autres magasins — une
/// lecture ratée se journalise et retombe sur « hériter du registre », l'état
/// le plus sûr, jamais un crash pour un réglage.
public struct MagasinOutilsParDefautDisque: MagasinOutilsParDefaut {
    private let fichier: URL

    public init(dossier: URL) {
        self.fichier = dossier.appendingPathComponent("outils-par-defaut.json")
    }

    public func charger() -> SelectionOutils {
        guard let donnees = try? Data(contentsOf: fichier) else { return SelectionOutils() }
        do {
            return try JSONDecoder().decode(SelectionOutils.self, from: donnees)
        } catch {
            Journal.echec("outils par défaut illisibles, repli sur « tous » : \(error)")
            return SelectionOutils()
        }
    }

    public func sauvegarder(_ selection: SelectionOutils) {
        do {
            let donnees = try JSONEncoder().encode(selection)
            try FileManager.default.createDirectory(
                at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try donnees.write(to: fichier, options: .atomic)
        } catch {
            Journal.echec("échec d'écriture des outils par défaut : \(error)")
        }
    }
}

/// Charge et sauvegarde le défaut, hors du fil principal.
public actor GestionnaireOutilsParDefaut {
    private let magasin: any MagasinOutilsParDefaut
    private var enMemoire: SelectionOutils?

    public init(magasin: any MagasinOutilsParDefaut) {
        self.magasin = magasin
    }

    public func actuels() -> SelectionOutils {
        if let enMemoire { return enMemoire }
        let charges = magasin.charger()
        enMemoire = charges
        return charges
    }

    public func mettreAJour(_ selection: SelectionOutils) {
        enMemoire = selection
        magasin.sauvegarder(selection)
    }
}

extension SelectionOutils {
    /// Comment ce réglage se lit d'un coup d'œil, sans ouvrir la feuille.
    ///
    /// `☠` « Tous » et « 9 sur 9 » ne veulent pas dire la même chose : le
    /// premier suivra le registre du PC quand un dixième outil y sera
    /// enregistré, le second restera à neuf. La phrase doit porter cette
    /// différence, sinon l'interface efface la distinction que le format
    /// préserve.
    public func resume(surTotal total: Int?) -> String {
        guard let outilsActifs else { return "Tous les outils du PC" }
        guard !outilsActifs.isEmpty else { return "Aucun outil" }
        guard let total else { return "\(outilsActifs.count) outils choisis" }
        return "\(outilsActifs.count) sur \(total)"
    }

    /// Une sélection a-t-elle été restreinte ? C'est ce qui décide d'afficher
    /// ou non le rappel au-dessus du composeur : quand rien n'est coupé, le fil
    /// reste nu.
    public var restreinte: Bool { outilsActifs != nil }
}
