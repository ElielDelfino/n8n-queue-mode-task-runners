# 4. Operação

## Status e logs

```bash
./scripts/status.sh
docker logs -f --tail 100 n8n-worker
docker stats --no-stream $(docker ps --filter network=n8n_net -q)
```

## Inspecionar o estado

```bash
# Postgres: tabelas, workflows e execuções
docker exec -it n8n-pgsql psql -U n8n -d n8n
#   \dt
#   SELECT id, name, active FROM workflow_entity;
#   SELECT id, status, "startedAt" FROM execution_entity ORDER BY id DESC LIMIT 10;

# Credentials estão cifradas (blob começa com U2FsdGVkX1 = "Salted__", AES):
#   SELECT name, type, left(data, 30) FROM credentials_entity;

# Redis: chaves da fila
docker exec n8n-redis redis-cli --scan --pattern 'bull:*' | head
```

## Recriar um serviço

Os processos n8n são stateless: recriar não perde nada.

```bash
./scripts/run-06-worker.sh      # remove e recria o worker
```

## Backup

Um backup tem **duas** partes, e uma não serve sem a outra:

```bash
# 1. dados
docker exec n8n-pgsql pg_dump -U n8n -d n8n --format=custom > backup-$(date +%F).dump

# 2. a chave que decifra as credentials desse dump
grep N8N_ENCRYPTION_KEY .env    # guardar em cofre de segredos, NUNCA junto do dump em local público
```

Restaurar:

```bash
docker exec -i n8n-pgsql pg_restore -U n8n -d n8n --clean --if-exists < backup-AAAA-MM-DD.dump
```

## Atualizar a versão do n8n

1. Leia o changelog / breaking changes da versão nova.
2. Faça **backup** (acima).
3. Altere `N8N_VERSION` no `.env`. Editor, worker, webhook e runner usam a mesma variável
   e **precisam** estar na mesma versão.
4. Recrie **o editor primeiro** (ele aplica as migrations novas) e espere o `/healthz`:

```bash
./scripts/run-05-n8n-editor.sh && docker logs -f n8n-editor
./scripts/run-06-worker.sh && ./scripts/run-07-runner.sh && ./scripts/run-08-webhook.sh
```

## Escalar workers

Cada peça escala de um jeito:

| Serviço | Replicável? | Observação |
|---------|-------------|------------|
| editor | ❌ (só 1) | múltiplos editores exigem o modo multi-main, que precisa de licença enterprise |
| webhook | ✅ | atrás do Traefik, que balanceia entre as réplicas |
| worker | ✅ | todos consomem a mesma fila do Redis |
| runner | ✅ | **vários runners podem se conectar ao mesmo worker** |
| Postgres / Redis | ❌ sem cluster próprio | são os pontos únicos a proteger (backup, recursos) |

O guia de referência recomenda **no mínimo 2 workers e 4 runners**. Exemplo de um segundo
worker (copie o `run-06` e troque):

| | Worker 1 | Worker 2 |
|---|---|---|
| `--name` | `n8n-worker` | `n8n-worker-2` |
| volume | `n8n-app/worker` | `n8n-app/worker-2` |

E runners extras (copie o `run-07`, troque `--name` e volume). Cada runner aponta, via
`N8N_RUNNERS_TASK_BROKER_URI`, para o worker que vai atendê-lo: `http://n8n-worker:5679`
ou `http://n8n-worker-2:5679`. Um worker sem nenhum runner conectado **não executa Code
nodes**, então distribua os runners para que todo worker tenha pelo menos um.

Não é preciso configurar nada no editor: os novos workers passam a consumir a mesma fila
do Redis. É a **escala horizontal** que o modo fila possibilita.

> Ajuste fino: `--concurrency` no comando do worker (`... n8n:VERSAO worker --concurrency=10`)
> define quantos jobs cada worker executa ao mesmo tempo.

## Desligar e limpar

```bash
./scripts/down.sh                       # remove containers, mantém dados e rede
docker network rm n8n_net               # remove a rede
sudo rm -rf ~/storage/n8n-*             # ⚠️ APAGA TODOS OS DADOS (workflows, credentials, execuções)
```
