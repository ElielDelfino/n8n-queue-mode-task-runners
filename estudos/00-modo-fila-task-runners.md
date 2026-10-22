# Fase 0 — n8n em modo fila com task-runners (setup local)

> Nota de referência da sessão em que subi o ambiente do zero. A última seção
> ("Explique com minhas palavras") é pra eu preencher — é o teste real de fluência.

---

## 1. Os 3 modos de execução do n8n

| Modo | Como funciona | Quando usar |
|------|---------------|-------------|
| **1. Simples (main / SQLite)** | tudo num processo só, dados num arquivo SQLite | testar, aprender, aula. **Nunca em produção** — um workflow pesado ou em loop derruba tudo, até o editor |
| **2. Fila (queue)** | separa em editor + worker + webhook; comunicação via **Redis** (fila pub/sub) + **PostgreSQL** (dados). Escala horizontal (vários workers) | produção |
| **3. Fila + task-runners** | igual ao 2, mas a **execução de código do usuário (node Code JS/PY)** roda num serviço isolado (task-runner) | produção mais segura — **é o que eu uso** |

**Por que o modo 3 existe:** o node Code (código do usuário) é a maior fonte de travamento.
No modo 2, um Code bugado trava o worker, e quando outro worker pega o mesmo job, trava também
(efeito cascata). Isolando o código no task-runner, se ele travar, **só ele cai** — o worker sobrevive.

---

## 2. Os serviços (7 containers)

| Serviço | Imagem | Papel | Web? |
|---------|--------|-------|------|
| **traefik-app** | traefik | proxy reverso: roteia por domínio (n8n.localhost / ws.localhost) | entrada 80 |
| **n8n-pgsql** | pgvector/pgvector:pg18 | fonte da verdade (workflows, credentials cifradas, execuções, login) | não |
| **n8n-redis** | redis | fila pub/sub + cache | não |
| **n8n-editor** | n8nio/n8n | admin/UI, dispara triggers | n8n.localhost |
| **n8n-webhook** | n8nio/n8n `webhook` | recebe gatilhos HTTP e **enfileira** (não executa) | ws.localhost |
| **n8n-worker** | n8nio/n8n `worker` | pega job da fila e **executa** node a node | não |
| **n8n-runner** | n8nio/runners | **sandbox** de código JS/PY | não |

> A mesma imagem `n8nio/n8n` vira editor, worker ou webhook — o que muda é o **command** no final.
> O runner é a exceção: imagem própria (`n8nio/runners`).

---

## 3. O caminho de uma execução

```
Produção (webhook):
  curl → Traefik (ws.localhost) → n8n-webhook → Redis (fila) → n8n-worker → [node Code? → n8n-runner] → Postgres

Manual (botão "Executar"):
  editor → (com OFFLOAD=true) Redis → worker → runner → Postgres
```

- **Redis é o carteiro**: editor/webhook só **enfileiram** o job; um worker ocioso pega.
- **Postgres é a verdade**: guarda o que precisa sobreviver a restart.
- **Claim Check Pattern**: dado pesado vai pro Postgres; pelo Redis só trafega o "sinal" leve
  "job X pronto, vá buscar".

---

## 4. Conceitos-chave (perguntas de entrevista)

- **DNS interno de rede user-defined**: containers se acham por **nome** só numa rede própria
  (`n8n_net`); a bridge default só resolve por IP. Por isso `QUEUE_BULL_REDIS_HOST=n8n-redis` funciona.
- **Stateless**: containers da app são descartáveis; o estado vive no Postgres/Redis. Posso matar e
  recriar o editor/worker sem perder nada. É o que permite ter vários workers iguais.
- **N8N_ENCRYPTION_KEY**: cifra as credentials no Postgres. Tem que ser **igual** em editor/worker/webhook,
  e **fixa** (no `.env`) pra sobreviver a recriações — senão não decifra as credentials antigas.
- **Menor privilégio**:
  - Postgres/Redis não têm `-p` nem label do Traefik → só alcançáveis por dentro da rede.
  - O **runner não tem** chave de banco, nem Redis, nem encryption key → é o código menos confiável,
    recebe só o mínimo (INPUT do node) do worker.
