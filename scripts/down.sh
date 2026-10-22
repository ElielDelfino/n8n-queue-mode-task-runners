#!/usr/bin/env bash
# Remove os containers (ordem inversa). Os DADOS ficam em $STORAGE_DIR e a rede é mantida:
# rodar up.sh de novo traz tudo de volta — é o que significa app stateless.
. "$(dirname "$0")/_common.sh"

for c in n8n-webhook n8n-runner n8n-worker n8n-editor n8n-redis n8n-pgsql traefik-app; do
    remove_container "$c" && echo "  removido: $c"
done

echo "Containers removidos. Dados preservados em $STORAGE_DIR."
