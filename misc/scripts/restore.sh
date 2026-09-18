#!/usr/bin/env bash
# Redeploie une version deja publiee dans GHCR et verifie que le service repond.
# Usage: misc/scripts/restore.sh <sha-ou-tag>
set -euo pipefail

OWNER="${GHCR_OWNER:-zeinatofik25-svg}"
TIMEOUT="${HEALTH_TIMEOUT:-300}"
REF="${1:-}"

if [ -z "$REF" ]; then
  echo "Usage: $0 <sha-ou-tag>" >&2
  echo "Exemple: $0 fa81dc4e8d84cd442154df40ba3d449ce2958828" >&2
  exit 2
fi

cd "$(dirname "$0")/../.."

echo "==> Recuperation des images ${REF}"
docker pull "ghcr.io/${OWNER}/microcrm-front:${REF}"
docker pull "ghcr.io/${OWNER}/microcrm-back:${REF}"

docker tag "ghcr.io/${OWNER}/microcrm-front:${REF}" orion-microcrm-front:local
docker tag "ghcr.io/${OWNER}/microcrm-back:${REF}" orion-microcrm-back:local

echo "==> Redeploiement sans reconstruction"
start=$(date +%s)
docker compose up -d --no-build --force-recreate

echo "==> Attente des controles de sante (max ${TIMEOUT}s)"
deadline=$(( start + TIMEOUT ))
for service in back front; do
  container="$(docker compose ps -q "$service")"
  until [ "$(docker inspect -f '{{.State.Health.Status}}' "$container")" = "healthy" ]; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
      echo "ECHEC: ${service} n'est pas healthy apres ${TIMEOUT}s" >&2
      docker compose logs --tail 50 "$service" >&2
      exit 1
    fi
    sleep 5
  done
  echo "    ${service} healthy"
done

echo "==> Smoke test"
for url in http://localhost/health http://localhost/api/persons http://localhost/api/organizations; do
  if curl -fsS -o /dev/null --max-time 20 "$url"; then
    echo "    OK  ${url}"
  else
    echo "ECHEC: ${url} ne repond pas" >&2
    exit 1
  fi
done

echo "==> Restauration terminee en $(( $(date +%s) - start ))s sur la version ${REF}"
