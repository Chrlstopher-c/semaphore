# Charte — Lueur

Lueur pilote le ruban de LED de la chambre (contrôleur ELK-BLEDOM) par le serveur Lueur du Pi. Un seul écran,
un seul focal : **la roue chromatique**, avec l'interrupteur en son cœur.

- **Accent** : orange incandescent `#FF8A3D` — la lueur d'un filament. Seul creux libre après le violet d'EchoHub,
  le rose de Saily, la turquoise de Duplex, le bleu d'Iris et le lime de Tamis ; plus saturé et plus rouge que
  l'ambre `Semantique.alerte`. Il ne porte que le chrome (sélecteur de monde, pickers système).
- **La couleur vivante** (celle du ruban) n'est pas un jeton : elle peint le curseur, le halo derrière la roue
  (un seul halo, flou fixe, jamais animé) et le glyphe de l'interrupteur. Éteint, tout retombe en `Neutre`.
- **États** : vert = ruban relié ; ambre = serveur joint mais ruban injoignable ; rouge = serveur injoignable.
- **Typo** : `Voix` du socle ; valeurs des curseurs en `Voix.mesure`.
- **Motion** : `Mouvement.micro` sur la roue et les pastilles, `normal` sur l'allumage ; haptique `selection`
  sur une pastille ou un effet, `engage` sur l'interrupteur, `butee` quand une trame n'atteint pas le ruban.
