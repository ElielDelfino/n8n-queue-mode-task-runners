# Fase 2 — Triggers (Manual, Schedule, Webhook)

> O trigger é o node que decide **quando** o workflow acorda. Todo workflow tem
> exatamente **um** trigger, no começo da esteira. Sem trigger, o fluxo nunca
> dispara sozinho.

---

## 1. Os 3 triggers que importam

| Trigger | Acorda quando... | Analogia | Uso |
|---------|------------------|----------|-----|
| **Manual** | clico "Execute workflow" | apertar o play na mão | só teste; **nunca** em produção |
| **Schedule** | chega a hora marcada | despertador ("todo dia 8h") | automação por **tempo** |
| **Webhook** | chega uma requisição HTTP externa | campainha (alguém toca) | automação por **evento externo** |

Webhook é o mais poderoso e o mais cobrado em entrevista.

## 2. Webhook no meu stack (modo fila) — a parte que importa

Divisão de quem atende cada tipo de webhook:

| Tipo | Path | Quem atende | Host |
|------|------|-------------|------|
| **Teste** | `/webhook-test/...` | **editor (main)** | `n8n.localhost` |
| **Produção** | `/webhook/...` | container **`n8n-webhook`** | `ws.localhost` |

- O **teste** roda no **editor** porque precisa **mostrar o payload no canvas**
  (o canvas vive no editor). Ele só escuta **uma** requisição, e só **depois**
  de clicar **"Listen for test event"** — a orelha fecha após cada disparo.
- A **produção** roda no container webhook → enfileira no Redis → **worker** executa.
  Não aparece no canvas, só em Execuções.

## 3. Bug que resolvi (e o que ensinou) ⚠️

`curl` respondia **"Cannot GET /webhook-test/..."** e a esteira não acendia.

- **Erro 1:** mandei o teste pro host de produção (`ws.localhost` = webhook container).
  O container webhook **não** conhece rotas `/webhook-test/` → "Cannot GET".
- **Erro 2 (o sútil):** deixei `-H "Host: ws.localhost"` no curl. O **Traefik roteia
  pelo header `Host`**, não pela URL. Esse header reescrevia o destino pro container
  errado mesmo com a URL escrita como `n8n.localhost`.

**Correto:**
```bash
curl "http://n8n.localhost/webhook-test/meu-primeiro-webhook"
```
Sem `-H`, com o host do editor → Traefik entrega pro editor → esteira acende. ✅

**Lição:** teste vai no editor, produção vai no webhook container. E no Traefik
quem manda no roteamento é o header `Host`.

## 4. Ler o payload de um Webhook

O webhook organiza a requisição HTTP em prateleiras dentro do `json`:

| Prateleira | O que traz |
|------------|-----------|
| `headers` | cabeçalhos (User-Agent, Host, ...) |
| `query` | o que vem depois do `?` na URL (`?nome=Ana`) |
| `body` | corpo da requisição (POST/PUT; GET simples vem vazio) |
| `params` | parâmetros de rota |

Testado: `curl ".../meu-primeiro-webhook?nome=Ana&cidade=Maceio"` → `nome` e
`cidade` caíram em **`query`**.

## 5. Puxar dado do payload (liga com a Fase 1)

Node Edit Fields depois do webhook, campo expression:
```
{{ "Olá " + $json.query.nome }}   →  "Olá Ana"
```

**Por que `$json.query.nome` e não `$json.nome`?**
Porque o `nome` está **dentro** da prateleira `query`, não solto na raiz do `json`.
O caminho tem que atravessar a camada: `$json` → `query` → `nome`. Escrever
`$json.nome` procuraria um campo inexistente → `undefined`.

> Hábito de ouro: **ler a estrutura no painel (JSON/Schema) antes de escrever a
> expression** — evita 90% dos "por que veio undefined?".

## 6. Explique com minhas palavras (teste de fluência)

1. Por que todo workflow precisa de um trigger?
   > É o que faz o fluxo acordar. Sem ele o workflow fica inerte, não dispara sozinho.

2. Diferença de quando Schedule × Webhook acordam?
   > Schedule = tempo (horário/intervalo agendado). Webhook = evento externo
   > (uma requisição HTTP chega).

3. No meu stack, quem recebe um webhook de produção e quem executa?
   > Recebe: container `n8n-webhook` (via Traefik, `ws.localhost`). Executa: `n8n-worker`.

4. Por que o teste deu "Cannot GET" quando mandei pro `ws.localhost`?
   > Porque o webhook de teste é registrado no editor (main), não no container
   > webhook. Teste vai em `n8n.localhost`; produção em `ws.localhost`.
