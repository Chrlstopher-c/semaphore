import Foundation

// Responsabilité : le client du réseau côté téléphone — charte (lecture, édition signée), machines (actions
// signées), demandes d'appairage, codes, ajouts et activité des invités. Passe par les routes du téléphone du
// nœud relié (`/api/reseau/telephone/`) : le nœud n'est qu'un facteur, la vérification se fait ici.

/// Envoie une requête de l'API au nœud relié : (méthode, chemin, corps JSON) → réponse.
public typealias RequeteReseau =
    @Sendable (_ methode: String, _ chemin: String, _ corps: String?) async throws -> ReponseRequete

public actor ClientReseau {
    static let prefixe = "/api/reseau/telephone/"

    private let requete: RequeteReseau
    private let signataire: Signataire
    /// Dernière charte digne vue : la garde anti-retour. Ne recule jamais.
    private var gardee: CharteSignee?
    private let garder: @Sendable (CharteSignee) async -> Void

    public init(
        requete: @escaping RequeteReseau, signataire: Signataire, gardee: CharteSignee?,
        garder: @escaping @Sendable (CharteSignee) async -> Void
    ) {
        self.requete = requete
        self.signataire = signataire
        self.gardee = gardee
        self.garder = garder
    }

    /// La charte courante, reconstruite depuis le texte signé ; la garde avance si la charte la passe.
    public func charte() async throws -> VueCharte {
        let reponse = try await appeler("GET", "charte", nil)
        return try await vue(depuis: reponse).vue
    }

    /// Relit la charte, exige qu'elle soit digne, applique `edition` (qui reçoit `moi` et la date), signe, envoie.
    public func editer(
        demande: String? = nil, _ edition: @Sendable (CharteReseau, String, String) throws -> CharteReseau
    ) async throws -> VueCharte {
        let courante = try await charte()
        guard courante.digne, let base = courante.charte else {
            throw ErreurReseau(message: "charte non vérifiable : rien n'est signé")
        }
        let moi = await signataire.membreSignataire()
        let edite = try edition(base, moi, EditionCharte.horodatage())
        let signee = try await SignatureReseau.signerCharte(edite, par: signataire)
        let corps = try ValeurJSON.objet(corpsCharte(signee, demande: demande)).texteJSON()
        let reponse = try await appeler("POST", "charte", corps)
        let lue = try await vue(depuis: reponse)
        if demande != nil, lue.demande == "introuvable" { throw ErreurReseau(message: "demande introuvable") }
        return lue.vue
    }

    public func machines() async throws -> [MachineReseau] {
        let reponse = try await appeler("GET", "machines", nil)
        return try Self.lireCorps(ReponseMachines.self, reponse.corps).machines
    }

    /// Un ordre signé (charte digne requise) : la machine `membre` le vérifie dans SA charte.
    public func agir(_ action: ActionMachine, sur membre: String) async throws {
        try Self.exigerSegment(membre)
        let courante = try await charte()
        guard courante.digne, let base = courante.charte else {
            throw ErreurReseau(message: "charte non vérifiable : action refusée")
        }
        let ordre = try await SignatureReseau.signerOrdre(
            reseau: base.reseau, cible: membre, action: action, par: signataire, le: EditionCharte.horodatage())
        let corps = try ValeurJSON.objet([
            "ordre": .objet(["texte": .texte(ordre.texte), "signature": .texte(ordre.signature)])
        ]).texteJSON()
        _ = try await appeler("POST", "machines/\(membre)/action", corps)
    }

    public func demandes() async throws -> [DemandeReseau] {
        let reponse = try await appeler("GET", "demandes", nil)
        return try Self.lireCorps(ReponseDemandes.self, reponse.corps).demandes.map(Self.avecEmpreinte)
    }

    /// Accepte une demande : la charte suivante contient le membre (ou l'invité), signée avec la demande.
    public func accepter(_ demande: DemandeReseau, comme accord: AccordDemande) async throws -> VueCharte {
        try await editer(demande: demande.id) { c, moi, le in
            switch accord {
            case .membre(let sorte):
                return try EditionCharte.ajouterMembre(
                    c, auteur: moi, id: demande.membre, nom: demande.nom, sorte: sorte, identite: demande.identite,
                    le: le)
            case .invite(let reglages):
                return try EditionCharte.inviterMembre(
                    c, auteur: moi, id: demande.membre, nom: demande.nom, identite: demande.identite,
                    reglages: reglages, le: le)
            }
        }
    }

    public func refuser(_ demande: DemandeReseau) async throws {
        try Self.exigerSegment(demande.id)
        _ = try await appeler("POST", "demandes/\(demande.id)/refuser", nil)
    }

    public func creerCode() async throws -> CodeReseau {
        let corps = try ValeurJSON.objet(["genre": .texte("meme_proprietaire")]).texteJSON()
        let reponse = try await appeler("POST", "codes", corps)
        return try Self.lireCorps(CodeReseau.self, reponse.corps)
    }

    /// Les ajouts en cours : le nœud répond un tableau, ou `{ ajouts: [...] }`.
    public func ajouts() async throws -> [AjoutReseau] {
        let reponse = try await appeler("GET", "ajouts", nil)
        let forme = try Self.lireCorps(ValeurJSON.self, reponse.corps)
        if case .tableau = forme { return try Self.lireCorps([AjoutReseau].self, reponse.corps) }
        if case .objet = forme { return try Self.lireCorps(ReponseAjouts.self, reponse.corps).ajouts }
        throw ErreurReseau(message: "réponse des ajouts illisible")
    }

    public func lancerAjout(machine: String, nom: String, hote: String, port: Int, utilisateur: String, cle: String)
        async throws
    {
        let ssh: [String: ValeurJSON] = [
            "hote": .texte(hote), "port": .nombre(Double(port)), "utilisateur": .texte(utilisateur), "cle": .texte(cle),
        ]
        let corps = try ValeurJSON.objet(["machine": .texte(machine), "nom": .texte(nom), "ssh": .objet(ssh)])
            .texteJSON()
        _ = try await appeler("POST", "ajouts", corps)
    }

    public func retourAjout(_ machine: String) async throws {
        try Self.exigerSegment(machine)
        _ = try await appeler("POST", "ajouts/\(machine)/retour", nil)
    }

    /// L'activité d'un invité ; nil quand le nœud n'a pas de télémétrie pour lui.
    public func activite(invite membre: String) async throws -> ActiviteInvite? {
        try Self.exigerSegment(membre)
        let reponse = try await appeler("GET", "invites/\(membre)/activite", nil)
        return try Self.lireCorps(ReponseActivite.self, reponse.corps).activite
    }

    // MARK: - Internes

    private func appeler(_ methode: String, _ route: String, _ corps: String?) async throws -> ReponseRequete {
        let chemin = Self.prefixe + route
        let reponse: ReponseRequete
        do { reponse = try await requete(methode, chemin, corps) } catch {
            Trace.erreur("reseau", "\(methode) \(chemin) : échec de la requête", error)
            throw error
        }
        guard (200..<300).contains(reponse.statut) else { throw Self.erreurDeStatut(reponse) }
        return reponse
    }

    /// Lit la vue de la charte d'une réponse ; la garde avance si la charte reçue est digne.
    private func vue(depuis reponse: ReponseRequete) async throws -> (vue: VueCharte, demande: String?) {
        let lu = try Self.lireCorps(ReponseCharte.self, reponse.corps)
        let moi = await signataire.membreSignataire()
        let identite = await signataire.identiteSignataire()
        guard let signee = lu.signee else {
            let vide = VueCharte(
                charte: nil, signee: nil, noeud: lu.noeud, appareil: lu.appareil, chef: lu.chef, digne: false)
            return (vide, lu.demande)
        }
        let charte = try CharteReseau(texte: signee.texte)
        var digne = false
        if SignatureReseau.digne(recue: signee, gardee: gardee) != nil {
            gardee = signee
            await garder(signee)
            digne = SignatureReseau.estChefDigne(charte, moi: moi, identiteMoi: identite)
        }
        let resultat = VueCharte(
            charte: charte, signee: signee, noeud: lu.noeud, appareil: lu.appareil, chef: lu.chef, digne: digne)
        return (resultat, lu.demande)
    }

    private func corpsCharte(_ signee: CharteSignee, demande: String?) -> [String: ValeurJSON] {
        var corps: [String: ValeurJSON] = ["texte": .texte(signee.texte), "signature": .texte(signee.signature)]
        if let demande { corps["demande"] = .texte(demande) }
        return corps
    }

    /// Une demande dont l'identité se lit : son empreinte est calculée ici, jamais lue du serveur.
    static func avecEmpreinte(_ demande: DemandeReseau) -> DemandeReseau {
        var copie = demande
        do {
            let publique = try Chiffrement.Identites.importer(demande.identite)
            copie.empreinte = Chiffrement.Identites.empreinte(publique)
        } catch { Trace.erreur("reseau", "identité de la demande \(demande.id) illisible", error) }
        return copie
    }

    static func erreurDeStatut(_ reponse: ReponseRequete) -> ErreurReseau {
        let corps = try? JSONDecoder().decode(ReponseErreur.self, from: Data(reponse.corps.utf8))
        return ErreurReseau(message: corps?.erreur ?? "erreur \(reponse.statut)", statut: reponse.statut)
    }

    static func lireCorps<T: Decodable>(_ type: T.Type, _ corps: String) throws -> T {
        do { return try JSONDecoder().decode(type, from: Data(corps.utf8)) } catch {
            Trace.erreur("reseau", "réponse du nœud illisible (\(String(describing: type)))", error)
            throw ErreurReseau(message: "réponse du nœud illisible")
        }
    }

    /// Segment de chemin sûr : lettres, chiffres, tiret, souligné.
    static func exigerSegment(_ valeur: String) throws {
        let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
        guard !valeur.isEmpty, valeur.utf8.count <= 64, valeur.allSatisfy({ alphabet.contains($0) }) else {
            throw ErreurReseau(message: "identifiant invalide")
        }
    }
}

private struct ReponseCharte: Decodable {
    let signee: CharteSignee?
    let noeud: String?
    let appareil: String
    let chef: Bool
    let demande: String?
}

private struct ReponseMachines: Decodable { let machines: [MachineReseau] }

private struct ReponseDemandes: Decodable { let demandes: [DemandeReseau] }

private struct ReponseAjouts: Decodable { let ajouts: [AjoutReseau] }

private struct ReponseActivite: Decodable { let activite: ActiviteInvite? }

private struct ReponseErreur: Decodable { let erreur: String? }
