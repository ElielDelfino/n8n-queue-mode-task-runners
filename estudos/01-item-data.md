# Fase 1 — Anatomia de um workflow + item data

> O fundamento do n8n. Se eu entendo item data, a maioria dos bugs deixa de me pegar.
> Pergunta clássica de entrevista.

---

## 1. O modelo mental — esteira de fábrica 🏭

- A **esteira** = um **array de items** → `[ {…}, {…}, {…} ]`
- Cada **item** = uma **caixa** (a unidade que anda na esteira)
- Cada **node** = uma **estação** na esteira

## 2. Anatomia de UM item

Todo item tem no máximo **duas prateleiras de nome fixo**:

```json
{
  "json":   { ...dados estruturados... },   // sempre existe
  "binary": { ...arquivos, se houver... }   // só quando há arquivo
}
```

- `json` → onde mexo 99% do tempo. Dentro dele cabe o que eu quiser
  (vários campos, objetos aninhados, listas).
- `binary` → arquivos crus (PDF, imagem, planilha).
- **Não** crio prateleiras soltas no item (tipo "cliente"). A riqueza mora
  **dentro** do `json`, não em prateleiras novas.

**Dois eixos independentes:**

| Eixo | O que varia |
|------|-------------|
| Quantos **items** na esteira | quantas caixas andam (uma por registro) |
| O que tem dentro do **`json`** | quão rico é o dado de cada caixa |

## 3. A regra de ouro (a que reprova candidato) ⚠️

> **Um node roda uma vez POR item.**

Chegam 3 items num HTTP Request → ele dispara **3 chamadas**. Eu **não** faço
o loop; o **n8n loopa por fora** e vai trocando qual caixa é a "atual".

E o pulo do gato das expressions:

> A cada execução, `$json` **re-aponta pra caixa daquela volta**.
> `$json.nome` escrito 1 vez → 3 resultados (Ana, Bruno, Carla), um por passada.

## 4. Ler o painel de execução

Abas do painel de saída de um node:

- **Table** → uma **linha = um item** (caixa); as **colunas = os campos** do `json`.
- **JSON** → mostra o **conteúdo do `json` já desembrulhado** (esconde a embalagem
  `json` e o array pra não poluir). A embalagem **não some** — só não é exibida.
- **Schema** → a árvore/hierarquia dos campos; deixa a estrutura explícita.

**A pegadinha que confunde todo iniciante:**

> No **painel** vejo o conteúdo do `json` desembrulhado (sem a palavra `json`).
> Mas na **expression** preciso escrever `$json.campo` — porque internamente a
> caixa sempre tem a prateleira `json`. Descompasso "o que vejo" × "o que escrevo".

Prova de que a prateleira existe: `{{ $json.nome }}` retorna `Ana`. Se `json`
não fosse uma prateleira, eu não precisaria do `$json.` antes.

## 5. O que fiz na prática

1. Node **Edit Fields (Set)** montando 1 caixa (`nome`, `email`) → vi 1 item no painel.
2. Descobri que o painel esconde o `json`; provei com `{{ $json.nome }}` → `Ana`.
3. Node **Code** gerando 3 items (aqui escrevi a embalagem `{ json: {...} }` na mão,
   porque no Code monto a esteira crua sem a UI desembrulhar).
4. Node **Edit Fields "Montar saudação"** com `{{ "Olá " + $json.nome }}` →
   rodou 3 vezes, gerou "Olá Ana / Olá Bruno / Olá Carla". Vi a regra de ouro ao vivo.

## 6. Explique com minhas palavras (teste de fluência)

1. Diferença entre um **item** e o campo **`json`** dentro dele?
   > O item é a caixa inteira (unidade da esteira). O `json` é uma prateleira
   > de nome fixo **dentro** do item, ao lado do `binary`. `json` não é o item.

2. Chegam **5 items** num HTTP Request. Quantas requisições e por quê?
   > 5 — uma por item. O n8n roda o node uma vez por caixa automaticamente.

3. Na aba Table, o que é uma **linha** e o que é uma **coluna**?
   > Linha = um item (caixa). Coluna = um campo do `json` daquela caixa.

4. Por que `{{ $json.email }}` vira vários valores com a esteira cheia?
   > Porque o node roda uma vez por item e `$json` re-aponta pra caixa da volta
   > atual — pega o email do item daquela execução.
