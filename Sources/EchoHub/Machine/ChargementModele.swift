// Charger et décharger un modèle depuis le téléphone.
//
// `☠` Le `TODO.md` classait ce point « hors périmètre » au motif qu'on ne voit
// pas la VRAM depuis un téléphone, donc qu'on ne saurait pas quoi afficher en
// cas d'échec. L'argument ne tient plus une fois le backend lu : `StatutInference`
// porte déjà `message` et `remediation`, écrits par le superviseur, et l'onglet
// Machine affiche déjà `message`. L'échec est donc racontable sans afficher un
// plan. Le scénario que ça débloque est le plus probable de tous : PC rallumé,
// aucun modèle chargé, et l'app réduite à une visionneuse jusqu'à ce que Chris
// marche jusqu'à la machine.
#if canImport(SwiftUI)
import SwiftUI
import EchoHubNoyau

extension Salon {
    /// Le nombre de fois qu'on redemande au PC « c'est fini ? ».
    ///
    /// Chaque tour attend jusqu'à 60 s CÔTÉ SERVEUR (`/etat/attendre`), donc
    /// trois tours couvrent trois minutes sans qu'aucune boucle de sondage ne
    /// tourne sur le téléphone. Bornée exprès : sans plafond, un chargement qui
    /// n'aboutit jamais ferait tourner l'app jusqu'à la batterie vide.
    static let toursAttenteChargement = 3
    static let delaiAttenteSecondes = 60

    /// Assemble les entrées du planificateur : métadonnées lues dans l'en-tête
    /// GGUF, profil matériel mesuré à l'instant, et ce qui occupe déjà le GPU.
    ///
    /// `☠` Le profil est relu à CHAQUE fois, jamais mémorisé : la VRAM libre
    /// change dès qu'un modèle est chargé ou éjecté, et planifier sur une mesure
    /// périmée est exactement ce qui produisait les échecs silencieux de la v1.
    ///
    /// Les deux relevés partent ensemble : ils sont indépendants, et les
    /// enchaîner ferait attendre deux allers-retours à travers le tunnel.
    func viser(
        _ modele: ModeleEnregistre, preferences: PreferencesChargement = PreferencesChargement()
    ) async throws -> CibleChargement.Cible {
        async let metadonnees = modeles.metadonnees(modele.id)
        async let profil = modeles.profilMachine()
        let vue = CibleChargement.construire(
            modele: modele, metadonnees: try await metadonnees, profil: try await profil,
            statut: statutPret, preferences: preferences
        )
        switch vue {
        case .success(let cible): return cible
        case .failure(let refus): throw refus
        }
    }

    /// Fait calculer un plan par le PC, l'applique tel quel, puis attend
    /// l'issue. C'est le geste à un doigt du registre ; l'écran de plan, lui,
    /// montre le plan avant de l'appliquer.
    public func chargerModele(_ modele: ModeleEnregistre) async {
        guard !chargementEnCours else { return }
        poser(chargement: true)
        defer { poser(chargement: false) }
        do {
            let cible = try await viser(modele)
            let reponse = try await modeles.planifier(demande: cible.demande)
            guard let plan = reponse["plan"], !plan.estNul else {
                return poser(echecMachine: "Le planificateur n'a rendu aucun plan.")
            }
            try await appliquer(plan: plan, chemin: cible.cheminModele)
        } catch let refus as RefusCible {
            Journal.echec("cible non calculable pour \(modele.id) : \(refus.manquant)")
            poser(echecMachine: "Manque : \(refus.manquant). \(refus.remediation)")
        } catch {
            Journal.echec("chargement de \(modele.id) impossible : \(error)")
            poser(echecMachine: Self.libelle(error))
        }
    }

    /// Applique un plan et suit l'issue. Partagé par le geste à un doigt et par
    /// l'écran de plan : deux chemins vers le même appel divergeraient.
    func appliquer(plan: ValeurJSON, chemin: String) async throws {
        statut = .pret(try await modeles.charger(cheminModele: chemin, plan: plan))
        poser(echecMachine: nil)
        await attendreLaFinDuChargement()
    }

    public func dechargerModele() async {
        guard !chargementEnCours else { return }
        poser(chargement: true)
        defer { poser(chargement: false) }
        do {
            statut = .pret(try await modeles.decharger())
            poser(echecMachine: nil)
        } catch {
            Journal.echec("déchargement impossible : \(error)")
            poser(echecMachine: Self.libelle(error))
        }
    }

    /// Sonde le moteur MAINTENANT.
    ///
    /// `☠` `/etat` rend un état MÉMORISÉ : un moteur mort continue d'y
    /// apparaître « prêt ». Le bouton « Vérifier » relisait cet état mémorisé,
    /// et pouvait donc confirmer une fausse bonne nouvelle.
    public func sonderMoteur() async {
        do {
            let sante = try await modeles.sante()
            await rafraichirStatut()
            poser(echecMachine: sante.disponible ? nil : santeIllisible(sante))
        } catch {
            Journal.echec("sonde du moteur échouée : \(error)")
            await rafraichirStatut()
        }
    }

    private func santeIllisible(_ sante: SanteMoteur) -> String {
        sante.detail.isEmpty
            ? "Le moteur ne répond pas à une sonde directe."
            : sante.detail
    }

    /// Boucle BORNÉE : l'attente est côté serveur, on ne sonde pas en rafale.
    private func attendreLaFinDuChargement() async {
        for _ in 0..<Self.toursAttenteChargement {
            do {
                let releve = try await modeles.attendreEtat(delaiSecondes: Self.delaiAttenteSecondes)
                statut = .pret(releve)
                guard releve.etat == .enCours else {
                    poser(echecMachine: releve.etat == .echoue ? releve.remediation : nil)
                    return
                }
            } catch {
                Journal.echec("attente du chargement interrompue : \(error)")
                return poser(echecMachine: Self.libelle(error))
            }
        }
        poser(echecMachine: "Le chargement dure encore. Tire vers le bas pour reprendre le relevé.")
    }
}
#endif
