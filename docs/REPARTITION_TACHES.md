# Répartition des tâches — équipe de 4 — début : sam. 21 nov. 2026 — rendu : sam. 5 déc. 2026

Équipe : **perso1KC**, **perso2AB**, **perso3F**, **Perso4**.
Jenkins, Docker et GitHub sont **déjà installés** : on commence directement par la configuration et les pipelines.
Objectif interne : toutes les exécutions et captures terminées le **mer. 2 déc.**, rapport finalisé le 3-4 déc., marge de sécurité avant le 5.

Barème : Git 15 % · Jenkins 30 % · Docker 25 % · Smoke/artefacts 15 % · Rapport & présentation 15 %.
Chacun est **responsable** d'un bloc, mais tout le monde doit pouvoir l'expliquer à l'oral (présentation de 10 min).

Charge estimée : perso1KC ≈ 32 % · perso2AB ≈ 22 % · perso3F ≈ 24 % · Perso4 ≈ 22 %.

## perso1KC — Git & GitHub + pipeline PR (charge la plus importante)
**Git (15 %)**

- Pousser le projet fourni (zip) dans le dépôt, créer `main` et `dev`, ajouter les 3 autres comme collaborateurs.
- Protéger `main` (PR obligatoire, 1 review, status check Jenkins, pas de push direct).
- Faire au moins 3 branches `feature/*` avec PR vers `dev` (captures des PR, `git log --graph`).
- Créer les tags `v1.0.0`, `v1.0.1` et un tag invalide (`v1.0`) pour montrer qu'il est ignoré.
- Configurer le webhook GitHub → Jenkins (événements push, pull request).

**Pipeline 1 : Build & Smoke sur PR (part du 30 % Jenkins)**

- Créer le job `taskboard-pr` (Multibranch, *Discover pull requests*), valider `Jenkinsfile.pr`.
- Exécuter : 1 PR réussie, 1 PR en échec (`FORCE_SMOKE_FAIL=true`). Capturer chaque stage et les branches parallèles Node 20 / 22.
- **Rapport** : Workflow Git, Branches, Versionning, Pipeline 1 (PR).

## perso2AB — Jenkins : configuration + pipeline dev
- Vérifier la configuration Jenkins existante : plugins nécessaires (Pipeline, GitHub Branch Source, Timestamper), accès Docker de l'agent, credentials GitHub.
- Créer le job `taskboard-dev` (Multibranch, filtre `dev`), valider `Jenkinsfile.dev`.
- Exécuter : 1 push dev réussi, 1 push dev en échec (`FORCE_SMOKE_FAIL=true`), puis un build parallèle 18 / 20 / 22 avec captures.
- Réaliser le schéma d'architecture globale du pipeline (GitHub → Jenkins → Docker → artefacts).
- **Rapport** : Architecture du pipeline, Stages, Triggers, Pipeline 2 (dev).

## perso3F — Docker + pipeline tag (25 % + part des 30 %)
- Valider `app/Dockerfile` : `docker build`, taille des images, comparaison Node 18/20/22.
- **Performance de build** : démontrer le cache (2ᵉ build plus rapide), effet du `.dockerignore`, tableau de temps avant/après.
- Créer le job `taskboard-tag`, valider `Jenkinsfile.tag`, exécuter `v1.0.0` (succès) et un cas d'échec (tag ≠ version de `package.json`).
- Vérifier les artefacts archivés (images `.tar.gz`, `SHA256SUMS.txt`).
- **Rapport** : Dockerfile, Performance de build, Pipeline 3 (tag).

## Perso4 — Smoke tests, artefacts, rapport & présentation (15 % + 15 %)
- Maîtriser `scripts/smoke.sh`, ajouter 1–2 cas de smoke, compléter les tests unitaires.
- Tableau récapitulatif Passed/Failed par stage et par pipeline (à partir des exécutions des 3 autres).
- Captures des artefacts archivés dans Jenkins (logs, résultats smoke, `pipeline-report.txt`).
- **Coordination du rapport (15–20 pages)** : assemblage, sommaire, cohérence, relecture.
- Préparer la présentation de 10 min et répéter (démo : un build Passed + un build Failed).

## Planning

| Date | Jalons | Qui |
|---|---|---|
| Sam. 21 – dim. 22 nov. | Projet poussé sur GitHub, tous clonent ; branches `main`/`dev` ; premiers `docker build` locaux ; tests locaux ; vérification de la config Jenkins | KC, F, Perso4, AB |
| Lun. 23 – mer. 25 nov. | Webhook ; jobs `taskboard-pr`, `taskboard-dev`, `taskboard-tag` ; première exécution de chaque pipeline ; protection de `main` | KC, AB, F |
| Jeu. 26 – dim. 29 nov. | PR et tags « officiels » avec captures ; cas Failed ; mesures de performance Docker ; début du rapport (parties individuelles) | tous |
| Lun. 30 nov. – mar. 1er déc. | Corrections, ré-exécutions si besoin, tableau Passed/Failed complet | Perso4 + chaque responsable |
| **Mer. 2 déc.** | **Gel des exécutions** : captures et artefacts prêts | tous |
| Jeu. 3 – ven. 4 déc. | Assemblage du rapport, relecture croisée, répétition chronométrée (10 min) | Perso4 coordonne |
| **Sam. 5 déc.** | **Rendu** | tous |

## Plan du rapport (15–20 pages)

1. Introduction et choix de l'application (1 p.) — Perso4
2. Architecture globale du pipeline, schéma (2 p.) — perso2AB
3. Workflow Git : branches, PR, protection (2–3 p.) — perso1KC
4. Versionning et tags (1–2 p.) — perso1KC
5. Dockerfile et performance de build (3 p.) — perso3F
6. Pipeline 1 : Build & Smoke sur PR (2 p.) — perso1KC
7. Pipeline 2 : Build complet sur push dev (2 p.) — perso2AB
8. Pipeline 3 : Build versionné + artefacts (2 p.) — perso3F
9. Smoke tests et statuts Passed/Failed (2 p.) — Perso4
10. Difficultés rencontrées, conclusion (1 p.) — tous

## Règles d'équipe
- Aucun push direct sur `main` ni `dev` : tout passe par PR.
- Chacun fait ses propres commits avec des messages clairs (l'historique est visible par l'évaluateur).
- Chaque responsable rédige sa partie du rapport au fil de l'eau, pas à la fin.
- En cas de blocage Jenkins/Docker : copier le log d'erreur et me l'envoyer.
