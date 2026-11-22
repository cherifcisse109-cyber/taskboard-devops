# Guide perso1KC — Git & GitHub + Pipeline PR (à terminer aujourd'hui, dim. 22 nov.)

Ta part pèse le plus lourd : **Git (15 %)** + **Pipeline 1 Build & Smoke sur PR** (part des 30 % Jenkins) + 3 chapitres du rapport.
Jenkins, Docker et GitHub sont déjà installés. Les étapes sont dans l'ordre : ne saute pas d'étape, chacune prépare la suivante.

## Planning de la journée

| Heure | Étape | Résultat attendu |
|---|---|---|
| 11h30 – 12h00 | 1 à 3 : dépôt, push, branches, collaborateurs | Les 3 autres peuvent cloner (ils sont débloqués) |
| 12h00 – 13h00 | 4 à 6 : identifiants, job `taskboard-pr`, webhook | Le job scanne le dépôt |
| 13h00 – 14h00 | Pause + 7 : premier test du pipeline | Premier build PR vert |
| 14h00 – 16h30 | 8 à 10 : 3 PR (réussie, échec Smoke, échec Build) | Captures des 3 cas |
| 16h30 – 17h30 | 11 à 12 : merge dans `dev`, release `main`, tags | `v1.0.0`, `v1.0.1`, `v1.0` créés |
| 17h30 – 18h30 | 13 : protection de `main` | Règle active + capture |
| 18h30 – 19h30 | 14 à 15 : captures + rapport | Dossier de preuves complet |

---

## Étape 0 — Prérequis (5 min)

Sur ta machine, ouvre un terminal et vérifie :

```bash
git --version
git config --global user.name  "Ton Nom Prénom"
git config --global user.email "ton.email@exemple.com"
```

Utilise **ton vrai nom** : l'évaluateur voit l'historique des commits.
Dézippe `taskboard-devops-project.zip` dans un dossier de ton choix (tu obtiens un dossier `devops-project/`).

## Étape 1 — Créer le dépôt GitHub (5 min)

1. GitHub → bouton **+** (en haut à droite) → **New repository**.
2. **Repository name** : `taskboard-devops`.
3. **Visibilité : choisis Public.** Sur un dépôt privé en compte gratuit, GitHub n'active pas la protection de branches (étape 13). Si le sujet impose un dépôt privé, garde Privé et ajoute une capture de ce message pour le rapport.
4. **Ne coche rien** : pas de README, pas de .gitignore, pas de licence (le projet les contient déjà).
5. Clique **Create repository**. Copie l'URL HTTPS : `https://github.com/<ton-compte>/taskboard-devops.git`.

## Étape 2 — Pousser le projet sur `main` (10 min)

```bash
cd devops-project
git init
git add .
git status          # vérifie : pas de node_modules/, pas de artifacts/
git commit -m "chore: initial commit - TaskBoard API, Dockerfile, Jenkinsfiles"
git branch -M main
git remote add origin https://github.com/<ton-compte>/taskboard-devops.git
git push -u origin main
```

GitHub ne demande plus le mot de passe de compte : utilise un **Personal Access Token** (voir étape 4) comme mot de passe, ou un client Git déjà connecté (GitHub Desktop, Git Credential Manager).
Vérifie sur GitHub : tu vois les dossiers `app/`, `scripts/`, `docs/` et les 3 `Jenkinsfile.*`.

## Étape 3 — Créer `dev` et inviter l'équipe (10 min)

```bash
git checkout -b dev
git push -u origin dev
```

Sur GitHub : **Settings → Collaborators → Add people** → ajoute les 3 pseudos GitHub de perso2AB, perso3F, Perso4 avec le rôle **Write**. Ils doivent accepter l'invitation (e-mail ou notification).

Dans **Settings → General → Default branch**, mets **`dev`** par défaut (ainsi les PR ciblent `dev` automatiquement). Confirme le changement.

> **Envoie tout de suite ce message au groupe** (ils attendent ce dépôt) :
> « Dépôt créé : https://github.com/<ton-compte>/taskboard-devops . Acceptez l'invitation, puis `git clone <url>` et `git checkout dev`. Ne poussez JAMAIS directement sur main/dev : travaillez sur une branche feature/<sujet> et ouvrez une PR vers dev. »

