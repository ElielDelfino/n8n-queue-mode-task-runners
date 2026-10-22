# Fase 6 — Credentials + segurança

> Segredo não vive no workflow. Vive **trancado no Postgres**, e a chave que destranca
> vive **fora do banco**, no `.env`. O workflow só carrega o **ID** — uma referência,
> nunca o segredo.

---

## 1. O tripé — o que mora em cada lugar

| Lugar | O que fica lá | Legível? |
|-------|---------------|----------|
| **Postgres** (tabela `credentials_entity`) | o segredo **criptografado** (blob AES) | não — cofre fechado |
| **`.env`** → containers (`-e` na subida) | a `N8N_ENCRYPTION_KEY` (a chave do cofre) | sim — por isso `.env` é gitignored |
| **Workflow** (`.json`) | só `id` + `name` da credential | sim, mas não é segredo |

⚠️ **Erro que eu cometi (de novo o crachá):** achei que a chave ficava no Postgres
"pra os containers conversarem". Dois erros num só:
1. Cadeado e chave na **mesma gaveta** não protegem nada — a chave fica **fora** do banco.
2. Containers não usam essa chave pra falar entre si (isso é senha de Redis/Postgres).
   Ela serve pra **destrancar o que se lê do banco** — e todos recebem a **mesma** chave
   porque todos leem os **mesmos blobs**.

## 2. Experimento do blob (ver pra crer)

Criei uma credential **Header Auth** (`X-Api-Key` = `teste-123`, fake) e fui olhar
como o Postgres guardava:

```bash
source .env && docker exec n8n-pgsql psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -c "SELECT id, name, type, data FROM credentials_entity;"
```

O `data` veio assim: `U2FsdGVkX19U5Dpj...` — um blob ilegível. Nem `teste-123` nem
`X-Api-Key` aparecem: **o Postgres nunca viu meu segredo em texto puro**. O editor
trancou com a chave *antes* de gravar.

Curiosidade de quem entende: todo blob de credential do n8n começa com `U2FsdGVkX1` —
é base64 de `Salted__`, assinatura do formato AES da lib CryptoJS.

## 3. Runtime — quem destranca (e quem NÃO)

Quem **executa o workflow** é quem destranca: o **worker** (produção) ou o
**main/editor** (execução manual de teste). No meu experimento foi o editor.

⚠️ **Meu erro da sessão:** disse que quem destrancava era o *runner*. Não — o
**task-runner só roda código do node Code** (JS/PY isolado); credential é assunto de
quem roda o workflow. Regra pra fixar: *runner roda código meu; worker roda o workflow.*

🎯 **Menor privilégio na prática** (e meu stack prova): nos scripts, a
`N8N_ENCRYPTION_KEY` entra no editor (`run-05`), no worker (`run-06`) e no webhook
(`run-08`) — o **runner (`run-07`) não recebe a chave**. Ele não precisa dela,
então não a tem. Se o runner for comprometido, o cofre continua fechado.

## 4. Export — o famoso "depende" ⚠️

No `.json` exportado, o node carrega só isto:

```json
"credentials": {
  "httpHeaderAuth": { "id": "V15ddINZGk75gyXC", "name": "Header Auth account" }
}
```

Nada de blob, nada de `teste-123`. Mas exportar pro git é seguro? **Depende** —
e eu caí na pegadinha respondendo "sim, pois só sai o ID":

- O que passou pelas **Credentials** → sai como ID. Seguro. ✅
- Mas o n8n **não sabe o que é segredo num campo livre**: Bearer fixo num header,
  token em query (`?token=abc123`), valor colado à mão num Set — tudo isso vai em
  **texto puro** pro export.

Moral: *a ferramenta protege o caminho padrão; ela não audita o que eu espalhei.*
Sempre **auditar o `.json` antes de commitar** procurando Bearer fixo, token em query
e valores colados à mão.

## 5. Perda da chave 🎯 (pergunta clássica de entrevista)

Perdemos a `N8N_ENCRYPTION_KEY`, banco intacto: os blobs continuam lá, íntegros —
e **ilegíveis pra sempre**. Criar uma chave nova **não recupera nada** (ela só serve
daqui pra frente, pra segredos recadastrados). Único remédio: **recadastrar todos os
segredos na mão**. Trabalho manual e custoso em produção → **a chave entra no backup
com o mesmo carinho que o dump do banco**.

## 6. External Secrets (a versão enterprise)

Pra não depender do cofre interno, o n8n (enterprise) integra com cofres externos —
HashiCorp Vault, AWS Secrets Manager etc.: os segredos vivem lá e o n8n busca na hora.
O mecanismo base (chave + banco) é o que toda vaga espera que eu domine primeiro.

## 7. O que montei (marco da fase)

`Manual → HTTP Request "Ecoar meus headers"` — GET `https://httpbin.org/headers`,
Authentication = Generic Credential Type → Header Auth → minha credential.

O httpbin devolveu meus headers de volta e lá estava `"X-Api-Key": "teste-123"` —
injetado pelo n8n **em runtime**, sem eu nunca digitar o segredo no node. O node só
conhece o ID. Export salvo em `workflows/testar-credential-ecoar-headers.json`.

Detalhe que ficou de lição: deixei a credential com nome default
("Header Auth account"). A regra de renomear node vale pra credential também —
em produção são dezenas ("API CRM produção", "Slack bot marketing").

## 8. Explique com minhas palavras (teste de fluência)

1. Onde o n8n guarda as credentials e como protege?
   > Tripé: blob AES no Postgres, chave no `.env` (injetada nos containers),
   > workflow só com o ID.

2. Perdemos a encryption key, banco intacto. Estrago e remédio?
   > Blobs ilegíveis pra sempre; chave nova não recupera nada; recadastrar tudo
   > na mão. Por isso a chave entra no backup junto com o dump.

3. Exportar workflow pro git é seguro?
   > Depende: o que passou pelas Credentials sai como ID (seguro), mas o n8n não
   > adivinha segredo em campo livre — Bearer fixo, token em query, valor colado
   > à mão vazam. Auditar o `.json` antes de commitar.

4. Quem destranca a credential em runtime?
   > Quem executa o workflow: worker (produção) ou main (teste manual). O task-runner
   > não — só roda código do Code node e nem recebe a chave (menor privilégio).

## 🔖 Reflexão — leia ao voltar aos estudos

**O que a fase realmente ensinou** (além de "criar credential"): segurança é saber
**onde cada coisa mora e quem consegue ler**. O n8n protege bem o caminho padrão —
mas só o caminho padrão. O "depende" do export é o resumo da fase: a ferramenta não
substitui a auditoria humana.

**Meu padrão de erro (vigiar):** de novo borrei fronteiras entre vizinhos. A chave
virou "crachá de comunicação" de novo (é cadeado!), o runner virou "quem destranca"
(é o worker!), e no export eu confiei na ferramenta sem enxergar o limite dela.
Pergunta-antídoto: *"isso vale pra tudo, ou só pro caminho padrão?"*

**O fio com as fases anteriores:** a arquitetura da Fase 0 agora explica segurança —
cada serviço do compose recebe **só o que precisa** (runner sem chave = menor
privilégio). E o node HTTP da Fase 3 é justamente **onde** a credential é usada:
o header que eu configurava à mão agora vem do cofre.

**Próximo marco:** Fase 7 — **Error handling + retries**. A fase que separa workflow
de demo de workflow de produção: o que acontece quando a API do outro lado cai?
