import Foundation

// Responsabilité : la demande de la liste des nœuds au nœud du lien qui vient de s'ouvrir, et la prise en compte
// de sa réponse : apprentissage des identités, puis nouveau calcul de la cible (la tour, une fois connue, prend le
// lien).

extension ClientAiguilleur {
    /// Demande la liste des nœuds sur le lien ouvert, en tâche de fond : un échec ne touche pas au lien.
    func demanderNoeuds() {
        Task {
            do {
                let reponse = try await self.requete(methode: "GET", chemin: "/api/appareils/noeuds", corps: nil)
                guard reponse.statut == 200 else {
                    Trace.info("aiguilleur", "liste des nœuds : statut \(reponse.statut), ignorée")
                    return
                }
                await self.apprendreNoeuds(reponse.corps)
            } catch {
                Trace.erreur("aiguilleur", "liste des nœuds non obtenue", error)
            }
        }
    }

    /// Apprend les identités de la liste ; une identité déjà connue reste. Si quelque chose est appris, la cible
    /// est recalculée (sans rien faire d'autre : pas d'appairage, pas de présentation).
    func apprendreNoeuds(_ corps: String) async {
        guard let entrees = ApprentissageNoeuds.lire(corps) else { return }
        let membre = etat.membre
        let identiteMoi = moi.map { Chiffrement.Identites.exporter($0.publique) }
        let appris = ApprentissageNoeuds.fusionner(entrees, dans: &etat.noeuds, moi: membre, identiteMoi: identiteMoi)
        guard !appris.isEmpty else { return }
        Trace.info("aiguilleur", "nœuds appris de la liste : \(appris.joined(separator: ", "))")
        await surEtat(etat)
        await cibler()
    }
}
