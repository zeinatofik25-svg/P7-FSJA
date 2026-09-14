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

#### Résultats, analyse et priorités SonarQube

Au moment de cette rédaction, trois analyses SonarQube Cloud ont été exécutées sur `main`. Les éléments marqués **constaté** ont été vérifiés dans le code ; les éléments marqués **mesuré** proviennent de l'analyse du commit `fa81dc4`. Le tableau suivant constitue le backlog de revue prioritaire.

| Priorité | Domaine | Constat ou contrôle SonarQube à relever | Risque | Traitement attendu |
| --- | --- | --- | --- | --- |
| P1 | Exposition API | **Constaté** : les repositories Spring Data REST exposent lecture et écriture des personnes et organisations, sans mécanisme d'authentification applicatif visible | Modification ou consultation non autorisée de données personnelles | Ajouter une authentification et une autorisation par rôle avant tout déploiement public |
| P1 | CORS | **Constaté** : la configuration autorise l'origine `*` sur toutes les routes | Une application tierce peut appeler l'API depuis le navigateur d'un utilisateur | Limiter les origines aux URL de l'interface selon l'environnement ; interdire toute origine non attendue |
| P1 | Données personnelles | **Constaté** : `Person` contient e-mail, téléphone et biographie | Exposition de données personnelles par l'API ou les logs | Minimiser les champs exposés, documenter la conservation et ne jamais journaliser les objets `Person` complets |
| P1 | Vulnérabilités | **Mesuré** : 4 vulnérabilités ouvertes, 0 Security Hotspot, note de sécurité C | Exploitation d'une faiblesse identifiée par SonarQube | Corriger immédiatement les vulnérabilités critiques et hautes ; examiner chaque Security Hotspot avant fusion |
| P1 | Dépendances | Relever les alertes des dépendances directes et transitives | Composant connu vulnérable | Mettre à jour de manière compatible ; contrôler aussi `npm audit` et le scan Trivy |
| P2 | Validation des entrées | **Constaté** : aucun contrat DTO ni annotation de validation n'est visible sur l'entité `Person` | Données invalides, volumétrie non maîtrisée et erreurs applicatives | Introduire des DTO et les contraintes `@NotBlank`, `@Email`, longueurs maximales ; ajouter les tests 400 associés |
| P2 | Couverture backend | **Mesuré** : 56,4 % sur 226 lignes Java, via JaCoCo importé depuis `back/build/reports/jacoco/test/jacocoTestReport.xml` | Zones REST et erreurs non protégées par des tests | Compléter les tests des cas d'erreur et viser 80 % sur le nouveau code |
| P2 | Couverture frontend | **Mesuré** : 27,3 % sur 735 lignes TypeScript, dont 26,7 % sur `person-details` | Régression de composants/services Angular | Ajouter les tests d'erreur HTTP, de formulaire et de navigation ; viser 80 % sur le nouveau code |
| P2 | Duplications | **Mesuré** : 2,5 % sur l'ensemble du code, 0 % sur le nouveau code | Corrections incohérentes et maintenance coûteuse | Extraire les méthodes/services communs uniquement lorsque SonarQube confirme une duplication significative |
| P2 | Complexité | Trier les méthodes et composants par complexité cognitive et nombre de branches | Défauts difficiles à détecter et tester | Découper les méthodes au-dessus du seuil du Quality Profile, avec tests de non-régression |
| P2 | Fiabilité | **Mesuré** : 9 bugs ouverts, note de fiabilité C, 30 code smells pour 104 minutes de dette | Erreurs de production ou dette technique | Corriger les bugs bloquants avant fusion ; planifier les code smells dans le sprint suivant |
| P3 | Maintenabilité | Relever code smells, dette estimée et règles de style | Lisibilité réduite et coût de changement | Traiter les alertes sur le nouveau code ; ne pas entreprendre de refactoring massif sans besoin métier |

Les éléments P1 constituent des risques de sécurité ou de confidentialité ; ils ne doivent pas être assimilés aux code smells P3. Les duplications et la complexité sont principalement des indicateurs de maintenabilité et deviennent des risques de fiabilité lorsqu'ils empêchent de tester ou de corriger le code avec confiance.

#### Quality Gate et règles de traitement

Le Quality Gate appliqué aux pull requests et à `main` doit exiger : aucune nouvelle vulnérabilité ni nouveau bug bloquant, aucune Security Hotspot non examinée, une couverture d'au moins 80 % sur le nouveau code et un taux de duplication inférieur à 3 % sur le nouveau code. La première analyse doit être archivée dans la documentation de sprint avec : date, branche/SHA, statut du Quality Gate, nombre de bugs, vulnérabilités, Security Hotspots, code smells, duplications, complexité et couverture, séparés par langage lorsque SonarQube les fournit.

