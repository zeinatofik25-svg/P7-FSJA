# MicroCRM

Application de gestion de personnes et d'organisations, composée d'un backend Java/Spring Boot et d'un frontend Angular. La documentation détaillée du projet et de son pipeline est dans [docs/documentation.md](docs/documentation.md).

## Choix techniques

- **Backend** : Java 17, Spring Boot 3.2 et Spring Data REST pour exposer l'API.
- **Données** : HSQLDB en mémoire, adaptée à la démonstration ; les données sont réinitialisées au redémarrage.
- **Frontend** : Angular 17 et TypeScript.
- **Conteneurs** : Docker multi-stage sépare les outils de build des images d'exécution ; Docker Compose lance les services. Caddy sert le frontend et relaie les appels API.
- **CI/CD** : GitHub Actions exécute les builds, tests et contrôles de sécurité ; les images sont publiées dans GHCR avec un tag correspondant au commit.
- **Qualité et suivi** : SonarQube Cloud mesure la qualité ; une pile Elasticsearch, Logstash et Kibana est disponible séparément pour les journaux.

## Exécution avec Docker

Prérequis : Docker Engine et Docker Compose v2.

Depuis la racine du dépôt :

```shell
docker compose up --build -d
docker compose ps
```

L'interface est disponible sur http://localhost et l'API sur http://localhost:8080. Pour arrêter les services :

```shell
docker compose down
```

Pour démarrer également la pile de monitoring, lancez-la avant l'application :

```shell
docker compose -f docker-compose-elk.yml up --build -d
```

Kibana est alors disponible sur http://localhost:5601.

## Exécution depuis les sources

Prérequis : Java 17, Node.js 20, npm et Chrome ou Chromium pour les tests frontend.

```shell
# Backend : build et tests
cd back
.\gradlew.bat build

# Frontend : installation, tests et build
cd ../front
npm ci
npm test -- --watch=false --browsers=ChromeHeadlessNoSandbox
npm run build
```
