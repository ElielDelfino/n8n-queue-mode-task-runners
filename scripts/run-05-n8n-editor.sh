#!/usr/bin/env bash
# Passo 5 — Editor (main): UI, administração, edição e testes de workflows.
# É o primeiro processo n8n a subir: na primeira vez ele roda as migrations no Postgres.
. "$(dirname "$0")/_common.sh"
require_vars POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB N8N_ENCRYPTION_KEY N8N_RUNNERS_AUTH_TOKEN

remove_container n8n-editor

docker run -d --restart=always \
    --name n8n-editor -h n8n-editor.intranet.br \
    --cpus=4 --memory=4g --memory-swap=4g --shm-size=1g \
    --tmpfs /run:rw,noexec,nosuid,size=512m \
    --tmpfs /tmp:rw,noexec,nosuid,size=512m \
    \
    --network "$NETWORK" \
    \
    -v "$STORAGE_DIR/n8n-app/editor":/data \
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
    -e N8N_HOST="$N8N_EDITOR_HOST" \
    -e N8N_PROTOCOL=http \
    -e N8N_PROXY_HOPS=1 \
    -e N8N_SECURE_COOKIE=false \
    -e N8N_EDITOR_BASE_URL="http://$N8N_EDITOR_HOST/" \
    -e WEBHOOK_URL="http://$N8N_WEBHOOK_HOST/" \
    \
    `# --- Grupo 4: execução com task-runner ---` \
    -e N8N_RUNNERS_MODE=external \
    -e N8N_RUNNERS_AUTH_TOKEN="$N8N_RUNNERS_AUTH_TOKEN" \
    -e EXECUTIONS_DATA_SAVE_ON_PROGRESS=true \
    -e EXECUTIONS_DATA_SAVE_ON_SUCCESS=all \
    `# Sem isso, o botão "Executar" roda no editor (que não tem runner) e o Code node dá timeout` \
    -e OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true \
    \
    `# --- Grupo 5: exclusivo do editor ---` \
    -e N8N_VERSION_NOTIFICATIONS_ENABLED=false \
    -e N8N_VERSION_NOTIFICATIONS_WHATS_NEW_ENABLED=false \
    -e N8N_PUBLIC_API_SWAGGERUI_DISABLED=true \
    -e N8N_METRICS=true \
    \
    `# --- Labels do Traefik: roteia N8N_EDITOR_HOST -> este container ---` \
    --label "traefik.enable=true" \
    --label "traefik.http.routers.n8n-editor.rule=Host(\`$N8N_EDITOR_HOST\`)" \
    --label "traefik.http.routers.n8n-editor.entrypoints=web" \
    --label "traefik.http.services.n8n-editor.loadbalancer.server.port=5678" \
    \
    "$N8N_IMAGE"
