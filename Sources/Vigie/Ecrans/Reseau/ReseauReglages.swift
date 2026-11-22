// Réglages › Réseau (grammaire des réglages de l'étalon : titre de section, cartes groupées, rangées) : le réseau du
// nœud relié tel que la charte signée le décrit — en-tête (nom, version, rôle de cet iPhone), demandes qui attendent
// l'accord d'un chef, machines, téléphones, invités, « Ajouter… ». Un chef y fait tout ce que Lanterne fait ; un
// membre non chef lit seulement. Chaque changement est une charte signée par cet iPhone, vérifiée par chaque nœud.
#if canImport(SwiftUI)
import SwiftUI
import VigieNoyau

struct ReseauReglages: View {
    @Environment(Cablage.self) private var cablage
    @State private var modele = ModeleReseau()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if cablage.etatAiguilleur == nil {
                    sansPi
                } else if !modele.charge {
                    ProgressView().tint(Q.secondaire).frame(maxWidth: .infinity).padding(.top, 48)
                } else if let charte = modele.charte {
                    contenu(charte)
                } else if modele.erreur != nil {
                    sansLecture
                } else {
                    sansReseau
                }
            }
            .padding(.bottom, 32)
        }
        .barreFeuille("Réseau")
        .task(id: cablage.lienAiguilleur == .ouvert) {
            modele.brancher(cablage.clientAiguilleur)
            await modele.suivre()
        }
    }

    @ViewBuilder private func contenu(_ charte: CharteReseau) -> some View {
        EnteteReseau(charte: charte, modele: modele).padding(.top, 8)
        BandeauErreurReseau(modele: modele)
        if modele.chefNonVerifie { GardeRefusee(modele: modele) }
        if modele.chef, !modele.demandes.isEmpty { demandes }
        groupe("Machines", charte.membres.filter { $0.invite == nil && $0.sorte != .telephone }, charte)
        groupe("Téléphones", charte.membres.filter { $0.sorte == .telephone }, charte)
        groupe("Invités", charte.membres.filter { $0.invite != nil }, charte)
        if modele.chef {
            TitreSection(texte: "Ajouter")
            Carte { MenuAjout(modele: modele) }
        } else if !modele.chefNonVerifie {
            Note(texte: "Lecture seule : un chef peut nommer cet iPhone chef depuis Lanterne › Paramètres › Réseau, "
                 + "ou depuis un autre iPhone chef.")
        }
    }

    private var demandes: some View {
        VStack(spacing: 0) {
            TitreSection(texte: "En attente de ton accord")
            Carte {
                ForEach(Array(modele.demandes.enumerated()), id: \.element.id) { rang, d in
                    if rang > 0 { Filet(retrait: 60) }
                    NavigationLink { DemandeReseauEcran(modele: modele, demande: d, proposee: nil) } label: {
                        RangeeDemande(demande: d)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private func groupe(_ titre: String, _ membres: [MembreCharte], _ charte: CharteReseau) -> some View {
        if !membres.isEmpty {
            TitreSection(texte: titre)
            Carte {
                ForEach(Array(membres.enumerated()), id: \.element.id) { rang, m in
                    if rang > 0 { Filet(retrait: 60) }
                    NavigationLink { MembreReseauEcran(modele: modele, id: m.id) } label: {
                        RangeeMembre(membre: m, charte: charte, machine: modele.machines.first { $0.membre == m.id },
                                     moi: modele.moi)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sansPi: some View {
        VStack(spacing: 0) {
            Carte {
                RangeeReglage(symbole: "point.3.connected.trianglepath.dotted", titre: "Réseau géré par le Pi",
                              couleur: Q.secondaire, chevron: false)
            }
            .padding(.top, 8)
            Note(texte: "Le réseau se gère par l’aiguilleur : Réglages › Connexion › Passer par le Pi.")
        }
    }

    /// La charte n'a pas pu être lue (erreur du nœud relié) : ce n'est pas un « aucun réseau ». Relu toutes les 4 s.
    private var sansLecture: some View {
        VStack(spacing: 0) {
            BandeauErreurReseau(modele: modele)
            Carte {
                RangeeReglage(symbole: "exclamationmark.triangle", titre: "Réseau non lu sur ce nœud",
                              couleur: Q.avertissement, chevron: false)
            }
            .padding(.top, 8)
            Note(texte: "Le nœud relié n’a pas servi la charte. Il tourne peut-être une version qui ne gère pas "
                 + "encore le téléphone chef.")
        }
    }

    private var sansReseau: some View {
        VStack(spacing: 0) {
            BandeauErreurReseau(modele: modele)
            Carte {
                RangeeReglage(symbole: "circle.dashed", titre: "Aucun réseau sur ce nœud", couleur: Q.secondaire,
                              chevron: false)
            }
            .padding(.top, 8)
            Note(texte: "Crée le réseau dans Lanterne › Paramètres › Réseau › Créer mon réseau ; cet iPhone y "
                 + "entrera dès qu’il est accepté.")
        }
    }
}

/// En-tête : glyphe du réseau, nom, version et rôle de cet iPhone.
private struct EnteteReseau: View {
    let charte: CharteReseau
    let modele: ModeleReseau

    var body: some View {
        Carte {
            HStack(spacing: 14) {
                Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 19, weight: .light))
                    .foregroundStyle(Q.texte).frame(width: 44, height: 44).background(Color.black, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(charte.nom).font(Q.rangee).foregroundStyle(Q.texte).lineLimit(1)
                    Text(detail).font(Q.detail).foregroundStyle(Q.secondaire).lineLimit(1)
                }
                Spacer(minLength: 8)
                if modele.chef { Pilule(texte: "Chef", symbole: "checkmark.seal") }
                if let enCours = modele.enCours { Text(enCours).font(Q.petit).foregroundStyle(Q.tertiaire) }
            }
            .padding(.horizontal, Q.marge).frame(height: 68)
        }
    }

    private var detail: String {
        let n = charte.membres.count
        return "Version \(charte.version) · \(n) membre\(n > 1 ? "s" : "")"
    }
}

/// Une demande d'appairage : glyphe du genre, nom, et ce qui attend.
struct RangeeDemande: View {
    let demande: DemandeReseau

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: demande.genre == "appareil" ? "iphone" : "desktopcomputer")
                .font(.system(size: 19, weight: .light)).foregroundStyle(Q.avertissement).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(demande.nom).font(Q.rangee).foregroundStyle(Q.texte).lineLimit(1)
                Text(demande.genre == "appareil" ? "Téléphone · demande à rejoindre" : "Machine · demande à rejoindre")
                    .font(Q.detail).foregroundStyle(Q.secondaire).lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .medium)).foregroundStyle(Q.meta)
        }
        .padding(.horizontal, Q.marge).frame(minHeight: 60).contentShape(.rect)
    }
}

/// Un membre de la charte : glyphe (vert en ligne), nom, puis rôle, état et ressources en une ligne.
struct RangeeMembre: View {
    let membre: MembreCharte
    let charte: CharteReseau
    let machine: MachineReseau?
    let moi: String?

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: GlypheMembre.symbole(membre)).font(.system(size: 19, weight: .light))
                .foregroundStyle(machine?.enLigne == true ? Q.enLigne : Q.meta).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(membre.nom).font(Q.rangee).foregroundStyle(Q.texte).lineLimit(1)
                Text(DetailMembre.ligne(membre, charte: charte, machine: machine, moi: moi))
                    .font(Q.detail).foregroundStyle(Q.secondaire).lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .medium)).foregroundStyle(Q.meta)
        }
        .padding(.horizontal, Q.marge).frame(minHeight: 60).contentShape(.rect)
    }
}