- **Idempotência**: `docker rm -f` no início dos scripts; as migrations do n8n checam a tabela
  `migrations` e só aplicam o que falta → rodar 1x ou 100x dá o mesmo resultado.
- **Onde cada execução roda**: produção (webhook/schedule) → sempre no worker. Manual → no editor por
  padrão; com `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true` vai pro worker (recomendado/futuro).

---

## 5. Bugs que resolvi (e o que ensinaram)

| Bug | Causa | Lição |
|-----|-------|-------|
| `numerical result out of range` ao criar rede | nome de interface bridge > 15 chars | nome de interface no Linux ≤ 15 chars |
| Traefik com 404, não descobria containers | socket montado com caminho errado (`~/var/run/...` virou pasta vazia) | `-v` sempre com caminho **absoluto**; origem inexistente vira pasta vazia (sem erro) |
| Editor "não achava" o runner (timeout 60s) | execução manual roda no main, que não tinha runner | faltava `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true` |
| Worker não recebia o runner | broker escutando só em 127.0.0.1 | `N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0` |

---

## 6. As 3 formas de executar um workflow

1. **Manual** (botão "Executar fluxo de trabalho") — testar rápido.
2. **Test URL** do webhook (`/webhook-test/...`) — só com "Listen for test event"; aparece no canvas.
3. **Production URL** (`/webhook/...`) — workflow **Publicado/Ativo**; roda no worker; aparece só em Execuções.

---

## 7. Comandos úteis

```bash
# subir cada serviço
bash run-01-network...  ... run-08-webhook.sh

# ver status
docker ps --filter name=n8n- --format '{{.Names}} · {{.Status}}'

# logs
docker logs -f n8n-worker

# entrar no banco
docker exec -it n8n-pgsql psql -U n8n -d n8n   # \dt lista tabelas, \q sai

# testar webhook de produção (workflow publicado)
curl -s -H "Host: ws.localhost" http://localhost/webhook/meu-teste

# dono numérico de pasta (volume)
ls -ldn <pasta>     # ou: stat -c '%u:%g %n' <pasta>
```

---

## 8. Explique com minhas palavras (PREENCHER — teste de fluência)

> Respondo isto sem olhar as seções acima. Se travar, é sinal do que revisar.

1. Por que o modo 3 (task-runners) é mais seguro que o modo 2? 
Por que os runner rodão isoladamente e se caso aconteça algum bug no codigo o worker nao entra em loop e falha. Desacomplamos para que nao tenha problemas em cascata. 
2. Qual a diferença entre matar o **container** do Postgres e apagar o **volume** dele? 
Matar o container é apenas matar o conteudo do conteiner que são efemeros, assim que deixamos um volume é para persistir os dados.
3. Por que o Postgres não tem `-p` nem label do Traefik? 
Por que ele resolve por dns, como estão na mesma network nao é preciso portas para eles se comunicarem, entra conceito menor previlegio
4. Onde roda uma execução **manual** vs uma de **produção**? O que muda com o `OFFLOAD`? _(...)_
Uma execução manual editor->redis->worker->task-runner->postgres, execução manual sem offload editor->task-runner->postgres e a de produção curl->traefik(ws.host/)->webhook->redis->worker->runner->postgres.
5. Por que o `N8N_ENCRYPTION_KEY` precisa ser igual e fixa em todos os serviços? 
- A N8N_ENCRYPTION_KEY serve para cifrar e decifrar as credentials (API keys, senhas) que ficam guardadas no Postgres.
Por que igual em todos: o editor cifra uma credential com essa chave e salva no banco; depois o worker lê do banco e precisa decifrar para usar. Se as chaves forem diferentes, o worker lê lixo → falha. 
Fixar no .env para que nao gere uma nova chave a cada container recriado. 
6. Por que o task-runner NÃO recebe as credenciais do banco? _(...)_
- Por que task-runner é para rodar os codigos e ele nao depende do banco. Quem precisa conversar com o banco sao os outros serviços do n8n . Menor priveligio. É o codigo menos confiavel. 