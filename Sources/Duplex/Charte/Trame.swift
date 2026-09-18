// La grille et les galbes viennent du socle `Systeme` (`Grille`, `Rayon`) et les
// écrans les écrivent directement. Ne restent ici que les dimensions propres au
// monde — des tailles de composant, pas des espacements : la grille de 4 pt
// gouverne les distances, pas la taille d'un anneau.
#if canImport(SwiftUI)
import CoreGraphics

public enum Trame {
    /// Le diamètre de l'anneau d'écoute, le seul grand objet du monde. Assez
    /// large pour être touché sans viser, assez petit pour laisser la page vide.
    public static let anneau: CGFloat = 136
    /// L'épaisseur du trait de l'anneau : visible de loin, pas un cerne.
    public static let traitAnneau: CGFloat = 3
    /// La hauteur d'une cellule du code — au-dessus de la cible tactile, parce
    /// qu'on la regarde plus qu'on ne la touche.
    public static let cellule: CGFloat = 56
    /// La jauge du tampon : un fil, pas une barre de progression.
    public static let jauge: CGFloat = 4
    /// Sa longueur, bornée : une jauge pleine largeur prendrait l'écran.
    public static let jaugeLargeur: CGFloat = 160
}
#endif
