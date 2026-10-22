# 2. Passo a passo: subindo serviço por serviço

> Rode **um script por vez** e faça a verificação de cada etapa antes de seguir.
> Se algo quebrar, você sabe exatamente qual peça foi.

---

## Pré-requisitos

- Linux ou WSL2 com **Docker 24+** (`docker version`)
- `curl` e `openssl`
- Porta **80** livre (`sudo ss -ltnp | grep ':80 '` não deve retornar nada)

## Passo 0: configurar o `.env`

```bash
cp .env.example .env
openssl rand -hex 32    # rode 3 vezes: um valor para cada segredo
```

Cole os valores em `POSTGRES_PASSWORD`, `N8N_ENCRYPTION_KEY` e `N8N_RUNNERS_AUTH_TOKEN`.

> ⚠️ Nunca commite o `.env`. Os scripts recusam rodar enquanto houver `GERE_*` ou `TROQUE_*` nele.
> Guarde a `N8N_ENCRYPTION_KEY` num lugar seguro **fora** do servidor: sem ela, um backup
> do banco não recupera nenhuma credential.

---

## Passo 1: storage e rede

```bash
./scripts/run-00-storage.sh
./scripts/run-01-network.sh
```

**O que acontece:** cria as pastas de dados em `$STORAGE_DIR` (padrão `~/storage`) e a
rede `n8n_net` (subnet `10.250.0.0/16`).

**Verifique:**

```bash
docker network inspect n8n_net --format '{{json .IPAM.Config}}'
ls ~/storage
```

---

## Passo 2: Traefik (porta de entrada)

```bash
./scripts/run-02-traefik.sh
```

**O que acontece:** sobe o proxy reverso na porta 80. Ele lê o socket do Docker e cria
rotas automaticamente para todo container com a label `traefik.enable=true`.

**Verifique:** abra http://127.0.0.1:8080/dashboard/. Ainda não haverá rotas para o n8n.

---

## Passo 3: PostgreSQL

```bash
./scripts/run-03-postgresql.sh
```

**Verifique** (espere `healthy`):

```bash
docker inspect -f '{{.State.Health.Status}}' n8n-pgsql
docker exec -it n8n-pgsql psql -U n8n -d n8n -c '\dt'   # vazio por enquanto
```

> Repare que o script **não tem `-p 5432:5432`**: o banco só é alcançável por dentro da rede.

---

## Passo 4: Redis

```bash
./scripts/run-04-redis.sh
```

**Verifique:**

```bash
docker exec n8n-redis redis-cli ping     # PONG
```

---

## Passo 5: Editor

```bash
./scripts/run-05-n8n-editor.sh
docker logs -f n8n-editor                # Ctrl+C para sair
```

**O que acontece:** na primeira vez, o editor roda as **migrations**, ou seja, cria as
tabelas no Postgres. As migrations são idempotentes: o n8n registra o que já aplicou na
tabela `migrations` e, nas próximas vezes, só aplica o que falta.

**Verifique:**

```bash
curl -s http://n8n.localhost/healthz     # {"status":"ok"}
docker exec -it n8n-pgsql psql -U n8n -d n8n -c '\dt'   # agora cheio de tabelas
```

Abra **http://n8n.localhost** e crie o usuário owner.

> Ainda **não** execute workflows: sem worker, nada consome a fila.

---

## Passo 6: Worker

```bash
./scripts/run-06-worker.sh
docker logs -f n8n-worker
```

**O que acontece:** o worker se conecta ao Redis para consumir jobs e abre o **broker**
de task-runners na porta 5679 (só dentro da rede).

**Teste:** no editor, crie `Manual Trigger → Edit Fields` e clique em **Executar**.
Deve funcionar, porque a execução manual foi para a fila e o worker a executou.

---

## Passo 7: Task-runner

```bash
./scripts/run-07-runner.sh
docker logs -f n8n-runner
```

**Teste (o marco do setup):** adicione um **Code node** depois do trigger:

```js
return [{ json: { ok: true, rodouEm: 'task-runner', agora: new Date().toISOString() } }];
```

Clique em **Executar**. Se aparecer o item com `ok: true`, o caminho
`editor → Redis → worker → runner` está funcionando de ponta a ponta.

> 💡 Experimento que vale fazer: `docker stop n8n-runner` e execute de novo. O Code node
> falha, mas worker e editor continuam de pé. É o isolamento na prática. Depois,
> `docker start n8n-runner`.

---

## Passo 8: Webhook

```bash
./scripts/run-08-webhook.sh
```

**Teste:**

1. Crie um workflow `Webhook (GET, path: ola) → Edit Fields`.
2. **Publique** o workflow (no n8n 2.x a URL de produção só é registrada após publicar).
3. Dispare:

```bash
curl -s "http://ws.localhost/webhook/ola?nome=Teste"
```

4. Veja a execução em **Executions** no editor.

> ⚠️ **Test URL × Production URL**
> - `http://n8n.localhost/webhook-test/ola`: atendida pelo **editor**, só enquanto você
>   clica em "Listen for test event". Aparece no canvas.
> - `http://ws.localhost/webhook/ola`: atendida pelo **container webhook**, só com o
>   workflow publicado. Aparece só em Executions.

---

## Pronto 🎉

```bash
./scripts/status.sh
```

Você tem os 7 containers de pé, cada um com um papel. Para entender cada `-e` dos scripts,
siga para [Variáveis de ambiente](03-variaveis-de-ambiente.md).
