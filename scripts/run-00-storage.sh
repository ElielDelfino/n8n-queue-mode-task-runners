#!/usr/bin/env bash
# Passo 0 — Pastas de dados persistentes (bind mounts).
# Containers são descartáveis; o que precisa sobreviver a um "docker rm" vive aqui.
. "$(dirname "$0")/_common.sh"

mkdir -p \
    "$STORAGE_DIR/traefik-app/config" \
    "$STORAGE_DIR/traefik-app/logs" \
    "$STORAGE_DIR/n8n-pgsql" \
    "$STORAGE_DIR/n8n-redis" \
    "$STORAGE_DIR/n8n-app/editor" \
    "$STORAGE_DIR/n8n-app/webhook" \
    "$STORAGE_DIR/n8n-app/worker" \
    "$STORAGE_DIR/n8n-app/runner"

# Postgres e Redis iniciam como root e ajustam o dono da própria pasta (UID 999) sozinhos.
# O n8n roda direto como o usuário "node" (UID 1000): se o seu usuário no host não for
# o 1000, a pasta precisa ser entregue a ele, senão o n8n não consegue gravar.
if [[ "$(id -u)" != "1000" ]]; then
    echo "Seu UID não é 1000 — ajustando dono de $STORAGE_DIR/n8n-app para 1000:1000 (sudo)."
    sudo chown -R 1000:1000 "$STORAGE_DIR/n8n-app"
fi

echo "Storage pronto em $STORAGE_DIR"
