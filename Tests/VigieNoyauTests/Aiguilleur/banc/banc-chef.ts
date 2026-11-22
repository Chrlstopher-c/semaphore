// Responsabilité : les deux nœuds du banc du téléphone chef — « portable » (chef du réseau, avec écran) et « tour »
// (sans écran, pas chef), reliés à l'aiguilleur réel et appariés. Le portable crée la charte, accepte les appareils
// (ils entrent comme téléphones) et nomme chef le PREMIER téléphone admis ; la tour accepte d'office les membres
// reconnus. `/api/banc/etat` rend aux appareils la version de la charte de chaque nœud et la pause du portable.
// Lancé par lancer-banc.sh (BANC_SCRIPT=banc-chef.ts). Variables : QUART_RACINE, BANC_URL, BANC_CODE_NOEUD,
// BANC_CODE_APPAREIL (téléphone chef), BANC_CODE_APPAREIL2 (téléphone non chef), BANC_CODE_APPAREIL4 (la tour),
// BANC_SORTIE (fichier JSON, écrit quand tout est prêt).
import { writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join } from 'node:path';

function requis(nom: string): string {
  const valeur = process.env[nom];
  if (!valeur) throw new Error(`variable absente : ${nom}`);
  return valeur;
}

const racine = requis('QUART_RACINE');
const url = requis('BANC_URL');
const pino = createRequire(join(racine, 'package.json'))('pino');
const { servirAppareil } = await import(join(racine, 'relais/federation/appareils.ts'));
const { creerNoeud } = await import(join(racine, 'relais/federation/banc-federation.ts'));
const { nommerChef } = await import(join(racine, 'commun/charte.ts'));

type Noeud = ReturnType<typeof creerNoeud>;
const silencieux = pino({ enabled: false });

function pauseDe(n: Noeud): boolean {
  // Accès d'essai : le drapeau de pause vit dans le câblage privé des machines du nœud.
  const interne = n.federation as unknown as { machines: { pause: { enPause(): boolean } } };
  return interne.machines.pause.enPause();
}

function table() {
  return {
    '/api/banc/etat': {
      GET: () =>
        Response.json({
          portable: portable.federation.charte.charte()?.version ?? 0,
          tour: tour.federation.charte.charte()?.version ?? 0,
          pausePortable: pauseDe(portable),
        }),
    },
  };
}

const portable: Noeud = creerNoeud('portable', { servirAppareil: servirAppareil(table(), silencieux) });
const tour: Noeud = creerNoeud('tour', { servirAppareil: servirAppareil(table(), silencieux) });

async function rejoindre(n: Noeud, code: string, sansEcran: boolean): Promise<string> {
  const r = await n.federation.rejoindreAiguilleur({ url, code, nom: n.nom, sansEcran });
  if (!r.ok) throw new Error(`rejoindre ${n.nom} : ${r.raison}`);
  return r.valeur.id;
}

async function attendre(condition: () => Promise<boolean> | boolean, quoi: string, ms = 60_000): Promise<void> {
  const fin = Date.now() + ms;
  while (!(await condition())) {
    if (Date.now() > fin) throw new Error(`délai dépassé : ${quoi}`);
    await Bun.sleep(100);
  }
}

const idPortable = await rejoindre(portable, requis('BANC_CODE_NOEUD'), false);
const idTour = await rejoindre(tour, requis('BANC_CODE_APPAREIL4'), true);
const creee = await portable.federation.charte.creer('Réseau du banc');
if (!creee.ok) throw new Error(`charte : ${creee.raison}`);

await attendre(async () => (await portable.federation.etat()).membres.some((m) => m.id === idTour && m.enLigne),
  'la tour en ligne');
const appairage = portable.federation.appairer(idTour);
if (!appairage.ok) throw new Error(`appairer : ${appairage.raison}`);
await attendre(async () => (await tour.federation.etat()).demandes.length > 0, 'demande de la tour');
tour.federation.decider((await tour.federation.etat()).demandes[0]?.id ?? '', true);
await attendre(() => tour.federation.charte.charte()?.version === portable.federation.charte.charte()?.version,
  'la tour adopte la charte');

/** Le portable accepte les appareils ; le premier téléphone de la charte devient chef (signé par le portable). */
let chefNomme = false;
setInterval(async () => {
  for (const demande of (await portable.federation.etat()).demandes) {
    if (demande.genre === 'appareil') portable.federation.decider(demande.id, true);
  }
  const charte = portable.federation.charte.charte();
  const premier = charte?.membres.find((m) => m.sorte === 'telephone');
  if (chefNomme || !charte || !premier) return;
  chefNomme = true;
  const r = await portable.federation.charte.editer((c, moi, le) => nommerChef(c, moi, premier.id, true, le));
  console.log(`téléphone ${premier.id} nommé chef : ${r.ok ? 'oui' : r.raison}`);
}, 100);

writeFileSync(requis('BANC_SORTIE'), JSON.stringify({
  adresse: url,
  codeAppareil: requis('BANC_CODE_APPAREIL'),
  codeIntrus: requis('BANC_CODE_INTRUS'),
  codeAppareil2: requis('BANC_CODE_APPAREIL2'),
  codeAppareil3: requis('BANC_CODE_APPAREIL3'),
  codeAppareil4: requis('BANC_CODE_APPAREIL4'),
  noeud: idPortable,
  tour: idTour,
  image: '',
}));
console.log(`banc chef prêt : portable ${idPortable} (chef), tour ${idTour}`);
await new Promise(() => undefined);
