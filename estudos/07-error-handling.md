# Fase 7 — Error handling + retries

> Em produção, **falha não é exceção — é rotina** (API fora, rate limit, timeout).
> Profissional não evita falha: **decide de antemão o que acontece quando ela vier**.
> O pior desfecho não é o erro vermelho — é o **erro silencioso**.

---

## 1. As 3 camadas de error handling

Truque pra nunca confundir (meu tropeço da fase): perguntar **"onde eu configuro isso?"**
— a resposta diz a camada. Camada ≠ ferramenta: a camada node tem DUAS ferramentas.

| Camada | Onde configuro | Ferramentas |
|--------|----------------|-------------|
| **1. Node** | aba Settings do node | Retry On Fail **+** On Error |
| **2. Workflow** | Workflow Settings (`⋯` do canvas) | Error Workflow (o plantonista) |
| **3. Design** | na cabeça, antes de montar | idempotência, validação de payload, timeout |

### Camada 1a — Retry On Fail

Configuro Max Tries + Wait Between Tries. **Retry compra tempo, não compra correção**:
- **429 Rate Limit** ("pediu rápido demais") → o tempo resolve → retry com espera é o tratamento certo.
- **401 credencial inválida** → o tempo não muda a chave → retry só martela a porta errada.
  ⚠️ Pior: excesso de tentativas falhas pode **bloquear a credencial** — eu estaria sabotando.
  O tratamento do 401 é **falhar rápido** (sem retry), alertar via plantonista, e um humano corrigir.

### Camada 1b — On Error (o destino quando o node desiste)

| Opção | O que faz | Quando usar |
|-------|-----------|-------------|
| **Stop Workflow** (default) | execução morre ali, vermelha | quando sem esse dado nada adiante faz sentido |
| **Continue (regular output)** | erro sai pela saída normal, **fantasiado de dado** | ⚠️ quase nunca — é a fábrica de erro silencioso |
| **Continue (error output)** | node ganha **segunda saída** só pra falhas | o profissional: a falha vira **ramo**, não morte |

O item que sai pela saída de erro vem recheado: `error.message`, `name` (AxiosError),
`code`, `status`, `stack` — matéria-prima de log e alerta (⚠️ cuidado ao logar o `stack`
inteiro: pode carregar URL/headers — regra do seguranca.md de não logar payload inteiro).

### Camada 2 — Error Workflow (o plantonista)

Workflow separado que começa com **Error Trigger**; configuro nos **Workflow Settings**
de cada workflow qual plantonista ele usa. Quando o workflow morre, o n8n chama o
plantonista com o boletim de óbito: `workflow.name` (quem), `execution.error.message`
(por quê), `execution.lastNodeExecuted` (onde — economiza metade do debug),
`execution.url` (link direto pro corpo), `mode`, `retryOf`. Um Edit Fields formata
isso num alerta de gente grande.

### Camada 3 — Design

O que nenhum checkbox resolve: **idempotência** (seção 6), **validação de payload**
(IF checando campos obrigatórios antes de processar — irmão do `{erro: true}` da Fase 3)
e **timeout** (Workflow Settings → Timeout Workflow, pra execução travada não pendurar).

## 2. Taxonomia do erro (3 níveis)

| Nível | O que acontece | Exemplo | Tem status code? |
|-------|---------------|---------|------------------|
| **Transporte** | requisição não completa | DNS não resolve, timeout, conexão recusada | **não** — ninguém respondeu |
| **HTTP** | servidor responde com erro | 500, 503, 404, 429 | sim, 4xx/5xx |
| **Lógica** | servidor responde "sucesso" com conteúdo ruim | ViaCEP: 200 + `{erro: true}` | sim, 200 |

⚠️ Caí nessa na prática: recebi um 503 e disse que era "erro de rede/DNS". A prova de
que não era estava na minha mão: **se chegou status code, alguém respondeu** — a viagem
completou. Erro de transporte não tem número, só silêncio.

## 3. Transiente × Determinístico

- **Transiente**: resolve sozinho com o tempo (503 sobrecarga, timeout, 429) → retry ajuda.
- **Determinístico**: vai falhar igual em todas as tentativas (404, 401, URL errada) →
  retry só adiciona latência ao fracasso — e no 401 pode piorar (bloqueio).

🎯 Regra de bolso pra entrevista: *retry compra tempo, não compra correção.*

## 4. O erro silencioso (vi na pele)

Selecionei sem querer **Continue (regular output)** em vez de **(error output)** — os
nomes são quase iguais. Resultado: workflow **verde**, "funcionou"... e o item que saiu
era um **500 fantasiado de dado**. Se houvesse um node "criar fatura" adiante, ele
processaria o erro como se fosse pedido de verdade. Ninguém fica vermelho, ninguém
avisa, o estrago segue rio abaixo. **É o pior tipo de falha** — e a razão de a opção
do meio quase nunca ser a certa.

## 5. O que montei (marco da fase): plantonista de ponta a ponta

- **`Laboratorio de Falhas`**: Webhook (GET `falha-teste`) → HTTP Request `Chamar API
  instável` (GET `httpbin.org/status/500`, On Error = Stop Workflow).
