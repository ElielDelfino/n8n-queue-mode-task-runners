# Fase 5 — Code node (JS): Run Once for All Items x Run Once for Each Item

> O Code node é a **saída de emergência**: quando nenhum node pronto resolve, eu
> escrevo o JS. Poderoso e perigoso — é o único node que me deixa ver a esteira
> **inteira** de uma vez, e o único que pode travar o ambiente.

---

## 1. Run Once for All Items — o "array de inputs" (padrão)

Roda **1 vez só**, recebendo a esteira inteira.

```js
const items = $input.all();          // array com TODOS os items
const idades = items.map(i => i.json.idade);   // [30, 16, 25, 33]
const total  = items.length;         // 4
```

- `$input.all()` → array de items. Daqui pra frente é **JS puro**, o n8n saiu de cena.
- `.map()` faz sentido aqui **porque é array**.
- `.length` me dá a contagem de items.

**Quebra de padrão ⚠️** — este modo **viola** a regra "node roda 1x por item" (Fase 1).
É o único node que enxerga a esteira toda. Por isso serve pra **agregar**: somar,
média, agrupar, deduplicar, reordenar (N → 1).

## 2. Run Once for Each Item — "objeto normal"

Roda **1 vez por item**. O n8n **já fez o loop** — eu recebo só a caixa da vez.

```js
const idade = $input.item.json.idade;        // valor direto, sem array
const tudo  = { ...$input.item.json };       // spread: copia todos os campos
```

- `$input.item` → **um** item. **`.all()` não existe aqui.**
- **Spread (`...$input.item.json`)** → copia os campos que já vieram, pra eu
  **acrescentar** em vez de **substituir**. Sem ele, o item perde `nome`/`idade`.
- Ordem no spread: o **último a falar vence** (`{...json, faixa: x}` → `faixa` novo ganha).

## 3. O contrato de saída — onde 90% dos bugs moram ⚠️

O formato do retorno **muda entre os modos**. Errar aqui = node rejeita ou item some.

| Modo | Retorno | Exemplo |
|------|---------|---------|
| **All Items** | array de items | `return [{ json: { media: 26 } }];` |
| **Each Item** | um item, **sem** array | `return { json: { nome: "Eliel" } };` |

As 3 camadas do All Items:
- `[ ]` → n8n só fala em **esteira**; mesmo 1 item vai dentro de array.
- `{ json: }` → a **prateleira fixa** (Fase 1). Sem ela o node rejeita.
- o conteúdo → o que o painel mostra.

**O `.json` volta a aparecer 👀** — o painel *esconde* o wrapper, mas dentro do Code
node eu estou **do lado de dentro da esteira**: `item.json.idade`, nunca `item.idade`
(que devolve `undefined` → soma vira `NaN`).

**Todo caminho precisa retornar um item.** `if` sem `else` → retorna `undefined` →
o item some ou o node quebra. E `return []` faz o ramo inteiro morrer **em silêncio**.

## 4. Por que o Code node roda no task-runner (meu stack) 🎯

O código do Code node é **meu**, não é node nativo testado pela n8n — logo é a maior
fonte de bug e travamento (loop infinito, estouro de memória).

Por isso o worker **não executa** o código: ele manda pro `n8n-runner`, que roda o JS
**isolado** e devolve o resultado. Se o meu código travar, **quem morre é o runner**,
não o worker — a falha fica contida no node Code e o ambiente é preservado.

> É a razão de existir do modo 3 (fila + task-runners). Ver `00-modo-fila-task-runners.md`.

## 5. Quando NÃO usar Code node — meu próprio exemplo (14/07/2026)

Usei Code node pra criar o campo `faixa` ("adulto"/"menor"). **Não precisava** — um
**Edit Fields** nativo resolvia em 1 node:

```
Edit Fields
  faixa   Expression   {{ $json.idade >= 18 ? "adulto" : "menor" }}
```

Mesmo ternário, sem código. **Régua:** antes de abrir o Code node, perguntar
*"dá pra fazer com Edit Fields + expression?"*. Se der, faz.

E **IF não servia** aqui: IF **separa**, não classifica (Fase 4). Ele mandaria adultos
pra `true` e menores pra `false` sem criar campo nenhum — eu precisaria de
IF → 2x Edit Fields → Merge = **4 nodes** pro que 1 fez.

**Quando o Code node é legítimo:** `Calcular média` — agregar **N → 1** nenhum node
pronto faz.

> **Red flag em entrevista 🎯:** workflow todo em Code node não é workflow, é script
> disfarçado. Joga fora legibilidade no canvas, retry por node e o painel item a item.

## 6. Fixed x Expression (aprendi tropeçando)

- **Fixed** → valor que **não depende de nada**. `nome = Eliel`. Digita e pronto.
- **Expression** `{{ }}` → valor que **depende** de algo (outro campo, `$now`, cálculo).

Expression é sempre **leitura** ("qual valor?"), nunca atribuição. `{{ $json = "Eliel" }}`
não existe — quem atribui é o próprio Edit Fields, na linha `nome = ...`.

> Vício de iniciante: ligar Expression em tudo "por segurança". Fixed é mais legível
> e não quebra.

## 7. O que montei (marco da fase: N→1 e 1→1)

`Manual → Code "Gerar pessoas" (All Items) → Code "Classificar faixa" (Each Item) → Code "Calcular média" (All Items)`

