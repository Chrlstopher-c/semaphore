import Foundation

/// La lecture des listes, imbrication comprise. Portée de
/// `frontend/src/chat/markdown/liste.ts`.
///
/// `☠` Le niveau d'une liste est son indentation MESURÉE sur la première ligne
/// d'item, jamais un palier supposé (« 2 espaces = un niveau ») : les modèles
/// indentent à 2, 3 ou 4 espaces selon l'humeur du gabarit, et un palier codé en
/// dur ferait disparaître un niveau sur deux.
///
/// Toute situation qu'on ne sait pas rattacher clôt la liste au lieu d'écraser
/// quoi que ce soit : l'appelant relit la ligne comme une nouvelle liste, et
/// aucun texte reçu n'est perdu.
enum AnalyseListe {
    /// Profondeur bornée : au-delà l'affichage n'est de toute façon plus
    /// lisible, et la récursion cesse d'être garantie finie sur une entrée
    /// pathologique (indentation croissante à chaque ligne).
    static let profondeurMax = 6
    /// Une continuation appartient à l'item si elle dépasse son indentation
    /// d'au moins deux espaces.
    static let retraitContinuation = 2

    struct Marque {
        let indentation: Int
        let ordonnee: Bool
        let texte: String
    }

    private static let motifItem = try? NSRegularExpression(
        pattern: "^(\\s*)([-*+]|\\d+[.)])\\s+(.*)$"
    )

    /// Reconnaît une ligne d'item et mesure son indentation — une tabulation
    /// compte pour deux espaces.
    static func marque(_ ligne: String) -> Marque? {
        guard let motifItem else { return nil }
        let entier = NSRange(ligne.startIndex..., in: ligne)
        guard let trouve = motifItem.firstMatch(in: ligne, range: entier) else { return nil }
        let creux = groupe(trouve, 1, ligne).replacingOccurrences(of: "\t", with: "  ")
        let marqueur = groupe(trouve, 2, ligne)
        return Marque(
            indentation: creux.count,
            ordonnee: marqueur.contains(where: \.isNumber),
            texte: groupe(trouve, 3, ligne)
        )
    }

    private static func groupe(
        _ trouve: NSTextCheckingResult, _ rang: Int, _ source: String
    ) -> String {
        guard let plage = Range(trouve.range(at: rang), in: source) else { return "" }
        return String(source[plage])
    }

    private struct Cadre {
        let indentation: Int
        let ordonnee: Bool
        let profondeur: Int
    }

    /// Lit une liste depuis `depart`. La nature — à puces ou numérotée — est
    /// celle de la PREMIÈRE ligne : c'est elle qui définit la liste, les
    /// suivantes s'y conforment ou la closent.
    static func lire(
        _ lignes: [String], depart: Int, indentation: Int, profondeur: Int
    ) -> (liste: ListeMarkdown, suivant: Int) {
        let premiere = marque(ligne(lignes, depart))
        let cadre = Cadre(
            indentation: indentation, ordonnee: premiere?.ordonnee ?? false, profondeur: profondeur
        )
        var items: [ItemListe] = []
        var i = depart
        while i < lignes.count {
            guard let suivant = consommer(lignes, i, cadre, &items), suivant > i else { break }
            i = suivant
        }
        return (ListeMarkdown(ordonnee: cadre.ordonnee, items: items), i)
    }

    /// Traite la ligne `index`. Rend l'index suivant, ou `nil` pour clore.
    private static func consommer(
        _ lignes: [String], _ index: Int, _ cadre: Cadre, _ items: inout [ItemListe]
    ) -> Int? {
        guard let marque = marque(ligne(lignes, index)) else {
            return continuation(lignes, index, cadre, &items)
        }
        if marque.indentation < cadre.indentation { return nil }
        if marque.indentation > cadre.indentation {
            return imbriquer(lignes, index, cadre, &items, retrait: marque.indentation)
        }
        // Changement de nature au même niveau : c'est une AUTRE liste, pas la
        // suite de celle-ci.
        guard marque.ordonnee == cadre.ordonnee else { return nil }
        items.append(ItemListe(contenu: AnalyseInline.analyser(marque.texte), sousListe: nil))
        return index + 1
    }

    /// Ligne indentée sous un item, sans marqueur : suite de son texte, ou fin.
    private static func continuation(
        _ lignes: [String], _ index: Int, _ cadre: Cadre, _ items: inout [ItemListe]
    ) -> Int? {
        let courante = ligne(lignes, index)
        if courante.trimmingCharacters(in: .whitespaces).isEmpty {
            // Ligne vide : la liste ne se poursuit que si un item suit (liste
            // « aérée »), sinon elle se clôt.
            guard let suivante = marque(ligne(lignes, index + 1)),
                  suivante.indentation >= cadre.indentation else { return nil }
            return index + 1
        }
        let retrait = courante.count - courante.drop(while: \.isWhitespace).count
        let rattachable = retrait >= cadre.indentation + retraitContinuation
        let nue = courante.drop(while: \.isWhitespace)
        // Un bloc de code indenté sous un item est rendu au niveau supérieur
        // plutôt qu'avalé en texte : il resterait lisible, mais perdrait sa
        // police à chasse fixe et son bouton copier.
        guard !items.isEmpty, rattachable, !nue.hasPrefix(AnalyseMarkdown.clotureCode) else {
            return nil
        }
        items[items.count - 1].contenu +=
            [.texte(" ")]
            + AnalyseInline.analyser(courante.trimmingCharacters(in: .whitespaces))
        return index + 1
    }

    /// Rattache une sous-liste au dernier item, ou clôt si c'est impossible.
    private static func imbriquer(
        _ lignes: [String], _ index: Int, _ cadre: Cadre,
        _ items: inout [ItemListe], retrait: Int
    ) -> Int? {
        guard !items.isEmpty, items[items.count - 1].sousListe == nil,
              cadre.profondeur < profondeurMax else { return nil }
        let sous = lire(lignes, depart: index, indentation: retrait, profondeur: cadre.profondeur + 1)
        items[items.count - 1].sousListe = sous.liste
        return sous.suivant
    }

    static func ligne(_ lignes: [String], _ index: Int) -> String {
        lignes.indices.contains(index) ? lignes[index] : ""
    }
}