## Étape 4 — Token GitHub et identifiants Jenkins (10 min)

**Créer le token** : GitHub → photo de profil → **Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token (classic)**.
Nom : `jenkins-taskboard`. Expiration : 30 jours. Coche les cases **`repo`** et **`admin:repo_hook`**. Génère et **copie le token tout de suite** (il ne s'affichera plus).

**L'ajouter dans Jenkins** : Tableau de bord → **Manage Jenkins → Credentials → System → Global credentials (unrestricted) → Add Credentials** :

| Champ | Valeur |
|---|---|
| Kind | Username with password |
| Username | ton pseudo GitHub |
| Password | le token copié |
| ID | `github-pat` |
| Description | Token GitHub pour taskboard |

## Étape 5 — Créer le job `taskboard-pr` (15 min)

1. Jenkins → **New Item** → nom `taskboard-pr` → type **Multibranch Pipeline** → OK.
2. **Branch Sources → Add source → GitHub**.
   - **Credentials** : `github-pat`.
   - **Repository HTTPS URL** : `https://github.com/<ton-compte>/taskboard-devops` puis clique **Validate** (doit afficher « Credentials ok »).
3. **Behaviours** : supprime **Discover branches** (croix rouge) et **Discover pull requests from forks**. Garde **Discover pull requests from origin** (option « Merging the pull request with the current target branch revision »).
4. **Build Configuration** : Mode = *by Jenkinsfile*, **Script Path = `Jenkinsfile.pr`** (attention à la casse).
5. **Scan Multibranch Pipeline Triggers** : coche *Periodically if not otherwise run* → **1 minute** (filet de sécurité si le webhook ne passe pas).
6. **Save**. Jenkins lance un premier scan : le journal doit se terminer par `Finished: SUCCESS`. Aucune PR n'existe encore, c'est normal que la liste soit vide.

Pourquoi supprimer « Discover branches » : ce job ne doit réagir qu'aux Pull Requests ; sinon il créerait des builds vides pour `main` et `dev`.

## Étape 6 — Le webhook GitHub → Jenkins (15 min)

**D'abord, une question : GitHub peut-il joindre ton Jenkins ?**
- Jenkins sur un serveur avec une adresse publique : URL = `http://<adresse>:8080/github-webhook/`.
- Jenkins en local (`localhost:8080`) : GitHub ne peut pas l'atteindre. Lance `ngrok http 8080`, copie l'URL `https://xxxx.ngrok-free.app` et utilise `https://xxxx.ngrok-free.app/github-webhook/`.
- Impossible ni l'un ni l'autre : passe cette étape, le scan toutes les minutes (étape 5) fait le travail, et tu le dis honnêtement dans le rapport.

**Configurer** : GitHub → dépôt → **Settings → Webhooks → Add webhook** :

| Champ | Valeur |
|---|---|
| Payload URL | l'URL ci-dessus, **avec le `/` final** |
| Content type | `application/json` |
| Which events | **Let me select individual events** : coche **Pushes**, **Pull requests** et **Branch or tag creation** ; décoche le reste |
| Active | coché |

**Vérifier** : onglet **Recent Deliveries** → clique la livraison « ping » → **Response 200** (icône verte). Prends une capture.
Si rouge : erreur 403 ou 404 → vérifie l'URL (le `/` final est obligatoire) ; timeout → Jenkins n'est pas joignable depuis Internet (voir ngrok ci-dessus).

## Étape 6 bis — Si Jenkins tourne dans Docker (2 min de vérification)

Les smoke tests appellent `http://localhost:30xx`. Si **Jenkins est lui-même dans un conteneur**, `localhost` désigne le conteneur Jenkins et non ton hôte Docker : le smoke échouera partout avec `[FAILED]` alors que les conteneurs tournent bien.
Solution (déjà prévue dans les Jenkinsfiles) : **Manage Jenkins → System → Global properties → Environment variables → Add** : nom `SMOKE_HOST`, valeur `host.docker.internal` (ou l'IP de l'hôte Docker). Si Jenkins est installé directement sur la machine, ne fais rien : la valeur par défaut est `localhost`.

---

## Étape 7 — Premier test du pipeline avec une PR simple (30 min)

Objectif : prouver que Jenkins voit une PR et exécute les 7 stages. Cette PR est aussi **la PR n°1 du rapport** (branche `feature/readme-equipe`).

```bash
git checkout dev
git pull origin dev
git checkout -b feature/readme-equipe
```

Ouvre `README.md`, ajoute sous le titre une section :

```markdown
## Équipe
- perso1KC : Git & GitHub, pipeline PR
- perso2AB : Jenkins, pipeline dev
- perso3F : Docker, pipeline tag
- Perso4 : smoke tests, rapport
```

```bash
git add README.md
git commit -m "docs: ajout de la section equipe dans le README"
git push -u origin feature/readme-equipe
```

Sur GitHub, le bandeau jaune « Compare & pull request » apparaît : clique-le, **base : `dev`** ← compare : `feature/readme-equipe`. Titre : `docs: ajout de la section équipe`. **Create pull request**.

Dans Jenkins : `taskboard-pr` → clique **Scan Multibranch Pipeline Now** si rien n'apparaît ; l'entrée `PR-1` apparaît, ouvre-la → build `#1`. Regarde **Stage View** ou **Pipeline Overview** : 7 stages, et dans Build / Run / Smoke **2 branches parallèles** (Node 20 et Node 22).
Premier build : compte 3 à 6 minutes (téléchargement des images Node).

Sur la page de la PR GitHub, en bas, une ligne `continuous-integration/jenkins/pr-merge` passe de jaune à verte.

**Si ça échoue**, regarde **Console Output** et cherche la première ligne en erreur :

| Message | Cause | Solution |
|---|---|---|
| `docker: command not found` / `permission denied ... docker.sock` | Jenkins n'a pas accès à Docker | ajouter l'utilisateur `jenkins` au groupe `docker` puis redémarrer Jenkins |
| `curl: command not found` | `curl` absent de l'agent | l'installer sur l'agent / le conteneur |
| `port is already allocated` | un autre build tient déjà les ports 3020 / 3022 | attendre la fin de l'autre build (voir note ci-dessous) |
| `[FAILED] ... -> 200` partout, conteneurs « Up » | problème `localhost` (étape 6 bis) | définir `SMOKE_HOST` |
| Aucun build ne démarre | mauvais Script Path | vérifier `Jenkinsfile.pr` dans la config du job |
| `ERROR: ... GitHub API rate limit` | identifiants non appliqués | vérifier `github-pat` dans la source de branche |

> **Note ports** : les 3 pipelines utilisent les mêmes ports (3018 / 3020 / 3022). Ne lance pas un build PR **en même temps** qu'un build dev ou tag : préviens perso2AB et perso3F quand tu lances tes builds.

---

## Étape 8 — PR n°2 : une vraie fonctionnalité qui réussit (30 min)

Fonctionnalité : suppression d'une tâche via `DELETE /todos/:id`. Ce code a été testé : 6 tests sur 6 passent.

```bash
git checkout dev && git pull origin dev
git checkout -b feature/delete-todo
```

**Dans `app/server.js`**, repère la dernière ligne avant la fin de la fonction :
`    return send(res, 404, { error: 'not found' });`
et remplace-la par :

```javascript
    const m = req.url.match(/^\/todos\/(\d+)$/);
    if (req.method === 'DELETE' && m) {
      const idx = todos.findIndex((t) => t.id === Number(m[1]));
      if (idx === -1) return send(res, 404, { error: 'todo not found' });
      todos.splice(idx, 1);
      res.writeHead(204);
      return res.end();
    }
    return send(res, 404, { error: 'not found' });
```

**À la fin de `app/test/api.test.js`**, ajoute :

```javascript

test('DELETE /todos/:id supprime une tache puis retourne 404', async () => {
  const created = await (await fetch(`${base}/todos`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: 'a supprimer' }),
  })).json();
  const del = await fetch(`${base}/todos/${created.id}`, { method: 'DELETE' });
  assert.strictEqual(del.status, 204);
  const again = await fetch(`${base}/todos/${created.id}`, { method: 'DELETE' });
  assert.strictEqual(again.status, 404);
});
```

**Teste en local avant de pousser** (réflexe : ne jamais envoyer une PR non testée) :

```bash
cd app && npm test && cd ..
```

Tu dois lire `# pass 6` et `# fail 0`. Puis :

```bash
git add app/server.js app/test/api.test.js
git commit -m "feat: ajout de la suppression d'une tache (DELETE /todos/:id)"
git push -u origin feature/delete-todo
```

Ouvre la PR (**base : `dev`**) et attends le build vert. **Demande à un coéquipier de relire et d'approuver** (**Files changed → Review changes → Approve**) : il en faudra une preuve pour le rapport. Ne merge pas encore.

## Étape 9 — Cas d'échec n°1 : le smoke test forcé (15 min)

Sur la PR n°2, dans Jenkins : `taskboard-pr` → `PR-2` → **Build with Parameters** (visible après le premier build) → coche **FORCE_SMOKE_FAIL** → **Build**.
Résultat attendu : le stage **Smoke Test est rouge**, les stages **Archive Artifacts** et **Cleanup** s'exécutent quand même, le build est **FAILURE**. Va dans **Build Artifacts** : tu y trouves `artifacts/smoke-node20.txt` avec la ligne `[FAILED] Cas force en echec` et `RESULT: FAILED`.
Capture : (a) Stage View avec le stage rouge, (b) le contenu du fichier smoke. Relance ensuite un build normal (**Build Now**) pour revenir au vert avant de merger.

## Étape 10 — Cas d'échec n°2 : le Build qui casse (20 min)

Cette PR **ne sera jamais mergée** : elle sert à montrer un test unitaire qui échoue pendant `docker build`.

```bash
git checkout dev && git pull origin dev
git checkout -b feature/break-health
```

Dans `app/server.js`, remplace `{ status: 'UP' }` par `{ status: 'DOWN' }` (une seule occurrence), puis :

```bash
git add app/server.js
git commit -m "test: casse volontaire de /health pour demontrer un echec de build"
git push -u origin feature/break-health
```

Ouvre la PR vers `dev` et laisse Jenkins la construire. Résultat attendu : le stage **Build est rouge** (le `RUN npm test` du Dockerfile échoue), les stages Run / Smoke / Archive sont **ignorés**, Cleanup s'exécute, la PR GitHub affiche une croix rouge.
Capture : (a) Stage View, (b) Console Output avec la ligne `not ok 1 - GET /health retourne UP`, (c) la PR avec la croix rouge.
Puis **ferme la PR sans la merger** (*Close pull request*) et supprime la branche. Tu peux ainsi expliquer dans le rapport que la CI a bloqué un code défectueux.

---

## Étape 11 — Fusionner dans `dev` (15 min)

Merge les PR n°1 (`feature/readme-equipe`) et n°2 (`feature/delete-todo`) avec **Merge pull request** (pas de force push, pas de commit direct). Chaque merge déclenche un push sur `dev` : le pipeline de perso2AB se lance, préviens-le. Attends qu'il soit fini avant l'étape suivante.

## Étape 12 — Release sur `main` et tags (30 min)

1. **PR de release** : GitHub → **New pull request** → base `main` ← compare `dev`, titre `release: v1.0.0`. Si la protection n'est pas encore active, merge avec **Create a merge commit**.
2. **Tag v1.0.0** (sur `main`, la version de `app/package.json` vaut déjà 1.0.0 : le pipeline tag compare les deux) :

```bash
git checkout main && git pull origin main
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
```

3. **Version 1.0.1** : crée `feature/bump-1.0.1` depuis `dev`, change `"version": "1.0.0"` en `"1.0.1"` dans `app/package.json`, commit `chore: bump version 1.0.1`, PR → `dev` → merge, puis PR `dev` → `main` → merge, puis :

```bash
git checkout main && git pull origin main
git tag -a v1.0.1 -m "Release 1.0.1"
git push origin v1.0.1
```

4. **Tag invalide** pour la démonstration : `git tag v1.0 && git push origin v1.0`. Le pipeline tag de perso3F l'ignore (stage ignoré car le motif `vX.Y.Z` ne correspond pas). Dis à perso3F quand tes tags sont poussés, pour qu'il fasse **Scan Repository Now** sur son job.
5. Vérifie : GitHub → **Releases / Tags** liste `v1.0.0`, `v1.0.1`, `v1.0`. Capture.

## Étape 13 — Protéger `main` (15 min)

Fais-le **après** le premier build PR vert (étape 7) : la vérification Jenkins n'apparaît dans la liste qu'une fois qu'elle a existé au moins une fois.

GitHub → **Settings → Branches → Add branch ruleset** (ou *Add classic branch protection rule* → pattern `main`) :

- ✔ **Require a pull request before merging** → **Required approvals : 1**
- ✔ **Require status checks to pass before merging** → cherche **`continuous-integration/jenkins/pr-merge`** et ajoute-le
- ✔ **Block force pushes** (déjà actif par défaut dans un ruleset)
- ✔ **Restrict deletions**
- Enforcement status : **Active**

Pour `dev` : règle plus légère, **Require a pull request before merging** seulement (0 approbation), pour ne pas bloquer l'équipe.

**Test de la protection** (c'est la preuve attendue) : essaie `git push origin main` directement depuis ta machine après un petit commit local. Tu dois recevoir `remote: error: GH013: Repository rule violations` ou `protected branch hook declined`. **Capture cet écran** ; puis annule ton commit local (`git reset --hard origin/main`).

---

## Étape 14 — Dossier de preuves : liste des captures

Crée un dossier `captures/` et nomme les fichiers ainsi :

| N° | Contenu | Fichier |
|---|---|---|
| 1 | Page du dépôt avec les dossiers | `01-depot.png` |
| 2 | Liste des branches (`main`, `dev`, `feature/*`) | `02-branches.png` |
| 3 | Collaborateurs invités | `03-collaborateurs.png` |
| 4 | Webhook : Recent Deliveries en 200 | `04-webhook.png` |
| 5 | Configuration du job `taskboard-pr` (Behaviours + Script Path) | `05-config-job.png` |
| 6 | PR n°1 et sa vérification Jenkins verte | `06-pr1-verte.png` |
| 7 | Stage View du build vert, branches parallèles Node 20 / 22 | `07-stages-verts.png` |
| 8 | PR n°2 avec l'approbation du coéquipier | `08-pr2-review.png` |
| 9 | Stage Smoke rouge (FORCE_SMOKE_FAIL) + fichier smoke `[FAILED]` | `09-smoke-failed.png` |
| 10 | PR n°3 : Build rouge + log `not ok` | `10-build-failed.png` |
| 11 | Artefacts archivés d'un build vert | `11-artefacts.png` |
| 12 | `git log --oneline --graph --all` | `12-git-graph.png` |
| 13 | Liste des tags | `13-tags.png` |
| 14 | Règle de protection de `main` | `14-protection.png` |
| 15 | Push direct refusé | `15-push-refuse.png` |

Pour la capture 12 : `git log --oneline --graph --all --decorate`.

## Étape 15 — Rédiger tes chapitres du rapport (le soir)

Tu écris 3 chapitres, avec les captures ci-dessus. Plan de chacun :

**Chapitre 3 — Workflow Git (2–3 p.)** : stratégie de branches (`main` stable, `dev` intégration, `feature/*` travail) ; schéma ; règle « tout passe par PR » ; protection de `main` (captures 14-15) ; revue de code (capture 8) ; convention de messages de commit (`feat:`, `fix:`, `docs:`, `chore:`).
**Chapitre 4 — Versionning (1–2 p.)** : versionnage sémantique `MAJOR.MINOR.PATCH` ; tags annotés `vX.Y.Z` ; lien entre `package.json` et le tag (vérifié par le pipeline) ; exemple `v1.0.0`, `v1.0.1` et rejet de `v1.0` (capture 13).
**Chapitre 6 — Pipeline 1 : Build & Smoke sur PR (2 p.)** : déclencheur (PR vers `dev` + webhook) ; les 7 stages et leur rôle ; parallélisation Node 20 / 22 ; trois cas : PR réussie (captures 6-7), échec Smoke (9), échec Build (10) ; artefacts (11).

Quand tu as fini les étapes, envoie-moi tes captures et tes notes : je rédige les chapitres avec toi.

---

## En cas de blocage
Copie-moi **le message d'erreur exact** (Console Output de Jenkins ou terminal) et l'étape où tu en es : je te donne la correction.
