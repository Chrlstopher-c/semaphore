// L'organisation gardée sur l'iPhone (favoris par machine) : fusion à chaque lecture réussie du parc, marque d'échec
// quand le relais ne répond pas, favoris à afficher même hors ligne. La fusion et le fichier sont dans VigieNoyau.
#if canImport(SwiftUI)
import Foundation
import VigieNoyau

extension ModeleRelais {
    /// Favoris à afficher : les épinglées du relais, puis celles gardées sur l'iPhone dont la session n'est pas au
    /// relais (machine éteinte, relais injoignable). Les plus récentes d'abord.
    var favoris: [Session] {
        let vivantes = JumellesDistantes.sansDoublons(sessions).filter(Organisation.estFavori)
        let presentes = Set(sessions.map(\.id))
        let gardees = organisation.favoris.filter { !presentes.contains($0.id) }
        return (vivantes + gardees).sorted { $0.majLe > $1.majLe }
    }

    /// Une lecture du parc a réussi : chaque machine en ligne et joignable est à jour sur l'iPhone.
    func synchroniserOrganisation(maintenant: Date) {
        var suite = organisation
        for machine in machines where machine.enLigne && machine.acces?.etat != "injoignable" {
            let ses = sessions.filter { $0.machine == machine.id }
            suite = suite.fusionner(machine: machine.id, sessions: ses, maintenant: maintenant)
        }
        garderOrganisation(suite)
    }

    /// Une session vue par le flux : son épinglage est gardé, sans compter comme une synchro.
    func memoriserFavori(_ session: Session) {
        garderOrganisation(organisation.fusionner(machine: session.machine, sessions: [session], maintenant: nil))
    }

    /// La lecture du relais a échoué : le motif part aux machines connues, leurs favoris ne bougent pas.
    func echecOrganisation(_ raison: String) {
        let identifiants = Set(machines.map(\.id)).union(organisation.machines.keys).sorted()
        garderOrganisation(organisation.echec(raison, sur: identifiants))
    }

    /// Déconnexion du nœud : ses favoris ne restent pas sur l'iPhone.
    func effacerOrganisation() {
        garderOrganisation(.vide)
    }

    /// Écrit seulement si quelque chose change (un état identique ne réécrit pas le fichier).
    func garderOrganisation(_ suite: Organisation) {
        guard suite != organisation else { return }
        organisation = suite
        stockage.ecrire(suite)
    }
}
#endif
