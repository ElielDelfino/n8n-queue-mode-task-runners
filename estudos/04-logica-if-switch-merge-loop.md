# Fase 4 — Lógica: IF, Switch, Merge, Loop

> Nodes de lógica **bifurcam** e **reúnem** a esteira. Até aqui ela era uma linha
> reta; agora o fluxo **escolhe** por onde cada caixa segue.

---

## 1. IF — o "sim/não" (2 saídas)

Avalia uma condição e **distribui** cada item em duas saídas:
- **true** (cima) → items que passaram
- **false** (baixo) → items que não passaram

Analogia: inspetor no fim da esteira que empurra cada caixa pra esquerda/direita.

**Regra de ouro de novo:** roda 1x por item. Ele **não para** o fluxo — **separa**.
Chegam 5 caixas → avalia as 5 e reparte entre `true`/`false`.

Config: `valor A` — operador — `valor B`. Ex.: `{{ $json.idade }}` **>= (Number)** `18`.

**Onde brilha (entrevista) 🎯** — validar o `{ erro: true }` da Fase 3:
```
HTTP Request → IF (erro é true?)
                 ├─ true  → avisar "CEP inválido"
                 └─ false → seguir processando
```

## 2. Merge — juntar caminhos

Se o IF bifurca, o Merge reúne (duas esteiras viram uma). Tem **2 entradas**
(input 1 e input 2). Modos:

| Modo | O que faz | Analogia |
|------|-----------|----------|
| **Append** | empilha input 1 e depois input 2 | juntar duas pilhas |
| **Combine** | casa items por chave/posição, funde campos | grampear folha A com a B |
| **SQL Query** | junta com lógica de query | JOIN |

Pra reunir os dois lados de um IF → **Append** (só quero a lista completa de volta).

## 3. Switch — o IF de várias saídas (3+)

IF só tem 2 saídas. Pra 3, 4, N caminhos → **Switch**: várias regras, cada uma
com sua saída. Ex.: rotear por UF (`SP`/`RJ`/`AL`/default).

Analogia: IF = bifurcação (2); Switch = rotatória (N saídas).
**Regra de bolso:** 2 caminhos → IF; 3+ → Switch (empilhar IFs fica ilegível).

## 4. Loop (Split in Batches) — a maior pegadinha ⚠️

O n8n **já itera** items automaticamente (node roda 1x por item). Então o Loop
**NÃO** existe pra "repetir" — existe pra processar em **lotes (batches)**, de N em N.

**Preciso de Loop quando:**
- API aceita no máx X registros por chamada → mando de X em X.
- Quero pausa entre grupos pra não tomar rate-limit.
- Preciso acumular resultado a cada rodada.

**NÃO preciso quando:** "quero 1 HTTP Request por item" → o HTTP já roda 1x por
item sozinho. Enfiar Loop aí é redundante e mais lento.

> Pergunta clássica de entrevista: *"o n8n já faz o loop; o node Loop é só pra lotear."*

## 5. O que montei (marco da fase: ramificar + juntar)

`Manual → Code "Gerar 4 pessoas" → IF "É maior de idade?" (idade >= 18)`
- `true`  → Edit Fields "Marcar maior" (`status=maior`, **Include Other ON**)
- `false` → Edit Fields "Marcar menor" (`status=menor`, **Include Other ON**)
- ambos → **Merge (Append)**: `true`→input 1, `false`→input 2 → 4 items de volta, cada um com `status`.

Aqui "Include Other **ON**" (preservar `nome`/`idade` e **acrescentar** `status`) —
oposto da Fase 3, onde era OFF pra enxugar.

## 6. Explique com minhas palavras (teste de fluência)

1. IF x Switch — quando cada um?
   > 2 caminhos → IF; 3+ → Switch. Empilhar IFs fica ilegível.

2. Tenho 50 items, 1 chamada HTTP por item. Preciso de Loop? Por quê?
   > Não. O n8n já itera; o HTTP Request roda 50x sozinho.

3. Tenho 50 items, a API só aceita 10 por requisição. Preciso de Loop? Por quê?
   > Sim — pra lotear em batches de 10 e não estourar o limite da API.

4. O IF "para" o fluxo quando um item reprova na condição?
   > Não. Ele separa: reprovados vão pra saída `false`, aprovados pra `true`.
