#!/usr/bin/env bash
# Passo 8 — Webhook: servidor HTTP dedicado aos gatilhos de PRODUÇÃO (/webhook/...).
# Recebe a requisição e ENFILEIRA no Redis — quem executa é o worker.
# Assim um pico de webhooks não deixa o editor lento.
. "$(dirname "$0")/_common.sh"
require_vars POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB N8N_ENCRYPTION_KEY

remove_container n8n-webhook

docker run -d --restart=always \
    --name n8n-webhook -h n8n-webhook.intranet.br \
    --cpus=4 --memory=4g --memory-swap=4g --shm-size=1g \
    --tmpfs /run:rw,noexec,nosuid,size=512m \
    --tmpfs /tmp:rw,noexec,nosuid,size=512m \
    \
    --network "$NETWORK" \
    \
    -v "$STORAGE_DIR/n8n-app/webhook":/data \
    \
    `# --- Grupo 1: modo fila + Redis + Postgres ---` \
    -e EXECUTIONS_MODE=queue \
    -e EXECUTIONS_TIMEOUT=1800 \
    -e QUEUE_BULL_REDIS_HOST=n8n-redis \
    -e DB_TYPE=postgresdb \
    -e DB_POSTGRESDB_HOST=n8n-pgsql \
    -e DB_POSTGRESDB_DATABASE="$POSTGRES_DB" \
    -e DB_POSTGRESDB_USER="$POSTGRES_USER" \
    -e DB_POSTGRESDB_PASSWORD="$POSTGRES_PASSWORD" \
    -e N8N_METRICS=true \
    \
    `# --- Grupo 2: base de todo serviço n8n ---` \
    -e N8N_ENCRYPTION_KEY="$N8N_ENCRYPTION_KEY" \
    -e NODE_ENV=production \
    -e GENERIC_TIMEZONE="$TIMEZONE" \
    -e TZ="$TIMEZONE" \
    -e N8N_DIAGNOSTICS_ENABLED=false \
    -e N8N_USER_FOLDER=/data \
    \
    `# --- Grupo 3: acesso web LOCAL (atrás do Traefik, sem HTTPS) ---` \
    -e N8N_HOST="$N8N_WEBHOOK_HOST" \
    -e N8N_PROTOCOL=http \
    -e N8N_PROXY_HOPS=1 \
    -e WEBHOOK_URL="http://$N8N_WEBHOOK_HOST/" \
    \
    `# --- Labels do Traefik: roteia N8N_WEBHOOK_HOST -> este container ---` \
    --label "traefik.enable=true" \
    --label "traefik.http.routers.n8n-webhook.rule=Host(\`$N8N_WEBHOOK_HOST\`)" \
    --label "traefik.http.routers.n8n-webhook.entrypoints=web" \
    --label "traefik.http.services.n8n-webhook.loadbalancer.server.port=5678" \
    \
    "$N8N_IMAGE" webhook
