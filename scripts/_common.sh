#!/usr/bin/env bash
# Carregado por todos os scripts (source). Centraliza:
#   - leitura do .env (segredos + versões + domínios)
#   - valores padrão
#   - funções utilitárias (remover container, validar variáveis, esperar healthcheck)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
    echo "ERRO: $ROOT_DIR/.env não encontrado." >&2
    echo "      Rode: cp .env.example .env  e preencha os segredos." >&2
    exit 1
fi

# Exporta tudo que está no .env para o shell (set -a = auto-export):
set -a; . "$ROOT_DIR/.env"; set +a

# Padrões (podem ser sobrescritos no .env):
STORAGE_DIR="${STORAGE_DIR:-$HOME/storage}"
NETWORK="${NETWORK:-n8n_net}"
N8N_IMAGE="docker.n8n.io/n8nio/n8n:${N8N_VERSION}"
RUNNER_IMAGE="n8nio/runners:${N8N_VERSION}"

# Idempotência: remover o container antes de recriar (rodar 1x ou 10x dá o mesmo resultado).
remove_container() {
    docker rm -f "$1" >/dev/null 2>&1 || true
}

# Falha cedo se uma variável obrigatória estiver vazia ou ainda com placeholder do .env.example.
require_vars() {
    local v
    for v in "$@"; do
        if [[ -z "${!v:-}" || "${!v}" == GERE_* || "${!v}" == TROQUE_* ]]; then
            echo "ERRO: defina $v no .env (está vazio ou com placeholder)." >&2
            exit 1
        fi
    done
}

# Espera o healthcheck do Docker ficar "healthy" (Postgres/Redis).
wait_healthy() {
    local name="$1" tries="${2:-60}" status i
    for ((i = 0; i < tries; i++)); do
        status="$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo none)"
        [[ "$status" == healthy ]] && { echo "  ✔ $name healthy"; return 0; }
        sleep 2
    done
    echo "ERRO: $name não ficou healthy (último status: $status). Veja: docker logs $name" >&2
    return 1
}

# Espera um serviço n8n responder /healthz através do Traefik (roteado pelo header Host).
wait_http() {
    local host="$1" tries="${2:-90}" i
    for ((i = 0; i < tries; i++)); do
        if curl -sf -o /dev/null -H "Host: $host" http://127.0.0.1/healthz; then
            echo "  ✔ $host respondendo /healthz"
            return 0
        fi
        sleep 2
    done
    echo "ERRO: $host não respondeu /healthz. Veja os logs do container." >&2
    return 1
}
