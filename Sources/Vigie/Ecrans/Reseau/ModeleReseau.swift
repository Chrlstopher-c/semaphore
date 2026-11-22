// Responsabilité : l'état de Réglages › Réseau — charte (vérifiée et gardée sur l'iPhone), machines, demandes et
// ajouts, relus pendant que l'écran est ouvert ; chaque geste de chef passe par ClientReseau (charte ou ordre signés
// par la clé de cet iPhone). Aucun geste sans lien par l'aiguilleur : le réseau ne se gère que par lui.
#if canImport(SwiftUI)
import Foundation
import Observation
import VigieNoyau

@MainActor @Observable
final class ModeleReseau {
    private(set) var vue: VueCharte?
    private(set) var machines: [MachineReseau] = []
    private(set) var demandes: [DemandeReseau] = []
    private(set) var ajouts: [AjoutReseau] = []
    private(set) var charge = false
    /// Libellé du geste en cours (« Signature… ») : les commandes se grisent pendant ce temps.
    private(set) var enCours: String?
    var erreur: String?

    @ObservationIgnored private var aiguilleur: ClientAiguilleur?
    @ObservationIgnored private var client: ClientReseau?

    var charte: CharteReseau? { vue?.charte }
    /// Chef, ET la charte reçue est digne de signature (garde de l'iPhone passée).
    var chef: Bool { vue?.chef == true && vue?.digne == true }
    /// Chef selon la charte, mais la garde a refusé cette version : on montre pourquoi, on ne signe rien.
    var chefNonVerifie: Bool { vue?.chef == true && vue?.digne == false }
    var moi: String? { vue?.appareil }
    var noeudRelie: String? { vue?.noeud }

    /// Branche (ou débranche) le client du lien par l'aiguilleur ; un nouveau lien refait le client.
    func brancher(_ nouveau: ClientAiguilleur?) {
        guard nouveau !== aiguilleur else { return }
        aiguilleur = nouveau
        client = nouveau.map { Self.client(pour: $0) }
        if nouveau == nil { vue = nil; machines = []; demandes = []; ajouts = [] }
    }

    private static func client(pour aiguilleur: ClientAiguilleur, gardee: CharteSignee? = GardeCharte.lire())
        -> ClientReseau
    {
        ClientReseau(
            requete: { methode, chemin, corps in
                try await aiguilleur.requete(methode: methode, chemin: chemin, corps: corps)
            },
            signataire: aiguilleur, gardee: gardee, garder: { GardeCharte.ecrire($0) })
    }

    /// Relit tout ce que l'écran montre ; demandes et ajouts seulement pour un chef.
    func rafraichir() async {
        guard let client else { return }
        do {
            let lue = try await client.charte()
            vue = lue
            if lue.charte != nil { machines = try await client.machines() }
            if chef {
                demandes = try await client.demandes()
                ajouts = (try? await client.ajouts()) ?? ajouts
            } else {
                demandes = []
            }
            erreur = nil
        } catch {
            erreur = Self.texte(error)
            Trace.erreur("reseau", "réseau non relu", error)
        }
        charge = true
    }

    /// Relit toutes les 4 s tant que la tâche (celle de l'écran) vit.
    func suivre() async {
        while !Task.isCancelled {
            await rafraichir()
            try? await Task.sleep(for: .seconds(4))
        }
    }

    // MARK: - Gestes de chef

    /// Une édition de la charte, signée ici ; vrai si le réseau l'a adoptée.
    @discardableResult
    func editer(
        _ libelle: String, demande: String? = nil,
        _ edition: @escaping @Sendable (CharteReseau, String, String) throws -> CharteReseau
    ) async -> Bool {
        await geste(libelle) { client in
            self.vue = try await client.editer(demande: demande, edition)
        }
    }

    @discardableResult
    func agir(_ action: ActionMachine, sur membre: String) async -> Bool {
        await geste(Self.libelle(action)) { client in try await client.agir(action, sur: membre) }
    }

