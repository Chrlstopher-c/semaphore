import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Ouvre un flux de génération et rend ses événements au fil de l'eau.
///
/// `☠` C'est LE point du projet où une erreur ne se voit pas dans un test : le
/// streaming ne se prouve qu'en le regardant arriver sur l'appareil. D'où la
/// découpe — tout ce qui peut être pur l'est (`AnalyseurSSE`,
/// `LectureEvenement`, `SegmenteurReponse`, tous testés), et il ne reste ici
/// que le strict nécessaire : ouvrir la requête, pousser les octets dans
/// l'analyseur, rendre les événements.
///
/// Le flux ne LANCE jamais : un échec de transport devient un événement
/// `.erreur`, exactement comme le fait le serveur une fois les en-têtes partis.
/// L'écran n'a donc qu'un seul chemin à peindre, pas deux.
public enum FluxGeneration {
    /// Plafond d'octets pour une seule génération. Il ne décrit aucun modèle :
    /// il borne une boucle qui, sans lui, dépend entièrement de ce que le
    /// serveur veut bien envoyer. 64 Mio, c'est plusieurs fois la plus longue
    /// réponse imaginable en tokens.
    public static let plafondOctets = 64 * 1024 * 1024

    public static func ouvrir(
        client: ClientEchoHub, methode: String = "POST", chemin: String, corps: Data?
    ) -> AsyncStream<EvenementFlux> {
        AsyncStream { suite in
            let tache = Task {
                await diffuser(client: client, methode: methode, chemin: chemin, corps: corps, vers: suite)
                suite.finish()
            }
            // L'écran qui referme la conversation annule le flux, donc la
            // requête : sans ça, le PC continuerait de générer dans le vide.
            suite.onTermination = { _ in tache.cancel() }
        }
    }

    private static func diffuser(
        client: ClientEchoHub, methode: String, chemin: String, corps: Data?,
        vers suite: AsyncStream<EvenementFlux>.Continuation
    ) async {
        let requete: URLRequest
        do {
            requete = try await client.requete(methode, chemin, corps: corps)
        } catch let erreur as ErreurRelais {
            suite.yield(erreurFlux(erreur))
            return
        } catch {
            suite.yield(erreurFlux(.injoignable(error.localizedDescription)))
            return
        }
        await lire(requete: requete, chemin: chemin, vers: suite)
    }

