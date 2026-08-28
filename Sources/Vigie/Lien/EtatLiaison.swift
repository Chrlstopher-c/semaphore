#if canImport(SwiftUI)
import Foundation
import Observation
import VigieNoyau

/// Ce qu'un aller-retour réseau apprend sur l'état de la liaison.
///
/// Émis par `ClientPi` à CHAQUE requête, consommé par la coquille. Aucun écran
/// n'a à penser à tenir le bandeau à jour : c'est ce qui garantit qu'il ne ment
/// jamais, y compris depuis un domaine écrit trois semaines plus tard.
public struct VerdictLien: Sendable {
    public let instant: Date
    /// Le relevé venait-il de l'instant, ou du registre persisté du Pi ?
    /// `nil` quand la requête ne dit rien là-dessus (écriture, route binaire).
    public let releveFrais: Bool?
    public let erreur: ErreurApi?

    public init(instant: Date = Date(), releveFrais: Bool?, erreur: ErreurApi?) {
        self.instant = instant
        self.releveFrais = releveFrais
        self.erreur = erreur
    }
}

/// L'état de liaison, en permanence à l'écran.
///
/// `☠` CE BANDEAU NE PARLE QUE DE LA LIAISON, JAMAIS D'UNE MACHINE. Il a
/// longtemps annoncé « PC en ligne » / « PC éteint », c'est-à-dire l'état d'UNE
/// machine du parc présenté comme l'état du produit entier : sur un fil hébergé
/// par le VPS, l'app affichait « PC éteint » et laissait croire que ce qu'on
/// regardait dormait. Constaté sur l'appareil le 2026-08-17.
///
/// Trois notions à ne jamais refondre :
///  1. la liaison au Pi — globale, c'est ce type ;
///  2. la fraîcheur d'un relevé — propriété DU RELEVÉ, portée par
///     `MentionFraicheur` sur chaque écran ;
///  3. l'état d'une machine — `MachineApi.enLigne`, par machine, affiché là où
///     cette machine est le sujet.
///
/// Et le régime `registre` n'est PAS une panne : le poste de travail éteint la
/// nuit est le fonctionnement normal du produit.
@MainActor @Observable
public final class Liaison {

    public enum Regime: Sendable, Equatable {
        /// Le harness répond en direct.
        case nominal
        /// Le registre persisté du Pi répond à la place : données vraies, datées.
        /// Cause habituelle, mais jamais affirmée ici : le poste de travail dort.
        case registre
        /// Le Pi ne répond pas : tunnel coupé, control plane mort, réseau absent.
        case perdue
        /// Session close ou périmée : plus rien n'est lisible avant reconnexion.
        case sessionRequise
    }

    public private(set) var regime: Regime = .perdue
    /// Dernier aller-retour ABOUTI, quel qu'en soit le verdict sur le PC.
    public private(set) var dernierContact: Date?
    /// Dernier refus rencontré. Effacé au premier succès.
    public private(set) var dernierEchec: ErreurApi?
    /// Vrai tant qu'aucune requête n'a encore abouti depuis le lancement.
    public private(set) var jamaisJoint = true

    public init() {}

    public var libelle: String {
        switch regime {
        case .nominal: return "en direct"
        case .registre: return "registre du Pi"
        case .perdue: return jamaisJoint ? "Pi injoignable" : "liaison perdue"
        case .sessionRequise: return "session à rouvrir"
        }
    }

    /// Complément de seconde ligne : dit depuis quand, ou pourquoi.
    public var precision: String? {
        switch regime {
        case .nominal:
            return nil
        case .registre:
            return "poste de travail absent — données datées"
        case .perdue:
            guard let dernierContact else { return dernierEchec?.message }
            return "dernier contact \(Fraicheur.texte(depuis: dernierContact))"
        case .sessionRequise:
            return dernierEchec?.message
        }
    }

    /// Applique un verdict. Seul point d'entrée : la coquille draine le flux de
    /// `ClientPi` et appelle ceci, personne d'autre.
    public func appliquer(_ verdict: VerdictLien) {
        if let erreur = verdict.erreur {
            appliquerErreur(erreur, instant: verdict.instant)
            return
        }
        jamaisJoint = false
        dernierContact = verdict.instant
        dernierEchec = nil
        // `releveFrais == nil` : l'aller-retour a abouti mais ne dit rien de la
        // fraîcheur (écriture, route binaire). On ne DÉGRADE pas le bandeau sur
        // une absence d'information — un envoi réussi ferait clignoter
        // « registre » alors qu'il vient précisément d'être servi.
        guard let releveFrais = verdict.releveFrais else {
            if regime == .perdue || regime == .sessionRequise { regime = .nominal }
            return
        }
        regime = releveFrais ? .nominal : .registre
    }

    private func appliquerErreur(_ erreur: ErreurApi, instant: Date) {
        dernierEchec = erreur
        switch erreur.genre {
        case .authentification:
            regime = .sessionRequise
        case .transport:
            regime = .perdue
        case .harnessInjoignable:
            // Le control plane est mort sur le Pi. Le Pi, lui, a répondu : c'est
            // un contact abouti, et surtout PAS un « PC éteint ».
            jamaisJoint = false
            dernierContact = instant
            regime = .perdue
        default:
            // 400/404/409/501 : le lien est bon, c'est le geste qui a été refusé.
            jamaisJoint = false
            dernierContact = instant
            if regime == .perdue || regime == .sessionRequise { regime = .nominal }
        }
    }

    /// Force le passage en « session à rouvrir » — utilisé par la déconnexion
    /// volontaire depuis les réglages.
    public func exigerSession() {
        regime = .sessionRequise
    }

    /// À appeler après une reconnexion réussie, avant la première lecture.
    public func sessionOuverte() {
        dernierEchec = nil
        regime = .perdue
        jamaisJoint = true
    }
}
#endif
