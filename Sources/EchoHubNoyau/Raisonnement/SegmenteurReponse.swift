import Foundation

/// Un bloc replié : du cheminement, pas la réponse.
public struct SegmentRaisonnement: Sendable, Equatable, Identifiable {
    /// Rang d'apparition dans la réponse. Identité STABLE tant que la réponse
    /// s'allonge par la fin — ce que fait un flux — donc utilisable en `ForEach`
    /// pendant la génération sans faire rejouer l'entrée en scène à chaque
    /// fragment.
    public let id: Int
    /// Nom de la convention qui a produit ce bloc (`think`, `outil`, `appel`…).
    public let convention: String
    /// Contenu du bloc, balises retirées.
    public let texte: String
    /// `false` tant que la balise fermante n'est pas arrivée.
    public let complet: Bool
}

/// Une réponse de modèle, séparée en ce qui se lit et ce qui se replie.
public struct ReponseSegmentee: Sendable, Equatable {
    /// Tout ce qui n'est pas du cheminement, dans l'ordre, recollé.
    public let visible: String
    public let raisonnements: [SegmentRaisonnement]
    /// Un bloc est ouvert et non refermé : le modèle est — ou s'est arrêté — en
    /// plein raisonnement.
    public let enCours: Bool
}

/// Sépare le texte brut d'une réponse en (texte visible, blocs repliés).
///
/// Port Swift de `frontend/src/chat/raisonnement/extraction.ts` d'EchoHub v2,
/// avec la MÊME divergence assumée vis-à-vis du backend : le serveur GARDE les
/// balises dans la part raisonnement, parce que ce sont des tokens réellement
/// renvoyés au modèle au tour suivant ; ici on les RETIRE, parce que
/// « `<think>` » affiché à l'écran n'est pas du raisonnement, c'est du
/// balisage. Les deux découpent au même endroit.
///
/// `☠` Cette fonction est le cœur de ce que Chris regarde. Elle est pure — pas
/// de réseau, pas de SwiftUI — précisément pour être prouvable par `swift test`
/// sur Linux, là où aucun écran ne l'est.
public enum SegmenteurReponse {
    /// Borne de la boucle : chaque tour consomme au moins une balise ouvrante
    /// entière, donc ce plafond n'est jamais atteint sur une entrée saine.
    private static let longueurOuvranteMin =
        Conventions.toutes.map(\.ouvrante.count).min() ?? 1

    public static func segmenter(_ source: String) -> ReponseSegmentee {
        guard source.contains(Conventions.marqueurFinEtape) else {
            return numeroter(segmenterPart(source))
        }
        var parts = source.components(separatedBy: Conventions.marqueurFinEtape)
        // `components` rend toujours au moins un élément : le retrait est sûr.
        let finale = parts.removeLast()
        var etapes: [SegmentRaisonnement] = []
        for part in parts { etapes.append(contentsOf: segmentsDEtape(part)) }
        let derniere = segmenterPart(finale)
        return numeroter(
            ReponseSegmentee(
                visible: derniere.visible,
                raisonnements: etapes + derniere.raisonnements,
                enCours: derniere.enCours
            )
        )
    }

    /// Un tour conclu par un appel d'outil : son commentaire libre devient un
    /// bloc « note de travail », placé selon qu'il précède ou suit les balises —
    /// ce qui restitue l'ordre réel commentaire, appel, résultat.
    private static func segmentsDEtape(_ part: String) -> [SegmentRaisonnement] {
        let morceau = segmenterPart(part)
        let commentaire = morceau.visible.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commentaire.isEmpty else { return morceau.raisonnements }
        let note = SegmentRaisonnement(id: 0, convention: "etape", texte: commentaire, complet: true)
        let commenceParDuTexte = premiereBalise(part) != 0
        return commenceParDuTexte ? [note] + morceau.raisonnements : morceau.raisonnements + [note]
    }

    /// Rang d'apparition de la première balise ouvrante, en nombre de
    /// caractères ; `count` s'il n'y en a aucune.
    private static func premiereBalise(_ source: String) -> Int {
        let debut = source.drop { $0.isWhitespace }
        let decalage = source.count - debut.count
        guard let ouverture = prochaineOuverture(String(debut), depuis: String(debut).startIndex) else {
            return source.count
        }
        return String(debut).distance(from: String(debut).startIndex, to: ouverture.index) + decalage
    }

    private static func numeroter(_ reponse: ReponseSegmentee) -> ReponseSegmentee {
        let numerotes = reponse.raisonnements.enumerated().map { rang, segment in
            SegmentRaisonnement(
                id: rang, convention: segment.convention,
                texte: segment.texte, complet: segment.complet
            )
        }
        return ReponseSegmentee(
            visible: reponse.visible, raisonnements: numerotes, enCours: reponse.enCours
        )
    }
}

// MARK: - Le découpage lui-même

extension SegmenteurReponse {
    private struct Ouverture {
        let convention: ConventionRaisonnement
        let index: String.Index
    }

    private struct Etat {
        var visible = ""
        var raisonnements: [SegmentRaisonnement] = []
        var curseur: String.Index
    }