enum GlypheMembre {
    static func symbole(_ m: MembreCharte) -> String {
        if m.invite != nil { return "person.crop.circle" }
        switch m.sorte {
        case .serveur: return "server.rack"
        case .pair: return "laptopcomputer"
        case .telephone: return "iphone"
        }
    }
}

/// Le texte de détail d'un membre : « Chef · en ligne · CPU 12 % · en pause ».
enum DetailMembre {
    static func ligne(_ m: MembreCharte, charte: CharteReseau, machine: MachineReseau?, moi: String?) -> String {
        var morceaux: [String] = []
        if m.id == moi { morceaux.append("Cet iPhone") }
        morceaux.append(role(m, charte: charte))
        if let machine {
            morceaux.append(machine.enLigne ? "en ligne" : "hors ligne")
            if machine.enLigne, let cpu = machine.etat?.cpu { morceaux.append("CPU \(Int(cpu.rounded())) %") }
            if machine.etat?.pause == true { morceaux.append("en pause") }
        }
        return morceaux.joined(separator: " · ")
    }

    static func role(_ m: MembreCharte, charte: CharteReseau) -> String {
        if charte.estChef(m.id) { return "Chef" }
        if m.invite != nil { return "Invité" }
        switch m.sorte {
        case .serveur: return "Serveur"
        case .pair: return "Pair"
        case .telephone: return "Téléphone"
        }
    }
}

/// Texte d'aide sous une carte, comme partout dans les réglages.
struct Note: View {
    let texte: String

    var body: some View {
        Text(texte).font(Q.detail).foregroundStyle(Q.secondaire)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32).padding(.top, 8)
    }
}

/// La dernière erreur d'un geste ou d'une relecture, en texte rosé sous l'en-tête.
struct BandeauErreurReseau: View {
    let modele: ModeleReseau

    var body: some View {
        if let erreur = modele.erreur {
            Text(erreur).font(Q.detail).foregroundStyle(Q.retraitTexte)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32).padding(.top, 8)
        }
    }
}

/// Chef selon la charte, mais signée par quelqu'un que cet iPhone ne tenait pas pour chef (ou plus ancienne) :
/// rien n'est signé tant que Chris ne l'a pas acceptée comme nouvelle référence.
private struct GardeRefusee: View {
    let modele: ModeleReseau
    @State private var confirmer = false

    var body: some View {
        TitreSection(texte: "Charte à vérifier")
        Carte {
            RangeeReglage(symbole: "exclamationmark.shield", titre: "Signée par \(signataire)",
                          valeur: "v\(modele.charte?.version ?? 0)", chevron: false)
            Filet(retrait: 60)
            Button { confirmer = true } label: {
                RangeeReglage(symbole: "checkmark.shield", titre: "En faire la référence…", couleur: Q.lien,
                              chevron: false)
            }
            .buttonStyle(.plain)
        }
        Note(texte: "Cet iPhone ne signe que par-dessus une charte qu’il sait vérifier. Celle-ci a été signée par un "
             + "chef qu’il ne connaissait pas encore : accepte-la seulement si ce changement vient bien de toi.")
            .confirmationDialog("Faire de cette charte la référence ?", isPresented: $confirmer,
                                titleVisibility: .visible) {
                Button("En faire la référence") { Task { await modele.faireConfiance() } }
            } message: { Text("Les prochaines signatures de cet iPhone partiront de cette version.") }
    }

    private var signataire: String {
        guard let c = modele.charte else { return "—" }
        return c.membre(c.par)?.nom ?? c.par
    }
}
#endif
