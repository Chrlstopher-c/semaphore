// Responsabilité : le mode vocal d'une session — écoute continue (reconnaissance française sur l'iPhone), envoi
// automatique après un silence, réponse de Claude lue à voix haute pendant qu'elle s'écrit, passer un message,
// couper la voix en parlant. L'agent est prévenu à l'entrée et à la sortie par une annonce dans le message envoyé.
#if canImport(SwiftUI)
@preconcurrency import AVFoundation
import Foundation
import Observation
import Speech
import VigieNoyau

@MainActor
@Observable
final class ModeVocal {
    static let partage = ModeVocal()

    enum Etat: Equatable { case ecoute, envoi, attente, parle }

    private(set) var session: String?
    private(set) var etat = Etat.ecoute
    /// Ce que Chris est en train de dire (pas encore envoyé).
    private(set) var entendu = ""
    /// La phrase de Claude dite en ce moment, et si c'est la voix de la tour (faux : voix de l'iPhone).
    private(set) var phraseLue: String?
    private(set) var voixTour = true

    @ObservationIgnored private(set) var lecteur: LecteurVoix?
    @ObservationIgnored private var moteur: MoteurVocal?
    @ObservationIgnored private weak var modele: ModeleRelais?
    @ObservationIgnored private let reco = ReconnaissanceVocale()
    @ObservationIgnored private var decoupe = DecoupePhrases()
    @ObservationIgnored private var premier = true
    /// Faux après « passer » ou une coupure : le reste de la réponse en cours n'est plus lu.
    @ObservationIgnored private var lireReponse = false
    @ObservationIgnored private var minuterie: Task<Void, Never>?
    /// Sessions dont le prochain message tapé porte l'annonce de sortie.
    @ObservationIgnored private var sortiesAAnnoncer: Set<String> = []
    /// Phrases de la réponse en cours effectivement commencées à voix haute (pour dire où la coupure est tombée).
    @ObservationIgnored private var phrasesDites: [String] = []
    /// Texte lu au moment d'une coupure : le prochain message envoyé le rappelle à l'agent.
    @ObservationIgnored private var coupure: String?

    private init() {}

    var actif: Bool { session != nil }

    func entrer(session id: String, modele: ModeleRelais) async -> String? {
        if actif { sortir() }
        if let refus = await ReconnaissanceVocale.autoriser() { return refus }
        if Dictee.partage.active { Dictee.partage.arreter() }
        let reco = self.reco
        let moteur = MoteurVocal { tampon in reco.ajouter(tampon) }
        do {
            try await moteur.demarrer()
        } catch {
            Trace.erreur("vocal", "démarrage audio", error)
            return "Micro indisponible."
        }
        guard let client = modele.client else { moteur.arreter(); return "Pas connecté au nœud." }
        let lecteur = LecteurVoix(moteur: moteur) { texte in try await client.syntheseFlux(texte) }
        brancher(lecteur, moteur, modele, session: id)
        if let refus = reco.demarrer(surResultat: { [weak self] texte in self?.entendre(texte) }) {
            sortir()
            return refus
        }
        Trace.info("vocal", "mode vocal ouvert")
        return nil
    }

    private func brancher(_ lecteur: LecteurVoix, _ moteur: MoteurVocal, _ modele: ModeleRelais, session id: String) {
        lecteur.surPhrase = { [weak self] phrase, tour in
            self?.phraseLue = phrase
            if let phrase { self?.phrasesDites.append(phrase); self?.voixTour = tour; self?.etat = .parle }
        }
        lecteur.surSilence = { [weak self] in self?.apresLecture() }
        moteur.surReconstruit = { [weak lecteur] in lecteur?.reprendre() }
        self.lecteur = lecteur
        self.moteur = moteur
        self.modele = modele
        session = id
        premier = true
        sortiesAAnnoncer.remove(id)
        lireReponse = false
        decoupe = DecoupePhrases()
        etat = .ecoute
        entendu = ""
        modele.observateurVocal = { [weak self] observation in self?.observer(observation) }
    }

    func sortir() {
        guard let id = session else { return }
        minuterie?.cancel()
        reco.arreter()
        lecteur?.taire()
        moteur?.arreter()
        modele?.observateurVocal = nil
        if !premier { sortiesAAnnoncer.insert(id) }
        lecteur = nil
        moteur = nil
        session = nil
        phraseLue = nil
        entendu = ""
        Trace.info("vocal", "mode vocal fermé")
    }

    /// Passer : la voix se tait et le reste de cette réponse ne sera pas lu.
    func passer() {
        lireReponse = false
        lecteur?.taire()
        etat = .ecoute
    }

    /// Le message tapé après la sortie du mode porte l'annonce de sortie (une seule fois).
    func prefixer(_ texte: String, session id: String) -> String {
        guard sortiesAAnnoncer.remove(id) != nil else { return texte }
        return ReglesVocales.apresSortie(texte)
    }

    // MARK: - Écoute

    private func entendre(_ texte: String) {
        guard actif else { return }
        if lecteur?.parle == true {
            guard ReglesVocales.couperLecture(entendu: texte, phraseLue: phraseLue) else { return }
            Trace.info("vocal", "coupure : Chris parle")
            coupure = phrasesDites.joined(separator: " ")
            passer()
        }
        entendu = texte
        armerEnvoi()
    }

    private func armerEnvoi() {
        minuterie?.cancel()
        minuterie = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ReglesVocales.silenceFinDeTour))
            guard !Task.isCancelled else { return }
            await self?.envoyer()
        }
    }

    /// La voix s'est tue : l'écho éventuel entendu pendant la lecture est jeté.
    private func apresLecture() {
        guard actif else { return }
        etat = .ecoute
        if entendu.isEmpty { reco.recommencer() }
    }

    private func envoyer() async {
        let texte = entendu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = session, let modele, ReglesVocales.mots(texte).count > 0 else { return }
        entendu = ""
        reco.recommencer()
        etat = .envoi
        var message = ReglesVocales.message(texte, premier: premier)
        if let dit = coupure { message = ReglesVocales.apresCoupure(message, dit: dit) }
        if let erreur = await modele.envoyer(message, a: id) {
            Trace.erreur("vocal", "envoi : \(erreur)")
            entendu = texte
            etat = .ecoute
            return
        }
        premier = false
        coupure = nil
        phrasesDites = []
        decoupe = DecoupePhrases()
        lireReponse = true
        if etat == .envoi { etat = .attente }
    }

    // MARK: - Réponse de Claude

    private func observer(_ observation: ObservationVocale) {
        guard let id = session, let modele, lireReponse else { return }
        let lu = modele.sourceLecture(id)
        switch observation {
        case .delta(let s, let bloc, let texte) where s == lu:
            dire(decoupe.ajouter(texte, bloc: bloc))
        case .final(let s, let texte) where s == lu:
            dire(decoupe.finir(texteFinal: texte))
        case .tourFini(let s) where s == lu:
            dire(decoupe.finir(texteFinal: nil))
            decoupe.nouveauTour()
        default:
            break
        }
    }

    private func dire(_ morceaux: [String]) {
        for morceau in morceaux { lecteur?.ajouter(morceau) }
    }
}
#endif
