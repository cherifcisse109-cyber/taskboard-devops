# TaskBoard API — Projet DevOps (ISG Sousse, 3 LIG)
## Équipe
- perso1KC : Git & GitHub, pipeline PR
- perso2AB : Jenkins, pipeline dev
- perso3F : Docker, pipeline tag
- Perso4 : smoke tests, rapport

Pipeline CI/CD autour d'une petite API REST Node.js (sans dépendance externe) avec **Git/GitHub, Jenkins, Docker**.

## L'application

| Route | Description |
|---|---|
| `GET /health` | état du service → `{"status":"UP"}` |
| `GET /version` | nom, version (package.json), version de Node |
| `GET /todos` | liste des tâches |
| `POST /todos` | crée une tâche (`{"title":"..."}`), 400 si titre absent |

```bash
cd app && npm test        # 5 tests unitaires (node:test)
cd app && npm start       # http://localhost:3000
```

## Structure

```
.
├── app/
│   ├── server.js            # API
│   ├── test/api.test.js     # tests unitaires
│   ├── package.json         # version = source de vérité du versionning
│   ├── Dockerfile           # multi-stage (build+tests -> runtime non-root), ARG NODE_VERSION
│   └── .dockerignore
├── scripts/smoke.sh         # smoke test : [PASSED]/[FAILED] + code retour
├── Jenkinsfile.pr           # Pipeline 1 : Build & Smoke sur PR vers dev
├── Jenkinsfile.dev          # Pipeline 2 : Build complet sur push dev
├── Jenkinsfile.tag          # Pipeline 3 : Build versionné sur tag vX.Y.Z + archivage
└── docs/REPARTITION_TACHES.md
```

## Les 3 pipelines

Tous suivent : **Checkout → Setup → Build → Run (Docker) → Smoke Test → Archive Artifacts → Cleanup** (7 stages, Cleanup dans `post { always }`).

| Pipeline | Déclencheur | Versions Node (parallèle) | Spécificité |
|---|---|---|---|
| `Jenkinsfile.pr` | PR ouverte vers `dev` (`changeRequest target: 'dev'`) | 20, 22 | build rapide + smoke |
| `Jenkinsfile.dev` | push sur `dev` (`branch 'dev'`) | 18, 20, 22 | build complet |
| `Jenkinsfile.tag` | tag `vX.Y.Z` (`tag pattern` regex) | 18, 20, 22 | vérifie tag = version `package.json`, `docker save` des images, `SHA256SUMS.txt` |

Points communs :
- **Parallélisation** : un build / run / smoke par version de Node (`parallel`).
- **Smoke** : `scripts/smoke.sh` → 6 cas, `RESULT: PASSED|FAILED`. Le stage est marqué FAILED (`catchError`) mais le pipeline continue pour **archiver les preuves** même en échec.
- **Démo d'un build FAILED** : lancer le job avec le paramètre `FORCE_SMOKE_FAIL=true`.
- **Artefacts archivés** : `artifacts/logs/` (build + conteneurs), `artifacts/smoke-node*.txt`, `artifacts/pipeline-report.txt` (+ images `.tar.gz` pour le tag).

## Workflow Git

- `main` : protégée (PR obligatoire, 1 review, status check Jenkins requis, pas de push direct).
- `dev` : branche d'intégration. Les PR `feature/*` → `dev` déclenchent le pipeline PR.
- `feature/<sujet>` : une branche par fonctionnalité/tâche.
- Release : PR `dev` → `main`, puis `git tag -a v1.0.0 -m "Release 1.0.0" && git push origin v1.0.0`.
- Commits conventionnels conseillés : `feat:`, `fix:`, `ci:`, `docs:`, `chore:`.

```bash
git init && git add . && git commit -m "chore: initial commit"
git branch -M main && git remote add origin <URL_GITHUB> && git push -u origin main
git checkout -b dev && git push -u origin dev
git checkout -b feature/exemple dev
```

## Mise en place Jenkins

1. Jenkins avec **Docker accessible** par l'agent (utilisateur `jenkins` dans le groupe `docker`, ou socket monté). `curl` et `git` requis sur l'agent.
2. Plugins : *Pipeline*, *Git*, *GitHub Branch Source*, *Docker Pipeline* (optionnel), *Timestamper*.
3. Créer **3 jobs Multibranch Pipeline** pointant sur le dépôt GitHub :

| Job | Script Path | Behaviours (Branch Sources) |
|---|---|---|
| `taskboard-pr` | `Jenkinsfile.pr` | *Discover pull requests from origin* ; filtrer les branches : aucune |
| `taskboard-dev` | `Jenkinsfile.dev` | *Discover branches* avec filtre `dev` |
| `taskboard-tag` | `Jenkinsfile.tag` | *Discover tags* ; filtre `v*` |

4. Webhook GitHub → `http://<jenkins>/github-webhook/` (événements : push, pull request). Si Jenkins est en local, utiliser un tunnel (ngrok) ou le *Scan Multibranch Pipeline Triggers* périodique.
5. Si Jenkins tourne **lui-même dans un conteneur**, `localhost:30xx` dans `smoke.sh` doit pointer vers l'hôte Docker (adapter `BASE_URL`, ex. `host.docker.internal`).

## État de validation

Testé dans l'environnement de génération : tests unitaires (5/5 OK), `smoke.sh` en cas **PASSED** (exit 0) et **FAILED** (exit 1, via `SMOKE_FORCE_FAIL=1`).
**Non testé ici** : `docker build` et exécution réelle des Jenkinsfiles (pas de Jenkins ni de réseau dans l'environnement). À valider par l'équipe sur votre Jenkins, et à corriger si besoin (les captures d'écran du rapport doivent venir de vos vraies exécutions).
