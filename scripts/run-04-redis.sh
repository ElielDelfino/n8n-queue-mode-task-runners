#!/usr/bin/env bash
# Passo 4 — Redis: a fila (Bull) + pub/sub entre os processos n8n.
# Editor e webhook ENFILEIRAM jobs aqui; workers ociosos pegam.
# Pelo Redis trafega só o "sinal" leve — o dado pesado fica no Postgres.
. "$(dirname "$0")/_common.sh"

remove_container n8n-redis

docker run -d --restart=always \
    --name n8n-redis -h n8n-redis.intranet.br \
    --read-only \
    --cpus="1.0" --memory=1g --memory-swap=1g \
    \
    --network "$NETWORK" \
    \
    -v "$STORAGE_DIR/n8n-redis":/data \
    -w /data \
    \
    --health-cmd="redis-cli ping" \
    --health-interval=1s \
    --health-timeout=3s \
    \
    "redis:${REDIS_VERSION}" \
        redis-server \
            --tcp-backlog 8192 --tcp-keepalive 30 --timeout 0 \
            --dir /data --save 16 1 --save 12 10 --save 6 100 \
            --rdbcompression no --appendonly yes --appendfsync everysec