| Relevé SonarQube | Valeur sur `main` au 14 septembre 2026 | Décision |
| --- | --- | --- |
| Quality Gate | **OK** | Échec : fusion bloquée |
| Vulnérabilités ouvertes | **4**, note de sécurité C | Toute criticité haute ou critique : correction prioritaire |
| Security Hotspots examinées | **100 %** (aucun hotspot détecté) | 100 % requis avant livraison |
| Bugs | **9**, note de fiabilité C | Bloquant/critique : correction avant fusion |
| Duplications nouveau code | **0 %** (2,5 % sur l'ensemble du code) | Supérieur à 3 % : justification ou refactoring ciblé |
| Complexité des méthodes prioritaires | Complexité cognitive **19**, cyclomatique **92** pour 973 lignes | Découpage et tests lorsque le seuil du profil est dépassé |
| Couverture Java | **56,4 %** (226 lignes) | Inférieure à 80 % : compléter les tests des cas d'erreur REST |
| Couverture TypeScript | **27,3 %** (735 lignes) | Inférieure à 80 % : ajouter les tests Jasmine/Karma |
| Avertissements d'analyse | **0** | Tout avertissement fausse la comparaison entre livraisons |

Ce relevé correspond à l'analyse du commit `fa81dc4`, exécutée le 14 septembre 2026 à 20:21:43 UTC. Les notes de fiabilité et de sécurité à C portent exclusivement sur du code hérité : aucune des trois pull requests livrées n'a introduit de bug, de vulnérabilité ni de code smell.

#### Croisement SonarQube, CI et ELK

Après chaque livraison, surveiller Kibana pendant les 15 premières minutes avec `service_name: "microcrm-back" and log_level: "ERROR"`, puis comparer le taux d'erreurs à la période précédant le déploiement. Une alerte SonarQube de fiabilité ou de validation devient prioritaire si elle correspond à une hausse de ces erreurs. Inversement, une erreur répétée dans ELK doit conduire à créer un test de régression puis à consulter les règles SonarQube de la zone concernée. Les logs ne doivent contenir ni e-mail, ni téléphone, ni biographie, ni jeton : une telle apparition est un incident de sécurité à traiter immédiatement.

#### Plan de remédiation

1. Avant exposition hors environnement local, restreindre CORS, protéger les routes REST et vérifier que les réponses API ne retournent que les données nécessaires.
2. Ajouter validation, limites de taille et tests négatifs sur les créations et modifications de personnes et d'organisations.
3. Configurer JaCoCo pour le backend, conserver LCOV pour le frontend et transmettre les deux rapports à SonarQube.
4. Après les trois premières CI, relever les alertes SonarQube, traiter tout P1, puis planifier les P2 confirmés avec un responsable et une échéance de sprint.
5. Réexaminer chaque sprint les vulnérabilités, Security Hotspots, dépendances, erreurs ELK et le statut du Quality Gate ; fermer le ticket seulement après validation par CI et absence de récidive dans les logs.

#### Règles de la CI

- Le token `SONAR_TOKEN`, les identifiants du registre et toute configuration sensible sont stockés dans les secrets GitHub ou dans les variables d'environnement de l'environnement de déploiement. Ils ne sont jamais écrits dans le dépôt, les Dockerfiles ou les journaux.
- Les dépendances sont installées à partir des fichiers verrouillés (`npm ci` et Gradle Wrapper). La chaîne échoue en cas de vulnérabilité **critique sur une dépendance de production** (`npm audit --omit=dev --audit-level=critical`) ou de **secret détecté** dans le dépôt. L'audit complet, incluant les dépendances de développement, et le scan de vulnérabilités du système de fichiers sont exécutés en mode rapport : ils n'interrompent pas la chaîne mais doivent être triés à chaque sprint. Ce seuil différencié est un choix assumé : les outils de build Angular actuels portent des vulnérabilités connues qui ne sont pas livrées en production et dont la correction impose une montée de version majeure, planifiée séparément.
- Les actions GitHub et les images de base sont maintenues à jour et référencées par une version explicite. Les permissions du workflow sont limitées au principe du moindre privilège et les publications sont interdites depuis une pull request non approuvée.
- Les images sont construites en plusieurs étapes, ne contiennent ni outils de build ni secrets, et exécutent les services avec un utilisateur non privilégié lorsque les images utilisées le permettent.
- Les entrées reçues par l'API sont validées, les erreurs ne révèlent pas de détails internes et les logs ne contiennent pas de données personnelles. Les règles OWASP applicables aux API REST et aux applications web Angular sont vérifiées lors de chaque revue.

Les alertes SonarQube, Dependabot et les scans de dépendances sont triés à chaque sprint. Une vulnérabilité critique fait l'objet d'un traitement prioritaire et peut déclencher une mise en pause des publications.

### Métriques DORA et KPIs opérationnels

Les métriques DORA permettent de mesurer séparément la vitesse de livraison et la fiabilité. Elles sont calculées sur une période glissante de 30 jours et révisées à chaque sprint. Les sources CI/CD sont l'historique GitHub Actions et GitHub Deployments ; les sources applicatives sont les index `microcrm-logs-*` dans Kibana. Une métrique n'est pas calculée à partir d'une estimation : les trois premières livraisons et les éventuels incidents doivent être consignés avant d'établir une valeur de référence.

#### Tableau DORA relevé le 14 septembre 2026

Les valeurs ci-dessous proviennent de trois déploiements réellement exécutés sur `main` le 14 septembre 2026 et d'un incident provoqué volontairement en environnement local. Elles constituent la première référence du projet et non une valeur cible ; la période d'observation reste d'une seule journée.

| Métrique DORA | Méthode de calcul | Source | Valeur mesurée | Cible après 3 sprints |
| --- | --- | --- | --- | --- |
| Lead Time for Changes | Médiane entre la date d'auteur du commit livré sur `main` et la fin du workflow CD associé au même SHA | `git log` et `actions/runs/<id>/timing` | **16 min 05 s** (54 min 30 s / 13 min 05 s / 16 min 05 s) | Moins de 1 jour ouvré |
| Deployment Frequency | Nombre de déploiements CD réussis sur `main` / période | Workflows `Continuous Deployment` réussis | **3 déploiements en 1 journée** | Au moins 1 déploiement par semaine |
| Mean Time to Restore (MTTR) | Écart entre le début de l'incident horodaté et la première requête à nouveau servie | Horodatage de l'arrêt, logs Kibana, logs du conteneur | **2 min 02 s** (1 incident simulé) | Moins de 4 heures |
| Change Failure Rate | (Déploiements ayant causé incident, rollback ou hotfix urgent / déploiements totaux) x 100 | Workflows CD et journal d'incidents | **0 %** (0 sur 3) | Inférieur à 15 % |

Le Lead Time du premier déploiement (54 min 30 s) inclut le délai de revue humaine de la pull request ; les deux suivants, sans attente de revue, tombent à 13 et 16 minutes. La médiane est retenue plutôt que la moyenne précisément pour que cette attente ponctuelle ne masque pas la performance réelle de la chaîne automatisée, dont la part incompressible est de 4 à 5 minutes (CI puis CD).

Le MTTR provient d'un incident **simulé** : arrêt volontaire du conteneur backend, détection par les logs, puis redémarrage. Il mesure la capacité de détection et de restauration de la chaîne, pas la résolution d'une panne réelle dont la cause serait inconnue. À ce titre il ne compte pas comme un échec de changement : le Change Failure Rate reste à 0 %, aucun des trois déploiements n'ayant provoqué de régression.

Le taux d'échec ne doit compter qu'un déploiement une seule fois, même s'il produit plusieurs erreurs. Un échec de CI avant déploiement reste un signal de qualité, mais ne constitue pas un échec de changement DORA. De la même manière, une erreur isolée dans Kibana n'est un incident que si elle dégrade le service ou exige une intervention.

#### Chronologie de l'incident simulé

| Jalon | Horodatage UTC | Écart depuis T1 |
| --- | --- | --- |
| T1 — arrêt du backend (`docker compose stop back`) | 21:07:22,554 | — |
| T2 — détection : premier document `log_level: ERROR` avec `application_log.status: 502` | 21:07:27,695 | 5,1 s |
| Redémarrage du conteneur | 21:08:31,122 | 68,6 s |
| T3 — première requête à nouveau servie | 21:09:24,212 | **121,7 s** |

La détection en 5 secondes est le bénéfice direct des logs d'accès Caddy : l'échec du `reverse_proxy` produit immédiatement un événement `ERROR` exploitable. L'essentiel du MTTR est en revanche consommé par le redémarrage applicatif, le backend mettant ici 41 secondes à répondre après le lancement de la JVM. Réduire ce MTTR passe donc par l'accélération du démarrage, non par l'amélioration de la supervision.

#### KPIs complémentaires

| KPI | Méthode de calcul | Source | Valeur mesurée | Cible opérationnelle | Action si seuil dépassé |
| --- | --- | --- | --- | --- | --- |
| Durée CI | Médiane de la durée totale des 3 derniers workflows `Continuous Integration` réussis sur `main` | GitHub Actions | **2 min 17 s** (2:26 / 2:11 / 2:17) | Moins de 15 min | Identifier l'étape lente et exploiter le cache Gradle/npm |
| Taux de réussite CI | (Workflows CI réussis / workflows CI terminés) x 100 | GitHub Actions | **100 %** sur les 3 livraisons ; 42 % sur l'historique complet de 26 runs | Au moins 95 % | Corriger ou isoler le test instable avant nouveau merge |
| Durée des tests | Durée des étapes `Build and test` et `Run unit tests with coverage` | Logs GitHub Actions | Backend **36 à 41 s**, frontend **12 à 15 s** | Backend moins de 5 min, frontend moins de 8 min | Réduire les tests redondants ou améliorer le cache |
| Couverture de tests | Couverture mesurée par SonarQube, JaCoCo pour Java et LCOV pour TypeScript | SonarQube Cloud | **37,6 %** global : backend 56,4 %, frontend 27,3 % | Au moins 80 % sur le nouveau code | Ajouter des tests avant validation de la pull request |
| Qualité SonarQube | Quality Gate réussi, sans avertissement d'analyse | SonarQube Cloud | **3 Quality Gates sur 3 réussis**, 0 avertissement d'analyse | 100 % des Quality Gates réussis | Bloquer la fusion et corriger les alertes |
| Fréquence d'erreurs applicatives | Nombre de logs `ERROR` / nombre total de logs, ventilé par `service_name` | Kibana, index `microcrm-logs-*` | **5,36 %** sur la fenêtre de 20 min contenant l'incident (12 sur 224) ; **0 %** hors incident | Inférieur à 1 % | Investiguer les erreurs répétées et créer un incident si le service est impacté |
| Délai de détection | Écart entre le début de la panne et le premier log `ERROR` indexé | Kibana | **5,1 s** | Moins de 1 min | Vérifier la chaîne gelf → Logstash → Elasticsearch |
| Taille des images publiées | Taille locale après `docker pull` du tag SHA | GHCR | Backend **558 Mo**, frontend **70 Mo** | Backend moins de 400 Mo | Passer à une image de base `alpine` ou à un JRE réduit via `jlink` |

#### Procédure de relève

Après chaque déploiement sur `main`, relever le SHA, l'heure du commit, l'heure de fin de CD, le statut du Quality Gate, la durée CI et la présence d'un incident. Conserver au minimum les trois relevés suivants dans le tableau de suivi de sprint :

| SHA | Commit livré (UTC) | Fin CD (UTC) | Durée CI | Quality Gate | Incident / rollback | Retour au service (UTC) |
| --- | --- | --- | --- | --- | --- | --- |
| `f0e274c` | 2026-09-14 10:18:31 | 2026-09-14 11:13:01 | 2 min 26 s | OK | Non | Sans objet |
| `7533d6d` | 2026-09-14 19:17:33 | 2026-09-14 19:30:38 | 2 min 11 s | OK | Non | Sans objet |
| `fa81dc4` | 2026-09-14 20:08:04 | 2026-09-14 20:24:09 | 2 min 17 s | OK | Non (incident simulé hors déploiement à 21:07:22) | 2026-09-14 21:09:24 |

L'heure de commit retenue est la date d'auteur du commit applicatif (`af7d58e`), et non celle du commit de fusion : c'est le moment où le changement a été écrit, conformément à la définition du Lead Time. Le mode de fusion « merge commit » a été choisi pour cette raison, un squash réécrivant l'horodatage d'origine et ramenant artificiellement la métrique à quelques minutes.

Pour Kibana, le panneau `Erreurs par service` utilise le filtre KQL `log_level: "ERROR"`. Le KPI de fréquence d'erreurs se calcule avec le même intervalle que le panneau de volume : $taux\ d'erreurs = \frac{nombre\ de\ logs\ ERROR}{nombre\ total\ de\ logs} \times 100$. Lors d'un pic de volume, comparer cette valeur avec la période précédente : un volume élevé sans hausse du taux d'erreurs correspond à une activité accrue, tandis qu'une hausse simultanée signale un risque de fiabilité.

#### Analyse commentée

Le pipeline limite effectivement les changements risqués : tests backend et frontend, audit des dépendances, recherche de secrets et analyse SonarQube précèdent toute publication, et le workflow CD n'est déclenché que par une CI réussie provenant d'un push sur `main`. Les trois livraisons du 14 septembre 2026 confirment que cette chaîne fonctionne de bout en bout : trois Quality Gates réussis, aucun échec de déploiement, et des images publiées avec un tag SHA immuable vérifiable dans GHCR.

**La chaîne automatisée n'est pas le facteur limitant.** La part incompressible entre un commit et une image déployable est de 4 à 5 minutes, dont 2 min 17 s de CI. L'écart entre le premier Lead Time (54 min 30 s) et les suivants (13 et 16 minutes) provient entièrement de l'attente de revue humaine. Optimiser la CI n'améliorerait donc pas significativement le Lead Time ; réduire le délai de prise en charge des pull requests, si.

**Le coût du CD a chuté de 68 % entre la première et la deuxième publication**, de 5 min 21 s à 1 min 42 s, grâce au cache Buildx sur GitHub Actions. La première exécution paie la construction complète des deux images ; les suivantes ne reconstruisent que les couches modifiées. Cette valeur ne doit donc pas être comparée d'un sprint à l'autre sans vérifier l'état du cache.

**Le taux de réussite CI de 42 % sur l'historique complet n'est pas un indicateur de fiabilité du produit.** Les quinze échecs sont concentrés entre le 27 août et le 10 septembre, pendant la mise au point du pipeline lui-même : versions d'actions inexistantes, permissions SonarCloud, attente bloquante du Quality Gate. Aucun ne correspond à une régression applicative. Sur les trois livraisons mesurées, le taux est de 100 %. La valeur de référence doit donc être recalculée sur une fenêtre glissante démarrant après stabilisation, et l'exclusion doit être documentée plutôt que silencieuse.

**Une amélioration d'outillage peut dégrader les indicateurs qualité.** La correction des trois avertissements d'analyse a fait apparaître 226 lignes Java jusque-là totalement absentes du périmètre SonarQube, et avec elles 5 issues et 3 vulnérabilités supplémentaires. Une lecture naïve conclurait à une régression ; il s'agit en réalité de la fin d'un angle mort. Toute comparaison de métriques SonarQube entre deux livraisons doit donc vérifier d'abord que le périmètre analysé est identique.

**Le Quality Gate vert ne certifie pas un code sain.** Il ne porte que sur le nouveau code, or les trois pull requests n'ont introduit aucune ligne de production. Les 9 bugs, 4 vulnérabilités et 30 code smells du code hérité restent donc invisibles pour ce contrôle, avec des notes de fiabilité et de sécurité à C. C'est une limite structurelle du Quality Gate, pas un défaut de configuration : le backlog de revue prioritaire reste le seul mécanisme qui traite ce stock.

**La supervision détecte vite, la restauration est lente.** Le délai de détection de 5,1 secondes montre que la chaîne gelf vers Logstash puis Elasticsearch est opérationnelle et que les logs d'accès Caddy suffisent à repérer une indisponibilité backend. En revanche 97 % du MTTR est consommé par le redémarrage applicatif. Le levier d'amélioration est donc le temps de démarrage du backend, mesuré entre 41 et 102 secondes selon la charge de la machine, et non l'outillage d'observabilité.

#### Recommandations, par priorité

| Priorité | Recommandation | Justification chiffrée |
| --- | --- | --- |
| 1 | Réduire le temps de démarrage du backend et porter `start_period` à 60 s dans le healthcheck | 97 % du MTTR de 2 min 02 s ; le budget actuel du healthcheck est de 140 s pour un démarrage observé jusqu'à 102 s |
| 2 | Compléter les tests backend sur les cas d'erreur REST | Couverture backend 56,4 % contre une cible de 80 % ; seules 2 classes de test existent |
| 3 | Traiter le stock de 9 bugs et 4 vulnérabilités du code hérité | Notes de fiabilité et de sécurité à C, invisibles pour le Quality Gate |
| 4 | Compléter les tests frontend, en priorité `person-details` | Couverture 27,3 % globale, 26,7 % sur `person-details` pour 281 lignes |
| 5 | Réduire l'image backend sous 400 Mo | 558 Mo contre 70 Mo pour le frontend ; coût de transfert à chaque déploiement |
| 6 | Réduire le délai de prise en charge des pull requests | Seul poste significatif du Lead Time, 54 min 30 s contre 4 à 5 min automatisés |

#### Limites du relevé

Ces valeurs portent sur une seule journée, trois déploiements et un incident provoqué. Elles établissent une référence, pas une tendance. Trois conditions doivent être réunies avant d'en tirer des conclusions de performance : au moins trente jours d'historique, des déploiements portant du code applicatif et non seulement de l'outillage, et au moins un incident non simulé dont la cause était inconnue au départ. Le MTTR d'un incident simulé est structurellement optimiste, puisque la cause et le correctif sont connus avant même le début de la mesure.

### Principes de conteneurisation et de déploiement

#### Rôle des Dockerfiles

Le `Dockerfile` racine utilise des étapes distinctes : compilation Angular, compilation Gradle, image de service frontend avec Caddy, puis image backend avec un JRE. Les étapes `front` et `back` produisent des services séparés et doivent être les cibles utilisées par Compose et le registre. L'étape `standalone`, qui réunit les deux processus avec Supervisor, est conservée pour un usage de démonstration ou de secours, mais n'est pas la cible privilégiée en production.

Les images doivent rester reproductibles et légères : contexte limité par `.dockerignore`, versions de base maîtrisées, aucune donnée persistante dans le conteneur et configuration fournie par variables d'environnement. Le backend utilise actuellement HSQLDB en mémoire ; les données sont donc perdues au redémarrage et cette configuration ne constitue pas une solution de sauvegarde de production.

Les images de construction utilisent `node:20-alpine` et Eclipse Temurin JDK 17. Les services utilisent les images officielles Caddy 2 Alpine et Eclipse Temurin JRE 17 Jammy. Le backend s'exécute avec un utilisateur système non privilégié ; les outils de compilation ne sont pas copiés dans les images finales. Ces choix limitent la surface d'attaque tout en conservant Java 17, version requise par le projet.

#### Rôle de Docker Compose

`docker compose` décrit l'exécution locale et l'environnement de validation : un service `front`, un service `back`, un réseau interne et les ports publiés nécessaires. Il doit fournir les variables de configuration, les dépendances de démarrage et des contrôles de santé. Compose sert à reproduire le déploiement et à réaliser le smoke test ; il ne remplace pas un orchestrateur de production lorsque la haute disponibilité est nécessaire.

### Monitoring local ELK

Le monitoring local est isolé dans [`docker-compose-elk.yml`](docker-compose-elk.yml) afin de ne pas alourdir la CI/CD ni le démarrage standard de l'application. Il déploie Elasticsearch 8.15.3 (stockage et recherche), Logstash 8.15.3 (collecte et normalisation) et Kibana 8.15.3 (exploration et tableaux de bord). La pile est destinée au poste de développement : l'authentification Elastic est désactivée et Elasticsearch réserve 1 Go de heap, Logstash 512 Mo. Prévoir au moins 4 Go de RAM disponible pour Docker Desktop.

Les services applicatifs continuent d'écrire sur leur sortie standard. Le driver Docker `gelf` envoie ces flux à Logstash en UDP sur le port `12201`, sans bibliothèque d'observabilité ni agent dans les conteneurs. Le backend produit des événements JSON Logback, avec le champ `service` à `microcrm-back`. Caddy produit également ses accès et ses erreurs en JSON, chaque requête HTTP donnant un document avec `application_log.status`, `application_log.request.uri` et `application_log.duration`. Logstash décode les événements JSON lorsqu'il le peut, conserve le message brut sinon, puis indexe les documents dans `microcrm-logs-AAAA.MM.JJ`.

Deux champs sont normalisés par Logstash pour que les tableaux de bord restent exploitables :

- `service_name` vaut `microcrm-back` ou `microcrm-front`. Il est repris du champ `service` du JSON applicatif et, à défaut, du `tag` déclaré sur le driver `gelf` dans [`docker-compose.yml`](docker-compose.yml). Sans cette reprise, les lignes non JSON du backend (démarrage de la JVM, arrêt du conteneur) seraient ventilées sous le nom du conteneur Docker et sépareraient artificiellement un même service en deux séries.
- `log_level` est mis en majuscules. Logback émet `INFO`/`WARN`/`ERROR` alors que Caddy émet `info`/`warn`/`error` ; sans normalisation, une agrégation sur `log_level.keyword` produit deux compartiments par niveau. Les lignes non JSON reçoivent le niveau déduit de la sévérité syslog transmise par le driver `gelf`.

#### Démarrage et arrêt

Depuis la racine du dépôt, démarrer d'abord ELK, puis l'application :

```shell
docker compose -f docker-compose-elk.yml up --build -d
docker compose -f docker-compose-elk.yml ps
docker compose up --build -d
```

Kibana est accessible sur http://localhost:5601 et Elasticsearch sur http://localhost:9200. Après quelques requêtes dans l'interface MicroCRM, vérifier les documents indexés :

```shell
curl http://localhost:9200/microcrm-logs-*/_count
```

Pour arrêter ELK tout en conservant les index locaux :

```shell
docker compose -f docker-compose-elk.yml down
```

Ajouter `-v` à cette dernière commande uniquement pour supprimer les données Elasticsearch locales et repartir d'un environnement vierge.

#### Tableau de bord Kibana

Dans **Stack Management > Data Views**, créer la vue `microcrm-logs-*` et choisir `@timestamp` comme champ temporel. Dans **Discover**, vérifier que les logs du backend affichent `application_log.level`, `application_log.message` et `service_name`, puis enregistrer la recherche `MicroCRM - Logs`.

Créer ensuite le tableau de bord `MicroCRM - Santé applicative` avec ces visualisations :

| Visualisation | Configuration | Indicateur suivi |
| --- | --- | --- |
| Volume des événements | Histogramme temporel, agrégation `Count`, intervalle automatique | Activité et pics de charge |
| Erreurs par service | Barres, filtre KQL `log_level: "ERROR"`, ventilation par `service_name.keyword` | Services en erreur et volumétrie des incidents |
| Répartition des niveaux | Donut, agrégation `Count`, découpage par `log_level.keyword` | Tendance INFO/WARN/ERROR |

Le filtre de période de Kibana doit être positionné sur les 15 dernières minutes pendant une démonstration. Les requêtes HTTP vers le front génèrent des événements Caddy et les appels API ou erreurs backend génèrent des événements Spring Boot. Pour investiguer une erreur, filtrer `service_name: "microcrm-back" and log_level: "ERROR"`, puis consulter le champ `application_log.stack_trace` lorsqu'il existe.

En fonctionnement nominal, le backend ne journalise pas chaque requête : le volume observé provient très majoritairement des accès Caddy, et un document `microcrm-back` correspond donc à un événement de cycle de vie ou à une anomalie. Une indisponibilité du backend est visible immédiatement via `application_log.status: 502`, Caddy journalisant l'échec du `reverse_proxy` au niveau `ERROR`. C'est ce signal qui alimente le KPI de fréquence d'erreurs et l'horodatage de détection d'un incident.

#### Diagnostic local

Si aucun événement n'apparaît, vérifier dans cet ordre que Logstash écoute (`docker compose -f docker-compose-elk.yml logs logstash`), que les conteneurs MicroCRM ont été recréés après le démarrage d'ELK (`docker compose up -d --force-recreate`) et que Docker Desktop peut joindre `host.docker.internal`. Cette adresse est la passerelle de l'hôte fournie par Docker Desktop sous Windows et permet au driver de logs de joindre le port Logstash publié. Le monitoring local est volontairement exclu des workflows CI/CD en raison de son coût mémoire et de l'absence de besoin de rétention longue durée.

### Plan de déploiement

#### Prérequis techniques

| Prérequis | Valeur | Vérification |
| --- | --- | --- |
| Docker Engine avec Compose v2 | Testé avec Docker Desktop 4.87, Engine 29.7.2 | `docker compose version` |
| Accès en lecture à GHCR | Compte disposant du droit `read:packages` | `docker login ghcr.io` |
| Ports libres sur l'hôte | `80` pour le frontend, `8080` pour l'API | `docker compose config` |
| Mémoire disponible | 2 Go pour l'application seule, 6 Go si la pile ELK tourne sur la même machine | `docker info` |
| SHA validé à déployer | Tag d'image produit par un workflow CD réussi | Onglet **Actions**, workflow `Continuous Deployment` |

Aucun secret n'est nécessaire au déploiement : l'application ne lit aucune variable d'environnement sensible et la base HSQLDB est embarquée.

#### Ordre de déploiement

L'ordre est imposé par deux dépendances techniques et ne peut pas être inversé :

1. **La pile ELK d'abord**, si le monitoring est souhaité. Le driver `gelf` émet en UDP sans accusé de réception : tout conteneur démarré avant Logstash perd définitivement les logs produits entre les deux démarrages.
2. **Le backend ensuite.** Le frontend déclare `depends_on: back: condition: service_healthy` ; Compose attend donc que le contrôle de santé du backend réussisse avant de démarrer Caddy.
3. **Le frontend enfin**, qui expose le port 80 et relaie `/api` vers le backend sur le réseau interne.

#### Procédure

```shell
docker login ghcr.io
docker pull ghcr.io/<organisation-ou-utilisateur>/microcrm-front:<sha>
docker pull ghcr.io/<organisation-ou-utilisateur>/microcrm-back:<sha>

docker tag ghcr.io/<organisation-ou-utilisateur>/microcrm-front:<sha> orion-microcrm-front:local
docker tag ghcr.io/<organisation-ou-utilisateur>/microcrm-back:<sha> orion-microcrm-back:local

docker compose up -d --no-build --force-recreate
docker compose ps
```

L'option `--no-build` est essentielle : elle garantit que l'artefact déployé est bien l'image testée par la CI, et non une recompilation locale qui pourrait diverger. Le déploiement est terminé lorsque les deux services affichent `healthy`, ce qui a demandé **75,6 secondes** lors du relevé du 14 septembre 2026.

#### Vérification

```shell
curl -f http://localhost/health
curl -f http://localhost/api/persons
curl -f http://localhost:8080/persons
```

Les trois réponses doivent être en succès. En cas de monitoring actif, contrôler ensuite Kibana pendant 15 minutes avec le filtre `log_level: "ERROR"` : un taux d'erreurs supérieur à 1 % justifie un retour arrière.

#### Retour arrière

Le rollback consiste à rejouer la même procédure avec le SHA précédemment validé. Aucune migration de données n'étant appliquée, l'opération est symétrique et ne nécessite aucune restauration. Le tag `main` existe pour le confort d'exploitation mais **ne doit jamais servir de référence de déploiement** : il est mutable, donc non reproductible.

#### Promotion vers la production

Un push sur `main` qui passe les tests, les scans et le Quality Gate construit et publie les images `front` et `back` avec un tag SHA immuable. Un environnement de recette déploie ces mêmes artefacts et exécute les contrôles ci-dessus ; la promotion vers la production réutilise l'image déjà validée, sans recompilation. Le déploiement de production est protégé par un environnement GitHub avec approbation manuelle, secrets séparés et journalisation.

### Plan de sauvegarde

#### Ce qui est sauvegardé

| Élément | Support | Fréquence | Méthode |
| --- | --- | --- | --- |
| Code source et historique | Dépôt GitHub `zeinatofik25-svg/P7-FSJA` | À chaque push | Réplication GitHub ; chaque poste de développement détient un clone complet |
| Images applicatives | GitHub Container Registry, tag SHA immuable | À chaque déploiement | Publiées par le workflow CD, conservées sans expiration |
| Configuration d'exécution | `docker-compose.yml`, `docker-compose-elk.yml`, `misc/docker/Caddyfile`, `elk/` | À chaque push | Versionnée dans le dépôt, donc couverte par la sauvegarde du code |
| Définition du pipeline | `.github/workflows/` | À chaque push | Idem |
| Rapports de tests et de couverture | Artefacts GitHub Actions | À chaque exécution CI | Rétention par défaut de 90 jours |
| Artefacts de version | Releases GitHub (JAR et archive du build Angular) | À chaque tag `vX.Y.Z` | Attachés à la release, conservés sans expiration |
| Secrets | Secrets GitHub Actions et variables d'environnement de l'hébergeur | À chaque modification | Jamais dans le dépôt ; restauration par ressaisie manuelle |

#### Ce qui n'est pas sauvegardé, et pourquoi

**Les données applicatives ne sont pas sauvegardées, parce qu'il n'y en a pas à conserver.** Le backend utilise HSQLDB en mémoire et recharge un jeu de fixtures à chaque démarrage : le contenu est perdu à l'arrêt du conteneur et reconstruit à l'identique au redémarrage. Prétendre sauvegarder cette base serait trompeur.

Cette configuration convient à une démonstration mais **interdit toute mise en production avec conservation de données**. Le passage à une base persistante externe est le prérequis à un vrai plan de sauvegarde ; il devra alors définir une fréquence, une rétention, un chiffrement et surtout un test de restauration périodique, une sauvegarde jamais restaurée n'ayant aucune valeur démontrée.

Les index Elasticsearch locaux ne sont pas sauvegardés non plus : le monitoring est un outil de poste de développement, sans besoin de rétention longue durée. Le volume `elasticsearch-data` survit à un `docker compose down` mais est détruit par l'option `-v`.

#### Test de restauration

La restauration de la chaîne de livraison se vérifie en redéployant un SHA antérieur avec la procédure du plan de déploiement, puis en contrôlant les trois points de vérification. Ce test est à exécuter une fois par semaine, conformément au plan de testing périodique.

### Plan de mise à jour

#### Mise à jour de l'application

Toute modification suit le même chemin, sans exception : branche, pull request vers `main`, CI complète, Quality Gate, puis publication automatique d'une image taguée par SHA. Le déploiement applique ensuite la procédure du plan de déploiement. Aucune modification ne doit être appliquée directement sur un environnement déployé, sous peine de rendre l'artefact non reproductible et le rollback imprévisible.

Un correctif urgent sur une version déjà publiée se traite par une branche `hotfix/X.Y.Z` créée à partir du tag concerné, puis par une nouvelle release correctrice. Le dépôt reste en trunk-based : `main` est la seule branche durable.

#### Mise à jour des dépendances

| Périmètre | Outil de détection | Commande de mise à jour | Cadence |
| --- | --- | --- | --- |
| Dépendances npm | `npm audit` dans le job `security`, alertes Dependabot | `npm update` puis `npm ci` pour régénérer `package-lock.json` | Revue à chaque sprint |
| Dépendances Gradle | `./gradlew dependencies`, scan Trivy, alertes Dependabot | Modification de `back/build.gradle` | Revue à chaque sprint |
| Images de base Docker | Scan Trivy du système de fichiers, `docker scout cves` | Modification des `FROM` du `Dockerfile` | Revue mensuelle |
| Actions GitHub | Alertes Dependabot | Mise à jour du SHA épinglé dans `.github/workflows/` | Revue mensuelle |
| Pile ELK | Notes de version Elastic | Modification des tags dans `docker-compose-elk.yml` | Revue semestrielle |

Les installations se font exclusivement à partir des fichiers verrouillés, `npm ci` et le Gradle Wrapper, afin que la CI, le poste de développement et l'image publiée résolvent strictement les mêmes versions.

#### Règles de traitement

Une vulnérabilité **critique sur une dépendance de production** interrompt la chaîne et bloque la publication. L'audit complet incluant les dépendances de développement s'exécute en mode rapport : les outils de build Angular portent des vulnérabilités connues qui ne sont pas livrées en production et dont la correction impose une montée de version majeure, planifiée séparément. Ce seuil différencié est un choix assumé, pas un contournement.

Les mises à jour sont appliquées par lots cohérents et séparées des évolutions fonctionnelles, afin qu'une régression puisse être imputée sans ambiguïté. Une montée de version majeure de Java, Node.js, Spring Boot ou Angular fait l'objet d'une pull request dédiée, avec exécution complète des tests et contrôle du Quality Gate avant fusion.

#### Vérification après mise à jour

Une mise à jour n'est considérée comme réussie qu'après trois contrôles : CI verte incluant les tests backend et frontend, Quality Gate SonarQube réussi, et absence de hausse du taux d'erreurs dans Kibana pendant les 15 minutes suivant le déploiement. Les métriques DORA relevées après chaque livraison permettent de détecter une dégradation progressive de la chaîne, notamment un allongement du Lead Time ou une hausse du Change Failure Rate.

### Mise en œuvre de la CI GitHub Actions

Le workflow [`ci.yml`](.github/workflows/ci.yml) centralise l'intégration continue. Il est déclenché sur chaque push, sur les pull requests vers `main`, chaque nuit à 02:30 UTC et manuellement depuis l'onglet **Actions** de GitHub.

Les jobs s'exécutent comme suit :

1. `backend` installe Java 17, utilise le Gradle Wrapper, exécute `./gradlew build collectSonarLibraries` et conserve les rapports de tests, la couverture JaCoCo, les classes compilées de production et de test ainsi que les dépendances du classpath.
2. `frontend` installe Node.js 20 et Chrome, exécute `npm ci`, les tests Karma en mode `ChromeHeadlessNoSandbox`, puis `npm run build`. Les rapports de couverture et le dossier `dist` sont conservés.
3. `security` exécute `npm audit --audit-level=high`, résout les dépendances Gradle et lance Trivy sur le dépôt pour détecter les vulnérabilités critiques/élevées et les secrets accidentellement présents.
4. `sonar`, dépendant des deux builds, récupère les classes Java, le classpath de compilation et la couverture frontend, puis soumet l'analyse à SonarQube Cloud. Le Quality Gate est vérifié séparément par le check GitHub **SonarCloud Code Analysis**, posté directement par l'application SonarCloud sur la pull request et le commit ; ce check doit être ajouté aux règles de protection de la branche `main` pour bloquer réellement une fusion en cas d'échec.

La première analyse de `main` a produit trois avertissements SonarCloud signalant l'absence des propriétés `sonar.java.libraries`, `sonar.java.test.binaries` et `sonar.java.test.libraries`. Sans le classpath, l'analyseur Java ne résout pas les types provenant des dépendances et dégrade silencieusement la détection : les règles liées à Spring, à JPA ou aux API tierces ne peuvent pas s'appliquer. La tâche Gradle `collectSonarLibraries` copie donc les jars du `testRuntimeClasspath` dans `back/build/sonar-libraries`, publiés comme artefact et transmis au scanner. Un résultat d'analyse sans avertissement est la condition pour que les métriques Java soient comparables d'une livraison à l'autre.

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