    @discardableResult
    func accepter(_ demande: DemandeReseau, comme accord: AccordDemande) async -> Bool {
        await geste("Signature…") { client in
            self.vue = try await client.accepter(demande, comme: accord)
            self.demandes.removeAll { $0.id == demande.id }
        }
    }

    func refuser(_ demande: DemandeReseau) async {
        await geste("Refus…") { client in
            try await client.refuser(demande)
            self.demandes.removeAll { $0.id == demande.id }
        }
    }

    func creerCode() async -> CodeReseau? {
        var code: CodeReseau?
        await geste("Code…") { client in code = try await client.creerCode() }
        return code
    }

    @discardableResult
    func lancerAjout(_ f: FicheAjoutServeur) async -> Bool {
        await geste("Installation…") { client in
            try await client.lancerAjout(machine: f.machine, nom: f.nom, hote: f.hote, port: f.port,
                                         utilisateur: f.utilisateur, cle: f.cle)
            self.ajouts = (try? await client.ajouts()) ?? self.ajouts
        }
    }

    func retourAjout(_ machine: String) async {
        await geste("Retour arrière…") { client in try await client.retourAjout(machine) }
    }

    func activite(_ membre: String) async -> ActiviteInvite? {
        guard let client else { return nil }
        return try? await client.activite(invite: membre)
    }

    /// La garde a refusé une charte pourtant bien signée (un chef que l'iPhone ne connaissait pas a signé) :
    /// Chris décide, en connaissance de cause, d'en faire la nouvelle référence.
    func faireConfiance() async {
        guard let aiguilleur, let signee = vue?.signee, SignatureReseau.verifier(signee) != nil else { return }
        GardeCharte.ecrire(signee)
        client = Self.client(pour: aiguilleur, gardee: signee)
        await rafraichir()
    }

    private func geste(_ libelle: String, _ corps: (ClientReseau) async throws -> Void) async -> Bool {
        guard let client else {
            erreur = "Pas de lien par le Pi : le réseau ne se gère que par lui."
            return false
        }
        enCours = libelle
        defer { enCours = nil }
        do {
            try await corps(client)
            erreur = nil
            await rafraichir()
            return true
        } catch {
            erreur = Self.texte(error)
            Trace.erreur("reseau", "geste de chef refusé : \(libelle)", error)
            return false
        }
    }

    private static func texte(_ erreur: Error) -> String {
        (erreur as? LocalizedError)?.errorDescription ?? erreur.localizedDescription
    }

    static func libelle(_ action: ActionMachine) -> String {
        switch action {
        case .arreter: return "Extinction…"
        case .pause: return "Mise en pause…"
        case .reprendre: return "Reprise…"
        case .redemarrer: return "Redémarrage…"
        case .reveiller: return "Réveil…"
        }
    }
}

/// Ce que Chris saisit pour installer un serveur par SSH depuis le nœud relié.
struct FicheAjoutServeur: Sendable {
    var nom = ""
    var hote = ""
    var port = 22
    var utilisateur = ""
    var cle = ""

    /// Identifiant de machine tiré du nom : minuscules, chiffres, tirets (40 au plus).
    var machine: String {
        let plie = nom.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        let tirets = plie.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        let net = String(tirets).split(separator: "-").joined(separator: "-")
        return String(net.prefix(40))
    }

    var complete: Bool {
        !machine.isEmpty && !hote.isEmpty && !utilisateur.isEmpty && cle.hasPrefix("/") && (1...65535).contains(port)
    }
}

/// La dernière charte digne vue par cet iPhone (anti-retour) : une version plus ancienne, ou signée par quelqu'un
/// qui n'était pas chef, ne sera jamais signée par-dessus.
enum GardeCharte {
    private static let cle = "quart.reseau.charteGardee"

    static func lire() -> CharteSignee? {
        guard let brut = UserDefaults.standard.data(forKey: cle) else { return nil }
        return try? JSONDecoder().decode(CharteSignee.self, from: brut)
    }

    static func ecrire(_ signee: CharteSignee) {
        guard let brut = try? JSONEncoder().encode(signee) else { return }
        UserDefaults.standard.set(brut, forKey: cle)
    }
}
#endif