    /// Consomme les signaux du collecteur jusqu'à la fin du transfert.
    ///
    /// Boucle bornée par la fin du flux ET par `plafondOctets` : un serveur qui
    /// ne se tairait jamais coupe au plafond, il ne fait pas tourner le
    /// téléphone jusqu'à la batterie vide.
    private static func lire(
        requete: URLRequest, chemin: String, vers suite: AsyncStream<EvenementFlux>.Continuation
    ) async {
        let transfert = SessionSSE.ouvrir(requete)
        let (signaux, tache) = (transfert.signaux, transfert.tache)
        let horloge = HorlogeFlux()
        // Un flux muet est coupé : la coupure devient une erreur de transport, et l'appelant se raccroche.
        let veilleur = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(RegleSilence.periodeSurveillance))
                if horloge.muet(maintenant: Date()) {
                    Journal.echec("flux \(chemin) muet, coupé pour se raccrocher")
                    tache.cancel()
                    return
                }
            }
        }
        defer {
            veilleur.cancel()
            transfert.session.finishTasksAndInvalidate()
        }
        var etat = EtatLecture()
        await withTaskCancellationHandler {
            for await signal in signaux {
                horloge.noter(signal, maintenant: Date())
                guard case .arreter(let erreur) = absorber(
                    signal, dans: &etat, chemin: chemin, vers: suite
                ) else { continue }
                if let erreur { suite.yield(erreurFlux(erreur)) }
                return tache.cancel()
            }
        } onCancel: {
            tache.cancel()
        }
    }

    /// Ce qu'une lecture de flux garde entre deux signaux.
    private struct EtatLecture {
        var analyseur = AnalyseurSSE()
        var total = 0
        /// Le statut d'un refus, retenu au lieu d'être agi tout de suite.
        var statutRefus: Int?
        /// Le corps de ce refus, qui porte `message` et `remediation`.
        var corpsRefus = Data()
    }

    private enum SuiteLecture {
        case continuer
        /// Arrêter le transfert, en émettant cette erreur s'il y en a une.
        case arreter(ErreurRelais?)
    }

    /// `☠` Sur un statut non-2xx, la tâche était annulée IMMÉDIATEMENT — donc le
    /// corps de la réponse, qui porte le message et le remède que le backend a
    /// pris la peine d'écrire pour ce cas exact, n'arrivait jamais. Sur le seul
    /// chemin qui compte — l'envoi d'un message — Chris recevait « Le serveur a
    /// répondu 409. » là où une requête ordinaire lui rendait la phrase. On
    /// retient donc le statut, on laisse le corps s'accumuler, et on tranche à
    /// la fin.
    private static func absorber(
        _ signal: SignalFlux, dans etat: inout EtatLecture, chemin: String,
        vers suite: AsyncStream<EvenementFlux>.Continuation
    ) -> SuiteLecture {
        switch signal {
        case .statut(let statut):
            guard !(200..<300).contains(statut) else { return .continuer }
            Journal.echec("flux \(chemin) refusé : statut \(statut)")
            etat.statutRefus = statut
            return .continuer
        case .octets(let donnees):
            guard etat.statutRefus == nil else { return retenirRefus(donnees, dans: &etat) }
            etat.total += donnees.count
            guard etat.total <= plafondOctets else {
                Journal.echec("flux \(chemin) coupé : plafond d'octets atteint")
                return .arreter(nil)
            }
            rendre(etat.analyseur.absorber(donnees), vers: suite)
            return .continuer
        case .fin(let echec):
            return conclure(echec: echec, etat: &etat, vers: suite)
        }
    }

    /// Un corps d'erreur JSON fait quelques centaines d'octets. Borné quand
    /// même : un serveur qui annoncerait un refus puis déverserait un flux
    /// entier ne doit pas remplir la mémoire du téléphone.
    private static let plafondCorpsRefus = 64 * 1024

    private static func retenirRefus(_ donnees: Data, dans etat: inout EtatLecture) -> SuiteLecture {
        guard etat.corpsRefus.count < plafondCorpsRefus else { return .continuer }
        etat.corpsRefus.append(donnees)
        return .continuer
    }

    private static func conclure(
        echec: String?, etat: inout EtatLecture,
        vers suite: AsyncStream<EvenementFlux>.Continuation
    ) -> SuiteLecture {
        if let statut = etat.statutRefus {
            return .arreter(LectureRefus.erreur(statut: statut, donnees: etat.corpsRefus))
        }
        if let echec { suite.yield(erreurFlux(.injoignable(echec))) }
        if let residu = etat.analyseur.terminer() { rendre([residu], vers: suite) }
        return .continuer
    }

    private static func rendre(
        _ trames: [TrameSSE], vers suite: AsyncStream<EvenementFlux>.Continuation
    ) {
        for trame in trames {
            if let evenement = LectureEvenement.lire(trame) { suite.yield(evenement) }
        }
    }

    private static func erreurFlux(_ erreur: ErreurRelais) -> EvenementFlux {
        let transport: Bool
        if case .injoignable = erreur { transport = true } else { transport = false }
        return .erreur(EvenementErreur(
            code: transport ? EvenementErreur.codeTransport : nil,
            message: erreur.libelle, remediation: erreur.remede
        ))
    }
}

/// Quand un flux est jugé muet (`suivi-flux-regles.ts` du web) : 20 s sans octet une fois le premier reçu,
/// 120 s avant (le serveur prépare encore : chargement, compaction de départ).
public enum RegleSilence {
    public static let silence: TimeInterval = 20
    public static let silenceAvantOctet: TimeInterval = 120
    public static let periodeSurveillance: TimeInterval = 5

    public static func muet(depuis vu: Date, octetsRecus: Bool, maintenant: Date) -> Bool {
        maintenant.timeIntervalSince(vu) >= (octetsRecus ? silence : silenceAvantOctet)
    }

    /// Attente avant de se raccrocher après un échec : 1 s, doublée, plafonnée à 10 s.
    public static func delaiApresEchec(_ echecs: Int) -> TimeInterval {
        min(pow(2, Double(max(0, echecs - 1))), 10)
    }
}

/// L'heure du dernier octet, partagée entre la lecture et le veilleur.
final class HorlogeFlux: @unchecked Sendable {
    private let verrou = NSLock()
    private var vu = Date()
    private var octets = false

    func noter(_ signal: SignalFlux, maintenant: Date) {
        guard case .octets = signal else { return }
        verrou.withLock {
            vu = maintenant
            octets = true
        }
    }

    func muet(maintenant: Date) -> Bool {
        verrou.withLock { RegleSilence.muet(depuis: vu, octetsRecus: octets, maintenant: maintenant) }
    }
}