    private static func segmenterPart(_ source: String) -> ReponseSegmentee {
        var etat = Etat(curseur: source.startIndex)
        for _ in 0...(source.count / longueurOuvranteMin) {
            /*
             * Deux cas concourent et c'est LE PLUS PROCHE du curseur qui
             * l'emporte, jamais l'un des deux systématiquement. Traiter la
             * fermeture orpheline d'abord faisait avaler tout ce qui la
             * précédait : un bloc d'outil complet se retrouvait absorbé dans un
             * segment étiqueté « Raisonnement ». Constaté côté web le
             * 2026-08-15, corrigé là-bas, repris ici plutôt que reproduit.
             */
            let orpheline = fermetureOrpheline(source, depuis: etat.curseur)
            let ouverture = prochaineOuverture(source, depuis: etat.curseur)
            if let orpheline, ouverture == nil || orpheline.index < ouverture!.index {
                etat = consommerOrpheline(source, etat, orpheline)
                continue
            }
            guard let ouverture else { break }
            guard consommerBloc(source, &etat, ouverture) else {
                return ReponseSegmentee(
                    visible: etat.visible, raisonnements: etat.raisonnements, enCours: true
                )
            }
        }
        etat.visible += source[etat.curseur...]
        return ReponseSegmentee(
            visible: etat.visible, raisonnements: etat.raisonnements, enCours: false
        )
    }

    /// Consomme un bloc ouvert par une balise. Rend `false` — APRÈS avoir posé
    /// le texte visible et le segment incomplet — quand le bloc n'est jamais
    /// refermé : c'est le cas NORMAL pendant la génération, pas un cas limite.
    /// Rien n'est mis en attente, sinon un raisonnement en cours resterait
    /// invisible jusqu'à la fin, et Chris regarderait un écran vide pendant que
    /// le modèle réfléchit.
    ///
    /// `☠` `inout`, pas une copie rendue. La version TypeScript dont ceci est le
    /// port mutait un objet partagé (sémantique de référence) ; une `struct`
    /// Swift rendue par valeur perd tout sur le chemin d'échec — le texte qui
    /// précédait la balise ET le segment incomplet. Bug réel, attrapé par
    /// `testBlocJamaisReferme`, c'est-à-dire par le cas le plus fréquent de
    /// toute l'app : chaque fragment reçu passe par là.
    private static func consommerBloc(
        _ source: String, _ etat: inout Etat, _ ouverture: Ouverture
    ) -> Bool {
        etat.visible += source[etat.curseur..<ouverture.index]
        let debut = source.index(ouverture.index, offsetBy: ouverture.convention.ouvrante.count)
        guard let fin = source.range(
            of: ouverture.convention.fermante, range: debut..<source.endIndex
        ) else {
            etat.raisonnements.append(
                segment(ouverture.convention, String(source[debut...]), complet: false)
            )
            return false
        }
        etat.raisonnements.append(
            segment(ouverture.convention, String(source[debut..<fin.lowerBound]), complet: true)
        )
        etat.curseur = fin.upperBound
        return true
    }

    /// Referme un bloc dont seule la balise fermante existe.
    ///
    /// `☠` Ce n'est pas un cas limite : les gabarits de conversation Qwen3 et
    /// DeepSeek-R1 placent eux-mêmes `<think>` à la fin du prompt pour amorcer
    /// le raisonnement. Le modèle n'a donc plus à l'émettre — le flux commence
    /// directement par la réflexion et ne porte que `</think>`. Chercher
    /// l'ouvrante en premier ne trouve rien, et TOUT le raisonnement s'affiche
    /// comme s'il était la réponse. C'est le comportement de tous les modèles de
    /// raisonnement chargés sur le PC.
    private static func consommerOrpheline(
        _ source: String, _ etat: Etat, _ orpheline: Ouverture
    ) -> Etat {
        var etat = etat
        let texte = String(source[etat.curseur..<orpheline.index])
        etat.raisonnements.append(segment(orpheline.convention, texte, complet: true))
        etat.curseur = source.index(orpheline.index, offsetBy: orpheline.convention.fermante.count)
        return etat
    }

    private static func segment(
        _ convention: ConventionRaisonnement, _ texte: String, complet: Bool
    ) -> SegmentRaisonnement {
        SegmentRaisonnement(id: 0, convention: convention.nom, texte: texte, complet: complet)
    }

    private static func prochaineOuverture(_ source: String, depuis: String.Index) -> Ouverture? {
        var meilleure: Ouverture?
        for convention in Conventions.toutes {
            guard let plage = source.range(
                of: convention.ouvrante, range: depuis..<source.endIndex
            ) else { continue }
            if meilleure == nil || plage.lowerBound < meilleure!.index {
                meilleure = Ouverture(convention: convention, index: plage.lowerBound)
            }
        }
        return meilleure
    }

    /// Fermeture qui apparaît AVANT toute ouvrante de la même convention.
    private static func fermetureOrpheline(_ source: String, depuis: String.Index) -> Ouverture? {
        var meilleure: Ouverture?
        for convention in Conventions.toutes {
            guard let fin = source.range(
                of: convention.fermante, range: depuis..<source.endIndex
            ) else { continue }
            let ouvrante = source.range(of: convention.ouvrante, range: depuis..<source.endIndex)
            // Une ouvrante située avant cette fermeture signifie un bloc normal.
            if let ouvrante, ouvrante.lowerBound < fin.lowerBound { continue }
            if meilleure == nil || fin.lowerBound < meilleure!.index {
                meilleure = Ouverture(convention: convention, index: fin.lowerBound)
            }
        }
        return meilleure
    }
}
