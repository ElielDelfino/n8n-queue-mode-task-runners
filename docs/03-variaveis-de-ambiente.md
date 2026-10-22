# 3. Variáveis de ambiente

> Nos scripts, as variáveis estão agrupadas por **finalidade**. Os grupos se repetem
> entre os serviços. Entendendo os grupos, você entende os 4 scripts do n8n.

Legenda: **E** = editor · **W** = worker · **H** = webhook · **R** = runner

---

## Grupo 1: modo fila + Redis + Postgres (E, W, H)

| Variável | Valor | Por quê |
|----------|-------|---------|
| `EXECUTIONS_MODE` | `queue` | liga o modo fila; sem isso cada processo executa sozinho |
| `EXECUTIONS_TIMEOUT` | `1800` | mata execuções com mais de 30 min; nenhum workflow pendura para sempre |
| `QUEUE_BULL_REDIS_HOST` | `n8n-redis` | onde está a fila (resolvido pelo DNS da rede) |
| `DB_TYPE` | `postgresdb` | troca o SQLite padrão pelo Postgres |
| `DB_POSTGRESDB_HOST` | `n8n-pgsql` | host do banco |
| `DB_POSTGRESDB_DATABASE` / `_USER` / `_PASSWORD` | do `.env` | credenciais do banco |
| `N8N_METRICS` | `true` | expõe `/metrics` no formato Prometheus |

## Grupo 2: base de todo processo n8n (E, W, H)

| Variável | Valor | Por quê |
|----------|-------|---------|
| `N8N_ENCRYPTION_KEY` | do `.env` | cifra/decifra credentials; **igual** em E, W e H |
| `NODE_ENV` | `production` | otimizações de runtime do Node |
| `GENERIC_TIMEZONE` / `TZ` | `America/Sao_Paulo` | fuso dos Schedule Triggers / fuso do sistema |
| `N8N_DIAGNOSTICS_ENABLED` | `false` | sem telemetria |
| `N8N_USER_FOLDER` | `/data` | onde o n8n grava arquivos locais (volume) |

## Grupo 3: acesso web atrás do proxy (E, H)

| Variável | Valor | Por quê |
|----------|-------|---------|
| `N8N_HOST` | `n8n.localhost` / `ws.localhost` | domínio público do processo |
| `N8N_PROTOCOL` | `http` | local; em produção, `https` |
| `N8N_PROXY_HOPS` | `1` | há 1 proxy (Traefik) na frente: o n8n confia no `X-Forwarded-For` para saber o IP real |
| `N8N_SECURE_COOKIE` | `false` (só E) | cookie de sessão sem HTTPS; **em produção, `true`** |
| `N8N_EDITOR_BASE_URL` | `http://n8n.localhost/` (só E) | URL usada em links e e-mails |
| `WEBHOOK_URL` | `http://ws.localhost/` | faz a UI mostrar a URL de produção apontando para o container webhook |

## Grupo 4: task-runners (E, W)

| Variável | Valor | Por quê |
|----------|-------|---------|
| `N8N_RUNNERS_MODE` | `external` | o código roda num container separado, não num subprocesso interno |
| `N8N_RUNNERS_AUTH_TOKEN` | do `.env` | segredo compartilhado com o runner |
| `N8N_RUNNERS_BROKER_LISTEN_ADDRESS` | `0.0.0.0` (só W) | o padrão `127.0.0.1` só aceita conexões de dentro do próprio container |
| `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS` | `true` (só E) | execuções manuais vão para a fila e são executadas pelo worker, que tem runner |
| `EXECUTIONS_DATA_SAVE_ON_PROGRESS` | `true` | salva o progresso node a node (ajuda a depurar execuções que caíram) |
| `EXECUTIONS_DATA_SAVE_ON_SUCCESS` | `all` | guarda execuções bem-sucedidas (útil para estudar; em produção avalie o volume) |

## Grupo 5: exclusivas do editor (E)

| Variável | Valor | Por quê |
|----------|-------|---------|
| `N8N_VERSION_NOTIFICATIONS_ENABLED` | `false` | sem aviso de nova versão (a versão é pinada) |
| `N8N_VERSION_NOTIFICATIONS_WHATS_NEW_ENABLED` | `false` | idem |
| `N8N_PUBLIC_API_SWAGGERUI_DISABLED` | `true` | não expõe a UI de documentação da API pública |

## Runner (R)

| Variável | Valor | Por quê |
|----------|-------|---------|
| `N8N_RUNNERS_TASK_BROKER_URI` | `http://n8n-worker:5679` | onde está o broker (o worker) |
| `N8N_RUNNERS_AUTH_TOKEN` | do `.env` | prova que o runner é legítimo |
| `N8N_RUNNERS_MAX_CONCURRENCY` | `128` | tarefas de código simultâneas por runner |

> Repare no que o runner **não** tem: nada de `DB_*`, `QUEUE_*` ou `N8N_ENCRYPTION_KEY`.

---

## Flags do `docker run` que se repetem

| Flag | Por quê |
|------|---------|
| `--read-only` + `--tmpfs /tmp,/run` | sistema de arquivos imutável; só volumes e tmpfs aceitam escrita |
| `--cpus` / `--memory` / `--memory-swap` | teto de recursos; um serviço descontrolado não derruba a máquina |
| `--restart=always` | volta sozinho após crash ou reboot |
| `-h <nome>.intranet.br` | hostname interno legível nos logs |
| `--health-cmd` (pg/redis) | o Docker sabe quando o serviço está **pronto**, e não só iniciado |
