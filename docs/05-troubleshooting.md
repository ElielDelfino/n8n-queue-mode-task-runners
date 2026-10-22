# 5. Troubleshooting

> Erros que eu realmente encontrei montando este stack. Cada um ensinou alguma coisa.

---

### `numerical result out of range` ao criar a rede

**Causa:** o nome da interface bridge (`-o com.docker.network.bridge.name=...`) tinha mais
de 15 caracteres.
**Lição:** no Linux, nome de interface de rede tem **no máximo 15 caracteres**. Por isso a
interface se chama `br-n8n-net`.

---

### Traefik responde 404 para tudo e não descobre os containers

**Causa:** o socket do Docker foi montado com caminho relativo/errado (`~/var/run/docker.sock`).
O Docker não reclama: cria uma **pasta vazia** no lugar e o Traefik fica sem fonte de dados.
**Lição:** em `-v`, use sempre caminho **absoluto** (`/var/run/docker.sock`). Origem
inexistente vira diretório vazio, em silêncio.
**Diagnóstico:** o dashboard (`http://127.0.0.1:8080/dashboard/`) mostra se as rotas
`n8n-editor` e `n8n-webhook` existem.

---

### Code node dá timeout de 60 s ao clicar em "Executar"

**Causa:** sem `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true`, a execução manual roda **no
editor**. O editor não tem runner conectado, então o Code node espera um runner que nunca chega.
**Correção:** a variável já está no `run-05-n8n-editor.sh`. Se removê-la, o erro volta.

---

### Runner não consegue conectar no worker

**Sintoma:** logs do `n8n-runner` com erro de conexão em `n8n-worker:5679`.
**Causa:** por padrão o broker escuta em `127.0.0.1`, que dentro do container do worker
significa "só eu mesmo".
**Correção:** `N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0` no worker (já está no script).
**Confira também:** se `N8N_RUNNERS_AUTH_TOKEN` é idêntico no worker e no runner.

---

### Webhook: `404` / `Cannot GET /webhook/...`

Quase sempre é um destes casos:

| Sintoma | Causa |
|---------|-------|
| 404 na URL de **produção** | workflow não está **publicado**; a rota só é registrada após publicar |
| 404 na URL de **teste** | não clicou em "Listen for test event" no editor |
| `Cannot GET` | mandou a URL de teste para o `ws.localhost` (ou o contrário). Teste = editor (`n8n.localhost/webhook-test/...`), produção = webhook (`ws.localhost/webhook/...`) |
| rota certa, host errado | `curl -H "Host: ..."` **reescreve** o destino que o Traefik usa para rotear |

---

### Credentials falham no worker (`Credentials could not be decrypted`)

**Causa:** `N8N_ENCRYPTION_KEY` diferente entre editor e worker, ou trocada depois de as
credentials terem sido salvas.
**Lição:** a chave precisa ser **igual** em todos os processos e **fixa**. Uma chave nova
não abre os blobs antigos. Se a original foi perdida, a única saída é recadastrar as
credentials.

---

### n8n não sobe: `EACCES: permission denied` em `/data`

**Causa:** a pasta do volume pertence a outro usuário. O n8n roda como UID 1000.
**Correção:** `sudo chown -R 1000:1000 ~/storage/n8n-app` (o `run-00-storage.sh` já faz
isso quando o seu UID não é 1000).

---

### Publish desabilitado / workflow não ativa

**Causa comum:** a tela está mostrando uma **execução** (execution view), não o workflow
editável. Clique em limpar a execução e volte ao modo de edição.
