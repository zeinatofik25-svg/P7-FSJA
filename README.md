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

Au moment de cette rédaction, aucun rapport SonarQube Cloud exporté ni aucune exécution analysée n'est disponible dans le dépôt. Il serait incorrect d'attribuer un nombre de vulnérabilités, de duplications ou un pourcentage de couverture à SonarQube sans cette preuve. Le tableau suivant constitue donc le backlog de revue prioritaire : les éléments marqués **constaté** ont été vérifiés dans le code ; les autres sont à qualifier avec la sévérité et la règle exacte proposées par SonarQube lors de la première analyse complète.

| Priorité | Domaine | Constat ou contrôle SonarQube à relever | Risque | Traitement attendu |
| --- | --- | --- | --- | --- |
| P1 | Exposition API | **Constaté** : les repositories Spring Data REST exposent lecture et écriture des personnes et organisations, sans mécanisme d'authentification applicatif visible | Modification ou consultation non autorisée de données personnelles | Ajouter une authentification et une autorisation par rôle avant tout déploiement public |
| P1 | CORS | **Constaté** : la configuration autorise l'origine `*` sur toutes les routes | Une application tierce peut appeler l'API depuis le navigateur d'un utilisateur | Limiter les origines aux URL de l'interface selon l'environnement ; interdire toute origine non attendue |
| P1 | Données personnelles | **Constaté** : `Person` contient e-mail, téléphone et biographie | Exposition de données personnelles par l'API ou les logs | Minimiser les champs exposés, documenter la conservation et ne jamais journaliser les objets `Person` complets |
| P1 | Vulnérabilités | Relever les vulnérabilités et Security Hotspots Java/TypeScript ouvertes | Exploitation d'une faiblesse identifiée par SonarQube | Corriger immédiatement les vulnérabilités critiques et hautes ; examiner chaque Security Hotspot avant fusion |
| P1 | Dépendances | Relever les alertes des dépendances directes et transitives | Composant connu vulnérable | Mettre à jour de manière compatible ; contrôler aussi `npm audit` et le scan Trivy |
| P2 | Validation des entrées | **Constaté** : aucun contrat DTO ni annotation de validation n'est visible sur l'entité `Person` | Données invalides, volumétrie non maîtrisée et erreurs applicatives | Introduire des DTO et les contraintes `@NotBlank`, `@Email`, longueurs maximales ; ajouter les tests 400 associés |
| P2 | Couverture backend | Relever la couverture Java mesurée par JaCoCo et importée depuis `back/build/reports/jacoco/test/jacocoTestReport.xml` | Zones REST et erreurs non protégées par des tests | Compléter les tests des cas d'erreur et viser 80 % sur le nouveau code |
| P2 | Couverture frontend | Relever la couverture LCOV importée depuis `front/coverage/microcrm/lcov.info` | Régression de composants/services Angular | Ajouter les tests d'erreur HTTP, de formulaire et de navigation ; viser 80 % sur le nouveau code |
| P2 | Duplications | Relever le pourcentage de duplication global et sur le nouveau code, séparément pour Java et TypeScript | Corrections incohérentes et maintenance coûteuse | Extraire les méthodes/services communs uniquement lorsque SonarQube confirme une duplication significative |
| P2 | Complexité | Trier les méthodes et composants par complexité cognitive et nombre de branches | Défauts difficiles à détecter et tester | Découper les méthodes au-dessus du seuil du Quality Profile, avec tests de non-régression |
| P2 | Fiabilité | Relever bugs, exceptions non traitées et code mort signalés | Erreurs de production ou dette technique | Corriger les bugs bloquants avant fusion ; planifier les code smells dans le sprint suivant |
| P3 | Maintenabilité | Relever code smells, dette estimée et règles de style | Lisibilité réduite et coût de changement | Traiter les alertes sur le nouveau code ; ne pas entreprendre de refactoring massif sans besoin métier |

Les éléments P1 constituent des risques de sécurité ou de confidentialité ; ils ne doivent pas être assimilés aux code smells P3. Les duplications et la complexité sont principalement des indicateurs de maintenabilité et deviennent des risques de fiabilité lorsqu'ils empêchent de tester ou de corriger le code avec confiance.

#### Quality Gate et règles de traitement

