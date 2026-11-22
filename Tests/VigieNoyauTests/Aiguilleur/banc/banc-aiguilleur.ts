// Responsabilité : le nœud du banc Swift — un nœud Quart réel relié à l'aiguilleur réel. Il accepte
// automatiquement les appareils qui demandent à s'appairer et leur sert `/api/etat` dans le canal chiffré.
// Lancé par lancer-banc.sh. Variables : QUART_RACINE (worktree Quart), BANC_URL (aiguilleur),
// BANC_CODE_NOEUD, BANC_CODE_APPAREIL, BANC_CODE_INTRUS, BANC_SORTIE (fichier JSON, écrit quand le nœud est relié).
// Scénarios de l'API : `/api/banc/image` (un PNG de ~480 Ko, écrit à côté du JSON), `/api/banc/diffuser` (deux deltas
// de texte et un événement), et un terminal d'écho sur la machine « noeud-banc ».
import { writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';

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
const { creerNoeud, ficheDe } = await import(join(racine, 'relais/federation/banc-federation.ts'));
const { pngDeBruit } = await import(join(racine, 'relais/federation/banc-png.ts'));
const sortie = requis('BANC_SORTIE');
const png = pngDeBruit(400);
writeFileSync(join(dirname(sortie), 'image.png'), png);

const TABLE = {
  '/api/etat': { GET: () => Response.json({ machine: 'noeud-banc' }) },
  '/api/federation/aiguilleur': { POST: () => new Response('jamais') },
  '/api/banc/image': { GET: () => new Response(png, { headers: { 'content-type': 'image/png' } }) },
  '/api/banc/diffuser': {
    POST: () => {
      noeud.diffusion.diffuser({ type: 'flux', sessionId: 's1', bloc: 'b', delta: 'Bon' });
      noeud.diffusion.diffuser({ type: 'flux', sessionId: 's1', bloc: 'b', delta: 'jour' });
      noeud.diffusion.diffuser({ type: 'session', session: ficheDe('s1', 'noeud-banc', 'Titre') });
      return Response.json({ ok: true });
    },
  },
};

const noeud = creerNoeud('noeud-banc', {
  servirAppareil: servirAppareil(TABLE, pino({ enabled: false })),
});
noeud.federation.terminaux.brancher({
  ouvert: async (ws: { send: (d: string | Uint8Array) => unknown }) => {
    ws.send(new TextEncoder().encode('$ '));
    return true;
  },
  recu: (ws: { send: (d: string | Uint8Array) => unknown }, message: string | Buffer) => {
    if (typeof message !== 'string') ws.send(message);
  },
  ferme: () => undefined,
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

writeFileSync(sortie, JSON.stringify({
  adresse: url,
  codeAppareil: requis('BANC_CODE_APPAREIL'),
  codeIntrus: requis('BANC_CODE_INTRUS'),
  codeAppareil2: requis('BANC_CODE_APPAREIL2'),
  noeud: reponse.valeur.id,
  image: join(dirname(sortie), 'image.png'),
}));
console.log(`banc prêt : nœud ${reponse.valeur.id} relié à ${url}`);
await new Promise(() => undefined);
