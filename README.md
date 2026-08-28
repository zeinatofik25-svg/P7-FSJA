<p align="center">
   <img src="./front/src/favicon.png" width="192px" />
</p>

# MicroCRM (P7 - Développeur Full-Stack - Java et Angular - Mettez en œuvre l'intégration et le déploiement continu d'une application Full-Stack)

MicroCRM est une application de démonstration basique ayant pour être objectif de servir de socle pour le module "P7 - Développeur Full-Stack".

L'application MicroCRM est une implémentation simplifiée d'un ["CRM" (Customer Relationship Management)](https://fr.wikipedia.org/wiki/Gestion_de_la_relation_client). Les fonctionnalités sont limitées à la création, édition et la visualisations des individus liés à des organisations.

![Page d'accueil](./misc/screenshots/screenshot_1.png)
![Édition de la fiche d'un individu](./misc/screenshots/screenshot_2.png)

## Code source

### Organisation

Ce [monorepo](https://en.wikipedia.org/wiki/Monorepo) contient les 2 composantes du projet "MicroCRM":

- La partie serveur (ou "backend"), en Java SpringBoot 3;
- La partie cliente (ou "frontend"), en Angular 17.

## Plans d'automatisation

Cette section définit les règles attendues avant la configuration technique de la CI/CD. Les workflows GitHub Actions, les images Docker et l'orchestration Compose devront respecter ces principes.

### Plan de testing périodique

#### Tests exécutés

- **Backend** : `./gradlew test` exécute les tests JUnit 5 et les tests d'intégration Spring Boot avec HSQLDB. Ils vérifient notamment le contexte applicatif, les repositories et les comportements REST couverts par le projet.
- **Frontend** : `npm test -- --watch=false --browsers=ChromeHeadlessNoSandbox` exécute les tests unitaires Jasmine via Karma dans Chrome headless. Ils vérifient les composants, services et parcours Angular couverts par les spécifications existantes.
- **Builds de validation** : `./gradlew build` et `npm run build` vérifient que le JAR et les fichiers statiques Angular sont produisibles avec les versions supportées.
- **Validation intégration conteneurisée** : après construction, `docker compose config` vérifie la configuration Compose, puis le démarrage des services et leurs contrôles de santé vérifient que le front et l'API sont accessibles.

#### Déclenchement et objectifs

| Moment | Contrôles | Objectif |
| --- | --- | --- |
| Chaque push sur une branche | Tests backend, tests frontend, builds et contrôle de qualité | Détecter immédiatement une régression introduite par le commit |
| Chaque pull request vers `main` | Même socle complet, avec analyse SonarQube Cloud et contrôle des dépendances | Bloquer l'intégration d'un code non compilable, régressif ou ne respectant pas le niveau de qualité attendu |
| Chaque nuit | Tests complets, scans de dépendances et construction des images Docker sans publication | Détecter une régression liée à une dépendance ou à l'environnement, même sans nouveau commit |
| Chaque semaine | Test de démarrage Compose et test de restauration des artefacts sauvegardés | Vérifier la disponibilité de la chaîne de livraison et la récupérabilité des livrables |
| Avant une mise en production | Tests de non-régression, contrôle SonarQube réussi et smoke test sur l'environnement cible | Réduire le risque fonctionnel et opérationnel de la livraison |

Les résultats, rapports de tests et couvertures doivent être conservés comme artefacts du workflow. Une pull request ne peut être fusionnée que si les tests obligatoires, le build et le Quality Gate SonarQube sont réussis. Les tests intermittents doivent être corrigés ou isolés rapidement ; un simple nouvel essai ne doit pas masquer une anomalie.

### Plan de sécurité

#### Analyse SonarQube Cloud

SonarQube Cloud est exécuté sur les pull requests et sur la branche `main`. Il analyse le backend Java et le frontend TypeScript afin de produire une vue centralisée de la dette technique et des risques. Le Quality Gate constitue un contrôle obligatoire avant fusion.

Les indicateurs surveillés sont :

- les vulnérabilités et les problèmes de sécurité susceptibles d'exposer des données ou de permettre une mauvaise utilisation de l'API ;
- les bugs et duplications pouvant provoquer un comportement incorrect ou rendre les corrections risquées ;
- les code smells, la complexité et la maintenabilité ;
- la couverture et les tests manquants sur le nouveau code ;
- les dépendances vulnérables et obsolètes, en complément des outils de gestion des dépendances.

#### Règles de la CI

- Le token `SONAR_TOKEN`, les identifiants du registre et toute configuration sensible sont stockés dans les secrets GitHub ou dans les variables d'environnement de l'environnement de déploiement. Ils ne sont jamais écrits dans le dépôt, les Dockerfiles ou les journaux.
- Les dépendances sont installées à partir des fichiers verrouillés (`npm ci` et Gradle Wrapper). La chaîne échoue en cas de vulnérabilité **critique sur une dépendance de production** (`npm audit --omit=dev --audit-level=critical`) ou de **secret détecté** dans le dépôt. L'audit complet, incluant les dépendances de développement, et le scan de vulnérabilités du système de fichiers sont exécutés en mode rapport : ils n'interrompent pas la chaîne mais doivent être triés à chaque sprint. Ce seuil différencié est un choix assumé : les outils de build Angular actuels portent des vulnérabilités connues qui ne sont pas livrées en production et dont la correction impose une montée de version majeure, planifiée séparément.
- Les actions GitHub et les images de base sont maintenues à jour et référencées par une version explicite. Les permissions du workflow sont limitées au principe du moindre privilège et les publications sont interdites depuis une pull request non approuvée.
- Les images sont construites en plusieurs étapes, ne contiennent ni outils de build ni secrets, et exécutent les services avec un utilisateur non privilégié lorsque les images utilisées le permettent.
- Les entrées reçues par l'API sont validées, les erreurs ne révèlent pas de détails internes et les logs ne contiennent pas de données personnelles. Les règles OWASP applicables aux API REST et aux applications web Angular sont vérifiées lors de chaque revue.

Les alertes SonarQube, Dependabot et les scans de dépendances sont triés à chaque sprint. Une vulnérabilité critique fait l'objet d'un traitement prioritaire et peut déclencher une mise en pause des publications.

### Principes de conteneurisation et de déploiement

#### Rôle des Dockerfiles

Le `Dockerfile` racine utilise des étapes distinctes : compilation Angular, compilation Gradle, image de service frontend avec Caddy, puis image backend avec un JRE. Les étapes `front` et `back` produisent des services séparés et doivent être les cibles utilisées par Compose et le registre. L'étape `standalone`, qui réunit les deux processus avec Supervisor, est conservée pour un usage de démonstration ou de secours, mais n'est pas la cible privilégiée en production.

Les images doivent rester reproductibles et légères : contexte limité par `.dockerignore`, versions de base maîtrisées, aucune donnée persistante dans le conteneur et configuration fournie par variables d'environnement. Le backend utilise actuellement HSQLDB en mémoire ; les données sont donc perdues au redémarrage et cette configuration ne constitue pas une solution de sauvegarde de production.

Les images de construction utilisent `node:20-alpine` et Eclipse Temurin JDK 17. Les services utilisent les images officielles Caddy 2 Alpine et Eclipse Temurin JRE 17 Jammy. Le backend s'exécute avec un utilisateur système non privilégié ; les outils de compilation ne sont pas copiés dans les images finales. Ces choix limitent la surface d'attaque tout en conservant Java 17, version requise par le projet.

#### Rôle de Docker Compose

`docker compose` décrit l'exécution locale et l'environnement de validation : un service `front`, un service `back`, un réseau interne et les ports publiés nécessaires. Il doit fournir les variables de configuration, les dépendances de démarrage et des contrôles de santé. Compose sert à reproduire le déploiement et à réaliser le smoke test ; il ne remplace pas un orchestrateur de production lorsque la haute disponibilité est nécessaire.

#### Stratégie de déploiement

1. Un push sur `main` qui passe les tests, les scans et le Quality Gate construit les images `front` et `back`.
2. Les images sont publiées dans GitHub Container Registry avec un tag immuable correspondant au SHA du commit. Un tag de version peut être ajouté pour faciliter l'exploitation, mais `latest` ne doit pas être utilisé comme référence de déploiement.
3. Un environnement de recette déploie ces mêmes artefacts et exécute les smoke tests via Compose. La promotion vers la production réutilise les images déjà validées, sans recompilation.
4. Le déploiement de production est protégé par un environnement GitHub avec approbation manuelle, secrets séparés et journalisation. En cas d'échec, le tag du dernier SHA validé est redéployé.

Les sauvegardes concernent d'abord les artefacts, la configuration et les manifests. Une vraie sauvegarde applicative nécessitera une base persistante externe ; elle devra être ajoutée avant de considérer le service prêt pour une production avec conservation des données.

### Mise en œuvre de la CI GitHub Actions

Le workflow [`ci.yml`](.github/workflows/ci.yml) centralise l'intégration continue. Il est déclenché sur chaque push, sur les pull requests vers `main`, chaque nuit à 02:30 UTC et manuellement depuis l'onglet **Actions** de GitHub.

Les jobs s'exécutent comme suit :

1. `backend` installe Java 17, utilise le Gradle Wrapper, exécute `./gradlew build` et conserve les rapports de tests ainsi que les classes compilées.
2. `frontend` installe Node.js 20 et Chrome, exécute `npm ci`, les tests Karma en mode `ChromeHeadlessNoSandbox`, puis `npm run build`. Les rapports de couverture et le dossier `dist` sont conservés.
3. `security` exécute `npm audit --audit-level=high`, résout les dépendances Gradle et lance Trivy sur le dépôt pour détecter les vulnérabilités critiques/élevées et les secrets accidentellement présents.
4. `sonar`, dépendant des deux builds, récupère les classes Java et la couverture frontend, lance l'analyse SonarQube Cloud, puis échoue si le Quality Gate est invalide.

#### Configuration GitHub requise

Dans **Settings > Secrets and variables > Actions**, créer :

- le secret `SONAR_TOKEN`, généré dans SonarQube Cloud avec les permissions minimales d'analyse ;
- la variable `SONAR_PROJECT_KEY`, correspondant à la clé du projet SonarQube ;
- la variable `SONAR_ORGANIZATION`, correspondant à l'identifiant de l'organisation SonarQube Cloud.

Le dépôt GitHub doit également être associé au projet SonarQube Cloud et le Quality Gate doit être configuré comme contrôle obligatoire de la branche `main`. Les secrets ne sont pas exposés aux workflows de pull requests provenant d'un fork ; l'analyse SonarQube est alors ignorée, tandis que les jobs de build et de sécurité restent exécutables.

Le choix de versions explicites (`actions/*@v4`, Java 17, Node.js 20 et versions figées des actions de scan), du cache Gradle/npm et des artefacts rend le pipeline reproductible et facilite le diagnostic. La publication des images est réalisée par le workflow CD uniquement après la réussite de ce socle de tests et de sécurité.

### Déploiement continu vers GHCR

Le workflow [`cd.yml`](.github/workflows/cd.yml) est déclenché automatiquement à la fin du workflow CI. Il ne publie que si l'exécution CI est réussie, provient d'un push sur `main` et correspond au commit validé par cette exécution. Il est donc impossible de publier directement une image depuis une pull request ou une branche de développement.

Le job CD :

1. récupère exactement le SHA validé par la CI ;
2. s'authentifie auprès de GitHub Container Registry avec le `GITHUB_TOKEN` fourni par GitHub Actions ;
3. construit les stages `front` et `back` du Dockerfile avec Buildx et son cache GitHub ;
4. publie `microcrm-front` et `microcrm-back` dans `ghcr.io/<organisation-ou-utilisateur>` avec un tag SHA immuable et le tag pratique `main`.

Aucun mot de passe, token personnel ou paramètre sensible n'est écrit dans le workflow. La permission `packages: write` est limitée au job de publication. Dans les paramètres du dépôt, le workflow doit être autorisé à écrire dans les packages et les images GHCR doivent être configurées comme privées ou publiques selon la politique Orion.

Pour déployer les images publiées sur un serveur, utiliser le SHA affiché dans l'exécution CD et le fournir à la configuration Compose du serveur, puis effectuer un redémarrage contrôlé. La promotion réutilise ainsi l'image testée, sans recompilation :

```shell
docker login ghcr.io
docker pull ghcr.io/<organisation-ou-utilisateur>/microcrm-front:<sha>
docker pull ghcr.io/<organisation-ou-utilisateur>/microcrm-back:<sha>
```

Le déploiement vers la production reste protégé par l'accès au serveur et par les règles d'environnement de l'hébergeur. Un rollback consiste à redéployer les deux images portant le SHA précédemment validé.

### Releases et versioning sémantique

Le workflow [`release.yml`](.github/workflows/release.yml) publie une release GitHub lorsqu'un tag `vX.Y.Z` est poussé sur le dépôt.

#### Politique de versioning

Le projet suit strictement [SemVer](https://semver.org/lang/fr/) :

- **MAJOR** : changement incompatible de l'API REST ou du comportement attendu ;
- **MINOR** : ajout de fonctionnalité rétrocompatible ;
- **PATCH** : correction rétrocompatible.

Les décisions structurantes retenues sont les suivantes :

- **Pas de release candidate à chaque commit.** Chaque commit sur `main` produit déjà une image GHCR taguée par SHA, testée et analysée. C'est le livrable de l'intégration continue. Créer une release GitHub par commit n'apporterait aucune information supplémentaire et rendrait l'historique des versions illisible.
- **La release est déclenchée par une action humaine.** L'équipe décide du contenu et du numéro de version, puis pousse un tag annoté. Le reste (construction, vérification, publication des artefacts et notes de version) est automatisé. Ce choix évite qu'un simple merge n'incrémente une version publique de façon non maîtrisée.
- **Pas de branche par release.** Le dépôt reste en trunk-based : `main` est la seule branche durable et les versions sont matérialisées par des tags immuables. Une branche `hotfix/X.Y.Z` n'est créée à partir d'un tag que si un correctif urgent doit être livré alors que `main` a déjà avancé.

#### Créer une release

```shell
git tag -a v1.0.0 -m "MicroCRM 1.0.0"
git push origin v1.0.0
```

Le workflow :

1. valide que le tag respecte le format SemVer et refuse le tag sinon ;
2. construit le backend avec `-PappVersion=<version>`, ce qui nomme le JAR `microcrm-<version>.jar`, puis construit le frontend Angular ;
3. démarre le JAR produit et vérifie que l'API répond sur `/persons`, afin de garantir que l'artefact publié est réellement exécutable ;
4. crée la release GitHub avec les notes générées automatiquement à partir des commits et des pull requests ;
5. attache le JAR backend et l'archive `microcrm-front-<version>.zip` du build Angular.

Un tag comportant un suffixe, par exemple `v0.1.0-rc.1`, est publié automatiquement comme **pré-release**. C'est le mécanisme à utiliser pour effectuer une release de test avant de figer une version stable.

Les artefacts publiés ne contiennent que le JAR applicatif et les fichiers statiques compilés : aucun fichier d'environnement, secret ou configuration sensible n'est joint. La permission `contents: write` est limitée à ce seul workflow.


### Lancer l'application avec Docker Compose

Depuis la racine du dépôt :

```shell
docker compose config
docker compose up --build -d
docker compose ps
```

Le frontend est disponible sur http://localhost et l'API reste disponible sur http://localhost:8080. Dans l'interface web, les appels passent par `/api` et Caddy les transmet au service backend sur le réseau Compose. Le statut `healthy` des deux services confirme le démarrage attendu.

Pour arrêter et supprimer les conteneurs :

```shell
docker compose down
```

Les images peuvent être contrôlées avant publication avec `docker scout cves orion-microcrm-front:local` et `docker scout cves orion-microcrm-back:local` (ou un scanner d'entreprise équivalent). Les résultats critiques doivent être traités avant promotion. Aucune donnée sensible ne doit être passée par `ARG` ou copiée dans le contexte Docker.

### Démarrer avec les sources

#### Serveur

##### Dépendances

- [OpenJDK >= 17](https://openjdk.org/)

##### Procédure

1. Se positionner dans le répertoire `back` avec une invite de commande:

   ```shell
   cd back
   ```

2. Construire le JAR:

   ```shell
   # Sur Linux
   ./gradlew build

   # Sur Windows
   gradlew.bat build
   ```

3. Démarrer le service:

   ```shell
   java -jar build/libs/microcrm-0.0.1-SNAPSHOT.jar
   ```

Puis ouvrir l'URL http://localhost:8080 dans votre navigateur.

#### Client

##### Dépendances

- [NPM >= 10.2.4](https://www.npmjs.com/)

##### Procédure

1. Se positionner dans le répertoire `front` avec une invite de commande:

   ```shell
   cd front
   ```

2. (La première fois seulement) Installer les dépendances NodeJS:

   ```shell
   npm install
   ```

3. Démarrer le service de développement:

   ```shell
   npx @angular/cli serve
   ```

Puis ouvrir l'URL http://localhost:4200 dans votre navigateur.

### Exécution des tests

#### Client

**Dépendances**

- Google Chrome ou Chromium

Dans votre terminal:

```shell
cd front
CHROME_BIN=</path/to/google/chrome> npm test
```

#### Serveur

Dans votre terminal:

```shell
cd back
./gradlew test
```

### Images Docker

#### Client

##### Construire l'image

```shell
docker build --target front -t orion-microcrm-front:latest .
```

##### Exécuter l'image

```shell
docker run -it --rm -p 80:80 -p 443:443 orion-microcrm-front:latest
```

L'application sera disponible sur http://localhost.

#### Serveur

##### Construire l'image

```shell
docker build --target back -t orion-microcrm-back:latest .
```

##### Exécuter l'image

```shell
docker run -it --rm -p 8080:8080 orion-microcrm-back:latest
```

L'API sera disponible sur http://localhost:8080.

#### Tout en un

```shell
docker build --target standalone -t orion-microcrm-standalone:latest .
```

##### Exécuter l'image

```shell
docker run -it --rm -p 8080:8080 -p 80:80 orion-microcrm-standalone:latest
```

L'application sera disponible sur http://localhost et l'API sur http://localhost:8080.
