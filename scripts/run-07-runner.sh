#!/usr/bin/env bash
# Passo 7 — Task-runner: sandbox que executa o código JS/Python do Code node.
# Recebe do worker só o necessário (código + INPUT do node). Se travar, falha só o Code
# node — o worker sobrevive.
# Menor privilégio: NÃO recebe senha do Postgres, nem Redis, nem N8N_ENCRYPTION_KEY.
. "$(dirname "$0")/_common.sh"
require_vars N8N_RUNNERS_AUTH_TOKEN

remove_container n8n-runner

docker run -d --restart=always \
    --name n8n-runner -h n8n-runner.intranet.br \
    --cpus=4 --memory=4g --memory-swap=4g --shm-size=1g \
    --tmpfs /run:rw,noexec,nosuid,size=512m \
    --tmpfs /tmp:rw,noexec,nosuid,size=512m \
    \
    --network "$NETWORK" \
    \
    -v "$STORAGE_DIR/n8n-app/runner":/data \
    \
    -e GENERIC_TIMEZONE="$TIMEZONE" \
    -e TZ="$TIMEZONE" \
    -e N8N_DIAGNOSTICS_ENABLED=false \
    -e N8N_USER_FOLDER=/data \
    `# Onde está o broker (o worker) e o token que prova que o runner é legítimo` \
    -e N8N_RUNNERS_TASK_BROKER_URI=http://n8n-worker:5679 \
    -e N8N_RUNNERS_AUTH_TOKEN="$N8N_RUNNERS_AUTH_TOKEN" \
    -e N8N_RUNNERS_MAX_CONCURRENCY=128 \
    \
    "$RUNNER_IMAGE"
