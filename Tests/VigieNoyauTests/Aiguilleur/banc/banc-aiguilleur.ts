// Responsabilité : le nœud du banc Swift — un nœud Quart réel relié à l'aiguilleur réel. Il accepte
// automatiquement les appareils qui demandent à s'appairer et leur sert `/api/etat` dans le canal chiffré.
// Lancé par lancer-banc.sh. Variables : QUART_RACINE (worktree Quart), BANC_URL (aiguilleur),
// BANC_CODE_NOEUD, BANC_CODE_APPAREIL, BANC_CODE_INTRUS, BANC_SORTIE (fichier JSON, écrit quand le nœud est relié).
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
const requireQuart = createRequire(join(racine, 'package.json'));
const pino = requireQuart('pino');

const { servirAppareil } = await import(join(racine, 'relais/federation/appareils.ts'));
const { creerNoeud } = await import(join(racine, 'relais/federation/banc-federation.ts'));

const TABLE = {
  '/api/etat': { GET: () => Response.json({ machine: 'noeud-banc' }) },
  '/api/federation/aiguilleur': { POST: () => new Response('jamais') },
};

const noeud = creerNoeud('noeud-banc', {
  servirAppareil: servirAppareil(TABLE, pino({ enabled: false })),
});
const reponse = await noeud.federation.rejoindreAiguilleur({
  url, code: requis('BANC_CODE_NOEUD'), nom: 'noeud-banc',
});
if (!reponse.ok) throw new Error(`rejoindre : ${reponse.raison}`);

setInterval(async () => {
  for (const demande of (await noeud.federation.etat()).demandes) {
    if (demande.genre !== 'appareil') continue;
    console.log(`décision : appareil ${demande.id} accepté à ${new Date().toISOString()}`);
    noeud.federation.decider(demande.id, true);
  }
}, 100);

const fin = Date.now() + 60_000;
while (!(await noeud.federation.etat()).aiguilleur?.relie) {
  if (Date.now() > fin) throw new Error('nœud non relié au bout de 60 s');
  await Bun.sleep(100);
}

writeFileSync(requis('BANC_SORTIE'), JSON.stringify({
  adresse: url,
  codeAppareil: requis('BANC_CODE_APPAREIL'),
  codeIntrus: requis('BANC_CODE_INTRUS'),
  noeud: reponse.valeur.id,
}));
console.log(`banc prêt : nœud ${reponse.valeur.id} relié à ${url}`);
await new Promise(() => undefined);
