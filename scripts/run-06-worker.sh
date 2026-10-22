#!/usr/bin/env bash
# Passo 6 — Worker: pega jobs da fila no Redis e executa os nodes, um a um.
# Também é o "broker" dos task-runners: abre a porta 5679 para o runner se conectar.
# Não tem label do Traefik: ninguém de fora fala com ele.
. "$(dirname "$0")/_common.sh"
require_vars POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB N8N_ENCRYPTION_KEY N8N_RUNNERS_AUTH_TOKEN

remove_container n8n-worker

docker run -d --restart=always \
    --name n8n-worker -h n8n-worker.intranet.br \
    --cpus=4 --memory=4g --memory-swap=4g --shm-size=1g \
    --tmpfs /run:rw,noexec,nosuid,size=512m \
    --tmpfs /tmp:rw,noexec,nosuid,size=512m \
    \
    --network "$NETWORK" \
    \
    -v "$STORAGE_DIR/n8n-app/worker":/data \
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
    `# Mesma chave do editor: é o worker que decifra as credentials na hora de executar` \
    -e N8N_ENCRYPTION_KEY="$N8N_ENCRYPTION_KEY" \
    -e NODE_ENV=production \
    -e GENERIC_TIMEZONE="$TIMEZONE" \
    -e TZ="$TIMEZONE" \
    -e N8N_DIAGNOSTICS_ENABLED=false \
    -e N8N_USER_FOLDER=/data \
    \
    `# --- Grupo 4: execução com task-runner ---` \
    -e N8N_RUNNERS_MODE=external \
    -e N8N_RUNNERS_AUTH_TOKEN="$N8N_RUNNERS_AUTH_TOKEN" \
    -e EXECUTIONS_DATA_SAVE_ON_PROGRESS=true \
    -e EXECUTIONS_DATA_SAVE_ON_SUCCESS=all \
    `# Padrão é 127.0.0.1 (só dentro do próprio container): o runner, em outro container, não alcançaria` \
    -e N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0 \
    \
    "$N8N_IMAGE" worker
