#!/usr/bin/env bash
# Passo 3 — PostgreSQL: a fonte da verdade.
# Guarda workflows, credentials (cifradas), execuções e usuários.
# Sem -p e sem label do Traefik: só é alcançável por dentro da rede (menor privilégio).
. "$(dirname "$0")/_common.sh"
require_vars POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB

remove_container n8n-pgsql

docker run -d --restart=always \
    --name n8n-pgsql -h n8n-pgsql.intranet.br \
    --read-only \
    --tmpfs /run:rw,noexec,nosuid,size=128m \
    --tmpfs /tmp:rw,noexec,nosuid,size=128m \
    --cpus="2.0" --memory=2g --memory-swap=2g --shm-size=1g \
    \
    --network "$NETWORK" \
    \
    -v "$STORAGE_DIR/n8n-pgsql":/var/lib/postgresql/data \
    \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -e PGDATA=/var/lib/postgresql/data/pgdata \
    \
    --health-cmd="pg_isready -U $POSTGRES_USER -d $POSTGRES_DB" \
    --health-interval=5s \
    --health-timeout=5s \
    --health-retries=10 \
    \
    "$POSTGRES_IMAGE" \
        postgres \
            --max_connections=200 \
            --wal_level=minimal \
            --max_wal_senders=0 \
            --port=5432