Le Quality Gate appliqué aux pull requests et à `main` doit exiger : aucune nouvelle vulnérabilité ni nouveau bug bloquant, aucune Security Hotspot non examinée, une couverture d'au moins 80 % sur le nouveau code et un taux de duplication inférieur à 3 % sur le nouveau code. La première analyse doit être archivée dans la documentation de sprint avec : date, branche/SHA, statut du Quality Gate, nombre de bugs, vulnérabilités, Security Hotspots, code smells, duplications, complexité et couverture, séparés par langage lorsque SonarQube les fournit.

| Relevé SonarQube | Valeur à compléter après analyse | Décision |
| --- | --- | --- |
| Quality Gate | À compléter | Échec : fusion bloquée |
| Vulnérabilités ouvertes | À compléter | Toute criticité haute ou critique : correction prioritaire |
| Security Hotspots examinées | À compléter | 100 % requis avant livraison |
| Bugs | À compléter | Bloquant/critique : correction avant fusion |
| Duplications nouveau code | À compléter | Supérieur à 3 % : justification ou refactoring ciblé |
| Complexité des méthodes prioritaires | À compléter | Découpage et tests lorsque le seuil du profil est dépassé |
| Couverture nouveau code Java | À compléter | Inférieure à 80 % : ajouter les tests et le rapport JaCoCo |
| Couverture nouveau code TypeScript | À compléter | Inférieure à 80 % : ajouter les tests Jasmine/Karma |

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

#### Tableau provisoire DORA

| Métrique DORA | Méthode de calcul | Source | Valeur initiale | Cible après 3 sprints |
| --- | --- | --- | --- | --- |
| Lead Time for Changes | Médiane entre l'heure du commit livré sur `main` et la fin du workflow CD associé au même SHA | GitHub commits et fin du workflow `Continuous Deployment` | Non mesurable : aucune livraison CD historisée dans le dépôt local | Moins de 1 jour ouvré |
| Deployment Frequency | Nombre de déploiements CD réussis sur `main` / 7 jours | Workflows `Continuous Deployment` réussis | Non mesurable : aucune exécution CD disponible | Au moins 1 déploiement par semaine |
| Mean Time to Restore (MTTR) | Moyenne entre le début d'un incident horodaté et le retour à un contrôle de santé réussi | Incident, logs Kibana, horodatage du rollback ou du correctif déployé | Non mesurable : aucun incident consigné | Moins de 4 heures |
| Change Failure Rate | (Déploiements ayant causé incident, rollback ou hotfix urgent / déploiements totaux) x 100 | GitHub Deployments, incidents et tickets | Non mesurable : aucune livraison CD disponible | Inférieur à 15 % |

Le taux d'échec ne doit compter qu'un déploiement une seule fois, même s'il produit plusieurs erreurs. Un échec de CI avant déploiement reste un signal de qualité, mais ne constitue pas un échec de changement DORA. De la même manière, une erreur isolée dans Kibana n'est un incident que si elle dégrade le service ou exige une intervention.

#### KPIs complémentaires

| KPI | Méthode de calcul | Source | Cible opérationnelle | Action si seuil dépassé |
| --- | --- | --- | --- | --- |
| Durée CI | Médiane de la durée totale des 3 derniers workflows `Continuous Integration` réussis | GitHub Actions | Moins de 15 min | Identifier l'étape lente et exploiter le cache Gradle/npm |
| Taux de réussite CI | (Workflows CI réussis / workflows CI terminés) x 100 sur 30 jours | GitHub Actions | Au moins 95 % | Corriger ou isoler le test instable avant nouveau merge |
| Durée des tests | Durée médiane des étapes `Build and test` et `Run unit tests with coverage` | Logs GitHub Actions | Backend moins de 5 min, frontend moins de 8 min | Réduire les tests redondants ou améliorer le cache |
| Couverture de tests | Couverture du nouveau code mesurée par SonarQube ; couverture globale suivie à titre indicatif | SonarQube Cloud et `front/coverage` | Au moins 80 % sur le nouveau code | Ajouter des tests avant validation de la pull request |
| Qualité SonarQube | Quality Gate réussi, avec 0 vulnérabilité et 0 bug bloquant sur le nouveau code | SonarQube Cloud | 100 % des Quality Gates réussis | Bloquer la fusion et corriger les alertes |
| Fréquence d'erreurs applicatives | Nombre de logs `ERROR` / nombre total de logs sur 15 min, ventilé par `service_name` | Kibana, index `microcrm-logs-*` | Inférieur à 1 % | Investiguer les erreurs répétées et créer un incident si le service est impacté |

