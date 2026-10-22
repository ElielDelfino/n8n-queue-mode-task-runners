# Fase 3 — HTTP Request + Set + Expressions

> A virada: até aqui o dado **vinha** até mim (webhook). Agora **eu busco** dado
> num serviço externo e o **remodelo**. HTTP Request é o node mais usado em produção.

---

## 1. HTTP Request — o canivete suíço

Faz uma chamada HTTP a qualquer API e traz a resposta pra esteira como item data.

**Recebe (config):** Method (`GET` buscar / `POST` enviar), URL, e opcionais
(headers, query, body, auth).
**Emite:** a resposta já embrulhada como `{ json: {...} }`.

**Quando NÃO usar:** se existe node dedicado do serviço (Slack, Google Sheets, ...),
prefira ele — já traz auth e tratamento prontos. HTTP Request é pro que não tem
node próprio ou quando quero controle total.

**Regra de ouro vale aqui:** chegam 3 items → **3 chamadas**, uma por caixa.
Dá pra usar o dado de cada caixa na URL: `https://api/user/{{ $json.id }}`.
⚠️ Pegadinha de entrevista: achar que faz 1 chamada e tomar rate-limit por fazer N.

## 2. O que montei

`Manual → HTTP Request "Buscar endereço por CEP" → Edit Fields "Remodelar endereço"`

API pública sem auth: **ViaCEP** — `https://viacep.com.br/ws/01001000/json/`
(retorna endereço a partir de um CEP; sem chave, pra não mexer com credentials — isso é Fase 6).

## 3. Lição de ouro: "HTTP 200 ≠ sucesso lógico" 🎯

Chutei um CEP inválido (`57000000`). A API respondeu:
```json
{ "erro": "true" }
```
com **status HTTP 200** → o node **não** ficou vermelho, mas o conteúdo era um erro.

> **"Deu 200" não significa "deu certo".** Muitas APIs devolvem status de sucesso
> com um corpo dizendo "não encontrei/falhou". Confiar cego no status HTTP = processar lixo.

Conecta com a regra do projeto (validar payload antes de processar). O tratamento
disso (IF checando `{{ $json.erro }}`) é Fase 7 (error handling).

Diagnóstico que usei: `docker exec n8n-editor sh -c "wget -qO- <url>"` — confirmou
que a rede estava ok e o "erro" vinha da própria API, não do Docker.

## 4. Remodelar com Set (trabalho do profissional)

API devolve muitos campos; o profissional **enxuga** pra deixar só o que o resto
do fluxo precisa. Dado limpo = fluxo legível e barato.

No node Edit Fields "Remodelar endereço":
- **"Include Other Input Fields" = OFF** → emite **só** os campos que declaro;
  descarta o resto. (Se ON, faz *merge*: mantém tudo que veio **e** adiciona os novos → caixa inchada.)
- Também renomeei campos (API → negócio): `logradouro`→`rua`, `localidade`→`cidade`.

| Campo novo | Valor |
|-----------|-------|
| `cep` | `{{ $json.cep }}` |
| `rua` | `{{ $json.logradouro }}` |
| `cidade` | `{{ $json.localidade }}` |
| `uf` | `{{ $json.uf }}` |

> Hábito profissional: o dado que sai de um node deve ser **exatamente** o que o
> próximo precisa — nem mais (polui/vaza), nem menos.

## 5. Explique com minhas palavras (teste de fluência)

1. Quando usar HTTP Request e quando NÃO usar?
   > Uso pra chamar API sem node dedicado / quando quero controle total. Não uso
   > se existe node próprio do serviço (já traz auth e tratamento).

2. Chegam 5 items num HTTP Request. Quantas chamadas? Risco?
   > 5 chamadas, uma por item. Risco de rate-limit se eu não esperava isso.

3. A API respondeu HTTP 200 mas com `{ "erro": "true" }`. O node falha? Perigo?
   > Não falha (status é 200). Perigo: seguir processando um resultado que na
   > verdade é um erro lógico. Preciso validar o corpo, não só o status.

4. Por que desligar "Include Other Input Fields" para enxugar?
   > Ligado ele mantém todos os campos de entrada e ainda soma os novos. Desligado
   > emite só os que declaro → caixa enxuta.
