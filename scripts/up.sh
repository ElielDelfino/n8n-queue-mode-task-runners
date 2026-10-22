#!/usr/bin/env bash
# Sobe o stack inteiro, na ordem certa, esperando cada dependência ficar pronta.
# Para aprender, prefira rodar os run-0X um a um (ver docs/02-passo-a-passo.md).
. "$(dirname "$0")/_common.sh"
DIR="$(dirname "$0")"

# Falha antes de criar qualquer coisa se o .env não estiver completo.
require_vars N8N_VERSION POSTGRES_IMAGE REDIS_VERSION TRAEFIK_VERSION \
    N8N_EDITOR_HOST N8N_WEBHOOK_HOST TIMEZONE \
    POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB N8N_ENCRYPTION_KEY N8N_RUNNERS_AUTH_TOKEN

echo "[0/8] storage";    bash "$DIR/run-00-storage.sh"
echo "[1/8] rede";       bash "$DIR/run-01-network.sh"
echo "[2/8] traefik";    bash "$DIR/run-02-traefik.sh"
echo "[3/8] postgres";   bash "$DIR/run-03-postgresql.sh"
echo "[4/8] redis";      bash "$DIR/run-04-redis.sh"
wait_healthy n8n-pgsql
wait_healthy n8n-redis

# O editor sobe sozinho primeiro: ele aplica as migrations no banco vazio.
echo "[5/8] editor";     bash "$DIR/run-05-n8n-editor.sh"
wait_http "$N8N_EDITOR_HOST"

echo "[6/8] worker";     bash "$DIR/run-06-worker.sh"
echo "[7/8] runner";     bash "$DIR/run-07-runner.sh"
echo "[8/8] webhook";    bash "$DIR/run-08-webhook.sh"
wait_http "$N8N_WEBHOOK_HOST"

echo
echo "Stack de pé:"
echo "  Editor:   http://$N8N_EDITOR_HOST"
echo "  Webhooks: http://$N8N_WEBHOOK_HOST/webhook/<path>"
echo "  Traefik:  http://127.0.0.1:8080/dashboard/"