- **Gerar pessoas** → cria 4 items (`nome`, `idade`: 30, 16, 25, 33). Treino do contrato.
- **Classificar faixa** (Each Item) → 4 entram, **4 saem**, agora com `faixa`. Spread preserva o resto.
- **Calcular média** (All Items) → 4 entram, **1 sai**: `mediaIdade: 26`, `totalPessoas: 4`.

```js
// Calcular média — Code porque agregação N→1 não tem node pronto.
const items = $input.all();

if (items.length === 0) {
  return [{ json: { mediaIdade: null, totalPessoas: 0 } }];
}

const soma = items.reduce((acc, i) => acc + i.json.idade, 0);
return [{
  json: {
    mediaIdade: Number((soma / items.length).toFixed(1)),
    totalPessoas: items.length,
  }
}];
```

**Detalhes que valem ouro:**
- **Guarda do vazio:** sem o `if`, `soma / 0` = `NaN` — e o JS **não reclama**. O `NaN`
  viaja fingindo ser número e explode 3 nodes depois, longe da causa. `null` é honesto
  ("não havia o que calcular"); `0` seria mentira (0 é média válida).
- `reduce(..., 0)` → a semente `0` não é decoração: sem ela, array vazio **estoura exceção**.
- `.toFixed(1)` devolve **string** (`"26.0"`) → `Number()` traz de volta. String vazando
  onde devia ter número quebra `IF` de "maior que" (compara texto!).
- `totalPessoas` de brinde: média sem tamanho de amostra esconde informação
  (média 23 de 2 pessoas ≠ de 200).

## 8. Erros que cometi (e o modelo mental por trás)

| Erro | Modelo mental errado | Certo |
|------|----------------------|-------|
| `item.map()` no Each Item | achei que sempre recebo array | Each Item me dá **1 caixa**. `.map` é de array. O n8n **já fez o loop** — iterar dentro seria loop dentro de loop (mesmo erro do Loop, Fase 4, com outra roupa) |
| `if (idade >= 18 ? "adulto" : "menor")` | tratei o ternário como **condição** | Ternário **produz um valor**. `"adulto"` e `"menor"` são **truthy** → o `if` era **sempre verdadeiro**. Ele **substitui** o `if`, não mora dentro |
| `faixa: idade` | consequência do erro acima | Gastei o ternário no `if`, sobrou o número cru. `faixa: idade >= 18 ? "adulto" : "menor"` |
| retornar só `{ faixa }` | achei que Code **completa** o item | Code **substitui**. Sem spread, `nome`/`idade` somem → `Calcular média` acha `undefined` → `NaN` |
| `5 items = 5 requisições HTTP` | colei "1x por item" só ao HTTP Request | Vale pra **todo** node: HTTP, Set, IF, Code |

> **`if` x ternário:** `if` decide **SE** algo acontece. Ternário decide **QUAL valor**.
> Eu queria a segunda coisa o tempo todo.

## 9. Explique com minhas palavras (teste de fluência)

1. Estou em Each Item. `$input.all()` funciona?
   > Não. Nesse modo recebo **1 item** (`$input.item`). `.all()` só existe no All Items.

2. Por que `return { nome: "Eliel" }` quebra o Code node?
   > Falta o wrapper `{ json: }` — e, no modo All Items, falta também o array.

3. Meu Code node trava em loop infinito. Quem morre?
   > O **task-runner** (`n8n-runner`). O worker é preservado — é pra isso que ele existe.

4. Quero adicionar 1 campo calculado a cada item. Code ou Edit Fields?
   > **Edit Fields** + Expression. Code só quando node pronto não resolve (ex.: agregar N→1).

5. Chegam 4 items num Code em All Items que retorna `[{json:{media:26}}]`. Quantos saem?
   > **1**. Agregação colapsa a esteira — só o Code node faz isso.

---

## 🔖 Reflexão — leia ao voltar aos estudos

**O que a Fase 5 realmente ensinou:** não foi "como escrever JS no n8n". Foi **quando
não escrever**. Eu vi os dois lados na mesma sessão — o `faixa` que devia ter sido
Edit Fields, e o `Calcular média` que só o Code resolvia. A régua ficou: *node pronto
primeiro; Code quando não tem*.

**Meu padrão de erro (vale vigiar):** eu domino a **mecânica** (o que acontece), mas as
**fronteiras entre conceitos vizinhos borram**. Aconteceu na Fase 2 (teste/produção/
offload/Traefik viraram uma coisa só) e de novo aqui (`.map` do All Items vazando pro
Each Item; ternário ocupando o lugar do `if`). O antídoto é sempre o mesmo: **parar e
perguntar "esse conceito vale nos DOIS lados ou só num?"**.

**O fio que atravessa tudo até agora:** o `json`. Fase 1 ele estava escondido pelo
painel; Fase 3 eu remodelei em volta dele; aqui ele **reapareceu na cara** — porque no
Code node eu estou do lado de dentro da esteira. Se um dia der `undefined` ou `NaN`,
a primeira suspeita é ele.

**Próximo marco:** Fase 6 — **Credentials + segurança**. Configurar uma credencial e
explicar **onde** ela é guardada (dica: a `N8N_ENCRYPTION_KEY` do meu compose é o
**cadeado** das credentials — não é crachá de comunicação entre serviços).
