#!/usr/bin/env bash
# Passo 1 — Rede bridge dedicada.
# Só numa rede "user-defined" o Docker oferece DNS interno: é isso que permite
# usar QUEUE_BULL_REDIS_HOST=n8n-redis (nome) em vez de IP.
. "$(dirname "$0")/_common.sh"

if docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "Rede $NETWORK já existe — nada a fazer."
    exit 0
fi

# bridge.name vira o nome da interface no Linux: precisa ter no máximo 15 caracteres.
docker network create \
    -d bridge \
    --subnet 10.250.0.0/16 \
    --gateway 10.250.255.254 \
    -o com.docker.network.bridge.name=br-n8n-net \
    -o com.docker.network.bridge.enable_icc=true \
    -o com.docker.network.driver.mtu=1500 \
    "$NETWORK"
