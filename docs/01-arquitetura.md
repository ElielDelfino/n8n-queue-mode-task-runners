# 1. Arquitetura

> Ideia central: **separar quem recebe, quem executa e quem guarda**, para que a falha
> de uma peça não derrube as outras e para que cada peça possa escalar sozinha.

---

## 1.1 Os 3 modos de execução do n8n

### Modo 1: simples (main + SQLite)

Um único processo faz tudo: serve a UI, recebe webhooks, executa workflows e grava num
arquivo SQLite.

- ✅ Sobe com um comando. Ótimo para aprender.
- ❌ Um workflow que aloca muita memória ou entra em loop derruba o processo, **inclusive o editor**.
- ❌ Não escala: não dá para ter dois processos usando o mesmo SQLite.

### Modo 2: fila (queue mode)

O n8n se divide em **papéis**, que se comunicam por **Redis** (fila/eventos) e
**PostgreSQL** (dados):

| Papel | O que faz |
|-------|-----------|
| **Editor (main)** | UI, administração, edição e testes. Dispara triggers de agenda. |
| **Webhook** | Servidor HTTP dos gatilhos de produção. Recebe e **enfileira**. |
| **Worker** | Pega jobs da fila e **executa** os nodes. Pode haver vários. |

Os papéis podem estar em máquinas diferentes, desde que alcancem Redis e Postgres.

### Modo 3: fila + task-runners (este repositório)

O modo 2 ainda tem uma fragilidade: o **Code node** executa código JS/Python escrito pelo
usuário **dentro do worker**. Código bugado trava o worker e, quando outro worker pega
o mesmo job, trava esse também (**efeito cascata**).

A solução é **isolar a execução do código do usuário** num serviço próprio, o
**task-runner**:

1. O worker chega num Code node.
2. Envia ao runner só o necessário: o código, o INPUT do node e as variáveis do workflow.
3. O runner executa e devolve o resultado.
4. Se o runner travar ou estourar memória, **só aquele node falha**. O worker continua.

O runner tem dois modos (`N8N_RUNNERS_MODE`):

| | `internal` | `external` (este repo) |
|---|---|---|
| Onde roda | processo filho dentro do worker | container separado |
| Vantagem | simples, rápido | isolado, seguro, resiliente |
| Custo | código abusivo derruba o container inteiro; **Python não funciona** | latência extra (o guia de referência fala em até ~3 s por execução com código) |

> O trade-off é **performance × isolamento**. Este repo escolhe isolamento, que é a direção
> que o próprio n8n v2 tomou.

---

## 1.2 O caminho de uma execução

**Produção (webhook):**

```
curl ──► Traefik (Host: ws.localhost) ──► n8n-webhook ──► Redis (job na fila)
                                                              │
                     Postgres ◄── resultado ── n8n-worker ◄───┘
                                                   │
                                     Code node? ──► n8n-runner
```

**Manual (botão "Executar" no editor):**

```
editor ──(OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true)──► Redis ──► worker ──► runner
```

> ⚠️ Sem `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true`, a execução manual roda **no editor**,
> que não tem runner conectado, e todo Code node dá timeout. É o erro mais comum desse setup.

### Quem faz o quê com os dados

- **Redis é o carteiro.** Por ele passa só o sinal leve ("job 123 pronto, vá buscar").
- **Postgres é a fonte da verdade.** Workflows, execuções e credentials ficam lá. Tudo que
  precisa sobreviver a um restart está no Postgres.
- Isso é o **Claim Check Pattern**: a mensagem carrega um "tíquete", e o conteúdo pesado
  fica guardado num lugar durável.

> Redis e Postgres **não conversam entre si**. São dois depósitos de estado independentes,
> e quem fala com os dois são os processos n8n.

---

## 1.3 Rede e DNS interno

Todos os containers estão na rede bridge `n8n_net`. Numa rede **definida pelo usuário**,
o Docker oferece DNS interno: um container encontra o outro pelo nome (`n8n-redis`,
`n8n-pgsql`). Na bridge padrão do Docker isso não acontece; só funciona por IP.

Consequência: Postgres e Redis **não precisam publicar porta** (`-p`). Ninguém de fora da
rede chega neles.

---

## 1.4 Quem recebe qual segredo (menor privilégio)

| Serviço | `POSTGRES_PASSWORD` | `N8N_ENCRYPTION_KEY` | `N8N_RUNNERS_AUTH_TOKEN` | Acessível de fora |
|---------|:---:|:---:|:---:|---|
| editor | ✅ | ✅ | ✅ | `n8n.localhost` |
| webhook | ✅ | ✅ | ❌ | `ws.localhost` |
| worker | ✅ | ✅ | ✅ | não |
| **runner** | ❌ | ❌ | ✅ | não |

O runner executa o código **menos confiável** do sistema, então recebe o mínimo: só o
token para provar ao worker que é legítimo. Mesmo que um código malicioso rode lá, ele
não tem como ler o banco nem decifrar credentials.

### Os três segredos, sem confundir

| Segredo | Protege | Se vazar | Se perder |
|---------|---------|----------|-----------|
| `POSTGRES_PASSWORD` | acesso ao banco | quem está na rede lê/escreve o banco | troca no banco e nos serviços |
| `N8N_ENCRYPTION_KEY` | **as credentials salvas** (API keys, senhas), cifradas no Postgres | com um dump do banco, dá para decifrar tudo | **as credentials salvas viram lixo**; é preciso recadastrar todas |
| `N8N_RUNNERS_AUTH_TOKEN` | o aperto de mão worker ↔ runner | um processo falso poderia se registrar como runner | só gerar outro e reiniciar worker + runner |

> 🎯 A `N8N_ENCRYPTION_KEY` **não** é uma senha de comunicação entre containers. Ela é o
> cadeado das credentials. Precisa ser igual em editor, worker e webhook porque um cifra e
> os outros decifram. E precisa ser fixa (no `.env`), porque uma chave nova não abre os
> blobs antigos.

---

## 1.5 Stateless: por que dá para destruir containers

Editor, worker, webhook e runner **não guardam estado próprio**. Tudo vive no Postgres
(e, transitoriamente, no Redis). Por isso:

- `docker rm -f n8n-worker && ./scripts/run-06-worker.sh` não perde nada.
- Dá para ter **10 workers idênticos** consumindo a mesma fila.
- Atualizar versão = recriar containers com outra imagem.

Já **apagar o volume** do Postgres (`$STORAGE_DIR/n8n-pgsql`) apaga tudo de verdade.
Container é descartável; volume, não.
