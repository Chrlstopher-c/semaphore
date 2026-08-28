// La jauge de la charte : un trait de 3 pt, un libellé, une valeur en mono.
// La couleur vient des seuils — en dessous, elle reste neutre : une jauge
// verte en permanence apprend à ignorer le vert.
#if canImport(SwiftUI)
import SwiftUI

public struct JaugeFine: View {
    private let libelle: String
    /// 0…1.
    private let part: Double
    private let detail: String?
    private let seuilVigilance: Double
    private let seuilDanger: Double

    public init(
        _ libelle: String,
        part: Double,
        detail: String? = nil,
        seuilVigilance: Double = 0.7,
        seuilDanger: Double = 0.9
    ) {
        self.libelle = libelle
        self.part = min(max(part, 0), 1)
        self.detail = detail
        self.seuilVigilance = seuilVigilance
        self.seuilDanger = seuilDanger
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Trame.fin) {
            HStack(spacing: Trame.serre) {
                Text(libelle)
                    .mention()
                    .foregroundStyle(Teinte.encreDouce)
                Spacer(minLength: 0)
                Text(pourcentage)
                    .donneePetite()
                    .foregroundStyle(ton == .neutre ? Teinte.encreDouce : ton.teinte)
                    .contentTransition(.numericText())
            }
            trait
            if let detail {
                Text(detail)
                    .mention()
                    .foregroundStyle(Teinte.encreTernie)
            }
        }
    }

    private var trait: some View {
        GeometryReader { cadre in
            ZStack(alignment: .leading) {
                Capsule().fill(Teinte.fondCreux)
                Capsule()
                    .fill(ton == .neutre ? Teinte.encreDouce : ton.teinte)
                    .frame(width: max(3, cadre.size.width * part))
                    .animation(Elan.pose, value: part)
            }
        }
        .frame(height: 3)
    }

    private var pourcentage: String { "\(Int((part * 100).rounded())) %" }

    private var ton: Ton {
        if part >= seuilDanger { return .danger }
        if part >= seuilVigilance { return .vigilance }
        return .neutre
    }
}
#endif
