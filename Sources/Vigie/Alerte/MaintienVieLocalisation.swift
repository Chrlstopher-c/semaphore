#if canImport(SwiftUI)
import CoreLocation
import Foundation
import Observation
import VigieNoyau

/// Le canal numéro deux : maintient l'app en vie quand la session audio ne le
/// peut plus, en tenant des mises à jour de localisation en arrière-plan.
///
/// Il ne remplace pas `MaintienVie`, il prend le relais exactement pendant le
/// temps où celui-ci est hors jeu — c'est-à-dire tant qu'une autre app détient
/// l'audio en exclusif.
///
/// `☠` LE cas mesuré qui justifie ce fichier : Sillon pose `.playback` SANS
/// `.mixWithOthers` (`MoteurAudio.swift`, ligne 453). Une session exclusive
/// interrompt la session silencieuse de `MaintienVie`, qui ne reprend qu'à
/// l'`interruptionNotification` de type `.ended` — donc à la fin du morceau, de
/// l'album, ou de l'écoute. Sans ce relais, écouter de la musique éteint le
/// canal d'alerte pendant toute la durée de l'écoute.
///
/// `☠` La précision grossière n'est pas une politesse, c'est la condition pour
/// que ce canal soit tenable : à trois kilomètres, iOS sert la demande depuis
/// les antennes et le Wi-Fi, sans jamais allumer le GPS. Ne pas la resserrer
/// « pour être sûr » — ce serait échanger l'autonomie de la batterie contre une
/// donnée dont personne ici n'a l'usage. Aucune position n'est lue, ni
/// enregistrée, ni transmise : seul le fait que le service tourne compte.
@MainActor
@Observable
public final class MaintienVieLocalisation: NSObject {
    public static let partage = MaintienVieLocalisation()

    public private(set) var actif = false
    public private(set) var statut = "inactif"
    public private(set) var releves = 0

    @ObservationIgnored private let gestionnaire = CLLocationManager()
    @ObservationIgnored private var boucle: Task<Void, Never>?

    private static let intervalleSondageS: Double = 25

    private override init() {
        super.init()
        gestionnaire.delegate = self
        gestionnaire.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        // Un filtre large : sans lui, iOS rappelle le délégué à chaque dérive de
        // quelques mètres, pour une donnée que ce canal n'utilise pas.
        gestionnaire.distanceFilter = 3_000
        // `false` : autrement iOS met les mises à jour en pause quand l'appareil
        // ne bouge pas — c'est-à-dire précisément quand le téléphone est posé,
        // donc précisément quand le canal doit tenir.
        gestionnaire.pausesLocationUpdatesAutomatically = false
    }

    /// Demande l'autorisation « Toujours ». Sans elle, les mises à jour cessent
    /// dès que l'app quitte le premier plan, et le canal ne sert à rien.
    public func demanderAutorisation() {
        guard gestionnaire.authorizationStatus == .notDetermined else { return }
        gestionnaire.requestAlwaysAuthorization()
    }

    public func engager() {
        guard !actif else { return }
        guard autorisationSuffisante else {
            statut = "autorisation « Toujours » refusée"
            Trace.info("alerte", "canal 2 impossible : \(gestionnaire.authorizationStatus.rawValue)")
            rapporter()
            return
        }
        // `☠` Cette propriété lève une exception Objective-C — donc tue le
        // processus, sans passer par `catch` — si `location` manque des
        // `UIBackgroundModes`. Elle y est (`Info.plist`) ; la garde protège le
        // jour où ce fichier est porté ailleurs.
        guard modeArrierePlanDeclare else {
            statut = "mode « location » absent de l'Info.plist"
            Trace.erreur("alerte", "canal 2 impossible : UIBackgroundModes sans location")
            rapporter()
            return
        }
        gestionnaire.allowsBackgroundLocationUpdates = true
        gestionnaire.startUpdatingLocation()
        actif = true
        statut = "relais de localisation actif — le processus survit"
        Trace.info("alerte", "canal 2 engagé (l'audio est pris par une autre app)")
        rapporter()
        demarrerBoucleDeSondage()
    }

    public func arreter() {
        guard actif else { return }
        boucle?.cancel()
        boucle = nil
        gestionnaire.stopUpdatingLocation()
        gestionnaire.allowsBackgroundLocationUpdates = false
        actif = false
        statut = "inactif"
        Trace.info("alerte", "canal 2 relâché après \(releves) relevé(s)")
        rapporter()
    }

    private var autorisationSuffisante: Bool {
        gestionnaire.authorizationStatus == .authorizedAlways
    }

    /// Lu dans le paquet plutôt que supposé : c'est la seule vérification qui
    /// distingue une exception fatale d'un refus propre.
    private var modeArrierePlanDeclare: Bool {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        return modes?.contains("location") ?? false
    }

    /// Le bus d'alerte, tenu par ce canal tant qu'il a la main — même cadence et
    /// même appelé que sous la veille audio, pour que l'écran du canal ne
    /// distingue rien d'autre que l'origine du relevé.
    private func demarrerBoucleDeSondage() {
        boucle?.cancel()
        boucle = Task { @MainActor [weak self] in
            while let self, self.actif, !Task.isCancelled {
                await CentreAlerte.partage.sonder(origine: .veilleLocalisation)
                try? await Task.sleep(for: .seconds(Self.intervalleSondageS))
            }
        }
    }

    private func rapporter() {
        CentreAlerte.partage.rapporterLocalisation(actif: actif, releves: releves, statut: statut)
    }
}

// MARK: - Délégué

extension MaintienVieLocalisation: CLLocationManagerDelegate {
    /// `☠` Les rappels de `CoreLocation` arrivent sur la file où le gestionnaire
    /// a été créé — ici la principale — mais leur signature n'est pas isolée.
    /// `assumeIsolated` dit à Swift 6 ce qui est vrai, sans sauter de tour de
    /// boucle : un `Task { @MainActor }` retarderait l'arrêt du canal.
    public nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        let nombre = locations.count
        MainActor.assumeIsolated { self.releves += nombre }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            Trace.erreur("alerte", "relevé de localisation refusé", error)
            self.statut = "relevé refusé : \(error.localizedDescription)"
            self.rapporter()
        }
    }

    /// L'autorisation peut être accordée APRÈS un `engager()` refusé — la
    /// réponse de Chris à l'invite système arrive forcément plus tard. Sans ce
    /// rattrapage, le canal resterait éteint jusqu'au redémarrage de l'app.
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard !self.actif, self.autorisationSuffisante else { return }
            guard MaintienVie.partage.audioInterrompu else { return }
            self.engager()
        }
    }
}
#endif