- **`Plantão de Erros`**: Error Trigger → Edit Fields `Formatar alerta`.
- Liguei os dois em Workflow Settings → Error Workflow, **publiquei ambos** e disparei
  com curl na URL **de produção** (`ws.localhost`, lição da Fase 2).

A cadeia completa que a execução percorreu (Fases 0 + 2 + 7 na mesma jogada):

```
curl → container webhook → fila no Redis → worker executa → 500 → morte não tratada
     → n8n aciona o Error Workflow → Error Trigger recebe o boletim real
```

O curl respondeu `{"message":"Workflow was started"}` **antes** do workflow falhar —
🎯 pegadinha de entrevista: webhook 200 = "entrou na fila", **não** "funcionou".

**As 3 regras do plantonista:**
1. Só falha **não tratada** aciona (meu workflow com error output terminava verde → não acionaria).
2. Só execução de **produção** aciona (teste manual no editor não chama o plantonista).
3. Na minha versão do n8n (modelo **Publish**), o plantonista precisa estar **publicado** —
   descobri pelo ⚠ no dropdown ("Not published... must be published before running in production").

## 6. Idempotência 🎯 (a pergunta temida)

**Conceito:** executar a operação 2+ vezes com o mesmo input produz o **mesmo efeito**
que executá-la uma vez (botão de elevador: 5 apertos = 1 chamada).

**Por que é assunto de error handling:** todo mecanismo de recuperação **cria repetição** —
retry re-executa, webhook reenvia evento, humano re-roda execução falha. Falha e
repetição andam juntas.

**O caso da fatura dupla:** webhook "pedido pago" chega 2x → 2 faturas. O defeito:
**workflow não tem memória entre execuções** — a exec 2 não sabe da exec 1 (podem até
rodar em workers diferentes!). O "já fiz isso?" precisa consultar **estado persistido
fora do workflow**, usando uma **chave de idempotência** (`pedido_id`):

```
Webhook → HTTP "Buscar fatura por pedido_id" → IF "já existe?"
            ├─ true  → encerra (loga "duplicado ignorado")
            └─ false → HTTP "Criar fatura"
```

**Nível sênior da resposta:** consultar→criar tem **janela de corrida** — se as duas
execuções chegam juntas, ambas consultam, ambas não acham, ambas criam. Solução:
empurrar a garantia pro **destino**: constraint UNIQUE sobre `pedido_id`, upsert em
vez de insert, ou API com header `Idempotency-Key` (Stripe). Regra de bolso:
**o IF mitiga; a garantia atômica no destino resolve.**

## 7. Explique com minhas palavras (teste de fluência)

1. Como você trata erro em n8n?
   > Em 3 camadas: node (Retry On Fail + On Error), workflow (Error Workflow com
   > Error Trigger) e design (idempotência, validação, timeout). Resposta boa passeia
   > pelas três.

2. Retry num 429 e num 401 — mesmo tratamento?
   > Opostos. 429 é transiente (o tempo resolve) → retry com espera. 401 é
   > determinístico (o tempo não muda a chave) → falhar rápido + alertar + humano
   > corrigir; retry pode até bloquear a credencial.

3. Por que o Error Workflow não disparou quando eu usava "Continue using error output"?
   > Porque falha tratada não é falha: o workflow terminava verde. O plantonista só
   > é chamado por morte não tratada — e só em execução de produção.

4. O que é idempotência e como aplicar num webhook de pagamento?
   > Rodar 2x com o mesmo input = efeito de 1x. Workflow não tem memória entre
   > execuções, então uso chave de idempotência (`pedido_id`) consultando estado
   > persistido; o robusto é garantia atômica no destino (UNIQUE/upsert/Idempotency-Key).

## 🔖 Reflexão — leia ao voltar aos estudos

**O que a fase realmente ensinou** (além dos checkboxes): erro não se "evita", se
**desenha**. As camadas 1 e 2 são configuração; a que separa candidato de profissional
é a 3, que não tem checkbox — é pensar "e se rodar duas vezes?" antes de montar. E o
inimigo número 1 não é o vermelho, é o **verde mentiroso**.

**Meu padrão de erro (vigiar — de novo fronteiras):** (a) transformei "3 camadas" em
"3 ferramentas" — Retry e On Error moram na MESMA camada (mesma aba Settings); antídoto:
*"onde eu configuro?"*. (b) Regredi no 429×401 dizendo que tinham "a mesma resposta" —
transiente e determinístico pedem tratamentos **opostos**. (c) Chamei um 503 de erro de
rede — status code é prova de que o servidor respondeu.

**O fio com as fases anteriores:** o `{erro: true}` da Fase 3 era o nível "lógica" da
taxonomia sem eu saber; o IF da Fase 4 é a ferramenta da validação e da idempotência;
o modo fila da Fase 0 explica por que o curl recebe "started" antes da falha — e por
que exec 1 e exec 2 podem nem estar no mesmo worker.

**Próximo marco:** Fase 8 — **Sub-workflows + boas práticas**: quebrar fluxo grande em
partes reutilizáveis com Execute Workflow. Rumo ao projeto de portfólio (Fase 9).
