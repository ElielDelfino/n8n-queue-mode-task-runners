#!/usr/bin/env bash
# Passo 2 — Traefik (proxy reverso).
# Única porta de entrada do stack. Roteia pelo header Host:
#   n8n.localhost -> n8n-editor    ws.localhost -> n8n-webhook
# Descobre os containers sozinho lendo as labels via socket do Docker.
. "$(dirname "$0")/_common.sh"

remove_container traefik-app

docker run -d --restart=always \
    --name traefik-app -h traefik-app.intranet.br \
    --read-only \
    --tmpfs /run:rw,noexec,nosuid,size=8m \
    --tmpfs /tmp:rw,noexec,nosuid,size=8m \
    --cpus="2.0" --memory=1g --memory-swap=1g \
    \
    --network "$NETWORK" \
    \
    -p 80:80 \
    `# Dashboard sem autenticação (api.insecure): só acessível a partir da própria máquina` \
    -p 127.0.0.1:8080:8080 \
    \
    `# Caminho ABSOLUTO: um caminho inexistente vira pasta vazia em silêncio` \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v "$STORAGE_DIR/traefik-app/config":/etc/traefik \
    -v "$STORAGE_DIR/traefik-app/logs":/logs \
    \
    "traefik:${TRAEFIK_VERSION}" \
    \
    --global.checknewversion=false \
    --global.sendanonymoususage=false \
    --api.insecure=true \
    --log.level=INFO \
    --log.filepath=/logs/error.log \
    --accessLog.filepath=/logs/access.log \
    --entrypoints.web.address=:80 \
    --providers.docker=true \
    --providers.docker.exposedbydefault=false \
    --providers.file.directory=/etc/traefik
