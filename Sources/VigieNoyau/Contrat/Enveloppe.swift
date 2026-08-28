import Foundation

/// L'enveloppe brute de toute LECTURE du control plane (`api-web/enveloppe.ts`).
///
/// Décodée pour être immédiatement traduite en `LectureApi` : c'est ce dernier
/// type qui rend impossible de confondre les trois régimes.
struct EnveloppeApi<Charge: Decodable & Sendable>: Decodable, Sendable {
    let pcOnline: Bool
    let stale: Bool
    let data: Charge?
    let message: String?
}

/// Les trois issues d'une lecture, et rien d'autre.
///
/// Modélisé en somme plutôt qu'en optionnels parce que la distinction est le
/// tout du produit : « PC éteint » est le RÉGIME NOMINAL des nuits, pas une
/// panne. L'écraser en erreur ferait afficher « erreur » la moitié du temps ;
/// l'inverse — présenter un control plane mort comme un PC éteint — enverrait
/// chercher un problème sur la machine de travail pendant que le Pi est muet.
/// Un `Bool` plus un optionnel autoriseraient les deux confusions ; ce type non.
public enum LectureApi<Charge: Decodable & Sendable>: Sendable {
    /// Relevé de l'instant : le harness a répondu en direct.
    case fraiche(Charge)
    /// Le registre persisté du Pi a répondu à la place : les données sont vraies
    /// mais datées. Cause côté serveur : le poste de travail ne répond pas.
    /// `donnees` à `nil` = le Pi ne sait rien non plus sur ce point.
    case datee(donnees: Charge?, message: String?)
    /// Panne réelle, à tous les étages : transport, authentification, 4xx/5xx,
    /// ou corps qui ne respecte pas le contrat.
    case echec(ErreurApi)

    /// La charge, quelle que soit sa fraîcheur. `nil` sur un échec — c'est là
    /// que le miroir prend le relais, jamais un écran vide.
    public var charge: Charge? {
        switch self {
        case .fraiche(let c): return c
        case .datee(let c, _): return c
        case .echec: return nil
        }
    }

    public var erreur: ErreurApi? {
        if case .echec(let e) = self { return e }
        return nil
    }

    /// Ce relevé vient-il de l'instant, ou du registre persisté du Pi ?
    ///
    /// `☠` NE DIT RIEN de la machine qui héberge ce qu'on regarde. Le serveur
    /// marque `stale` **toute** réponse du harness quand le poste de travail
    /// dort, missions du VPS comprises : c'est une propriété DU RELEVÉ, pas du
    /// sujet. Le nom précédent — `pcEnLigne` — invitait à en faire un état
    /// global affiché en permanence, et l'app annonçait « PC éteint » sur un fil
    /// qui tournait sur le VPS. Constaté sur l'appareil le 2026-08-17.
    public var releveFrais: Bool {
        if case .fraiche = self { return true }
        return false
    }
}

public enum DecodeurContrat {
    /// Décodeur partagé. Aucune stratégie de date : le contrat ne transporte que
    /// des entiers en millisecondes epoch, jamais d'ISO 8601.
    static let json = JSONDecoder()

    /// Traduit une réponse HTTP de LECTURE en l'une des trois issues.
    ///
    /// `statut` vient de la réponse ; il ne peut pas être déduit du corps, parce
    /// que le 502 du relais et le 404 du control plane portent la même forme
    /// `{ error, message }`.
    public static func lecture<Charge: Decodable & Sendable>(
        _ type: Charge.Type,
        statut: Int,
        corps: Data
    ) -> LectureApi<Charge> {
        guard (200...299).contains(statut) else {
            return .echec(ClassementErreur.classer(statut: statut, corps: corps))
        }
        do {
            let enveloppe = try json.decode(EnveloppeApi<Charge>.self, from: corps)
            return interpreter(enveloppe)
        } catch {
            return .echec(.contratRompu("réponse illisible pour \(type) : \(error)"))
        }
    }

    private static func interpreter<Charge: Decodable & Sendable>(
        _ enveloppe: EnveloppeApi<Charge>
    ) -> LectureApi<Charge> {
        guard enveloppe.pcOnline else {
            return .datee(donnees: enveloppe.data, message: enveloppe.message)
        }
        guard let donnees = enveloppe.data else {
            // Le serveur n'émet jamais ça : `enveloppe(true, …)` est toujours
            // appelée avec une charge. Si ça arrive, c'est une rupture de
            // contrat — la faire passer pour un PC éteint masquerait un défaut.
            return .echec(.contratRompu("enveloppe pcOnline=true sans données"))
        }
        return .fraiche(donnees)
    }

    /// Réponse HORS enveloppe, forme nue. Sert `/health` et les routes natives
    /// de `pi-web`, qui n'ont jamais porté l'enveloppe H-75.
    public static func nu<Charge: Decodable & Sendable>(
        _ type: Charge.Type,
        statut: Int,
        corps: Data
    ) -> Result<Charge, ErreurApi> {
        guard (200...299).contains(statut) else {
            return .failure(ClassementErreur.classer(statut: statut, corps: corps))
        }
        do {
            return .success(try json.decode(Charge.self, from: corps))
        } catch {
            return .failure(.contratRompu("réponse illisible pour \(type) : \(error)"))
        }
    }
}