#### Procédure de relève

Après chaque déploiement sur `main`, relever le SHA, l'heure du commit, l'heure de fin de CD, le statut du Quality Gate, la durée CI et la présence d'un incident. Conserver au minimum les trois relevés suivants dans le tableau de suivi de sprint :

| SHA | Commit livré (UTC) | Fin CD (UTC) | Durée CI | Quality Gate | Incident / rollback | Retour au service (UTC) |
| --- | --- | --- | --- | --- | --- | --- |
| `f0e274c` | 2026-09-14 10:18:31 | 2026-09-14 11:13:01 | 2 min 26 s | OK | Non | Sans objet |
| `7533d6d` | 2026-09-14 19:17:33 | 2026-09-14 19:30:38 | 2 min 11 s | OK | Non | Sans objet |
| À compléter | À compléter | À compléter | À compléter | À compléter | Non / Oui | Sans objet / À compléter |

L'heure de commit retenue est la date d'auteur du commit applicatif (`af7d58e`), et non celle du commit de fusion : c'est le moment où le changement a été écrit, conformément à la définition du Lead Time. Le mode de fusion « merge commit » a été choisi pour cette raison, un squash réécrivant l'horodatage d'origine et ramenant artificiellement la métrique à quelques minutes.

Pour Kibana, le panneau `Erreurs par service` utilise le filtre KQL `log_level: "ERROR"`. Le KPI de fréquence d'erreurs se calcule avec le même intervalle que le panneau de volume : $taux\ d'erreurs = \frac{nombre\ de\ logs\ ERROR}{nombre\ total\ de\ logs} \times 100$. Lors d'un pic de volume, comparer cette valeur avec la période précédente : un volume élevé sans hausse du taux d'erreurs correspond à une activité accrue, tandis qu'une hausse simultanée signale un risque de fiabilité.

#### Analyse initiale et recommandations

Le pipeline est conçu pour limiter les changements risqués : tests backend et frontend, audit des dépendances, recherche de secrets et Quality Gate SonarQube précèdent la publication. Le workflow CD est déclenché seulement pour une CI réussie provenant d'un push sur `main`, ce qui assure la traçabilité du SHA livré. En revanche, aucune exécution CI/CD et aucun incident de production ne sont disponibles dans les données locales ; les quatre métriques DORA ne peuvent donc pas être chiffrées de manière fiable à ce stade.

La priorité du prochain sprint est de réaliser au moins trois livraisons sur `main`, de compléter le tableau de relève pour chacune et d'enregistrer les incidents avec heures de début et de résolution. L'équipe pourra alors remplacer les valeurs provisoires par les médianes et moyennes observées. Les tableaux Kibana complètent ces métriques en révélant les pics de charge et la fréquence des erreurs après livraison ; ils ne remplacent pas l'horodatage des déploiements ni la déclaration d'incident nécessaires au calcul DORA.

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

#### Stratégie de déploiement

1. Un push sur `main` qui passe les tests, les scans et le Quality Gate construit les images `front` et `back`.
2. Les images sont publiées dans GitHub Container Registry avec un tag immuable correspondant au SHA du commit. Un tag de version peut être ajouté pour faciliter l'exploitation, mais `latest` ne doit pas être utilisé comme référence de déploiement.
3. Un environnement de recette déploie ces mêmes artefacts et exécute les smoke tests via Compose. La promotion vers la production réutilise les images déjà validées, sans recompilation.
4. Le déploiement de production est protégé par un environnement GitHub avec approbation manuelle, secrets séparés et journalisation. En cas d'échec, le tag du dernier SHA validé est redéployé.

Les sauvegardes concernent d'abord les artefacts, la configuration et les manifests. Une vraie sauvegarde applicative nécessitera une base persistante externe ; elle devra être ajoutée avant de considérer le service prêt pour une production avec conservation des données.

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
