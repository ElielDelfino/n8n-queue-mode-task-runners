#!/usr/bin/env bash
# Mostra o estado dos containers e testa os endpoints /healthz via Traefik.
. "$(dirname "$0")/_common.sh"

docker ps -a --filter "network=$NETWORK" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
echo

for host in "$N8N_EDITOR_HOST" "$N8N_WEBHOOK_HOST"; do
    if curl -sf -o /dev/null -H "Host: $host" http://127.0.0.1/healthz; then
        echo "  ✔ $host /healthz"
    else
        echo "  ✘ $host /healthz"
    fi
done
