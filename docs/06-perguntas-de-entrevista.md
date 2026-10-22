# 6. Perguntas de entrevista

> O que este setup ensina, no formato em que costuma ser cobrado.
> Tente responder antes de abrir a resposta.

---

<details>
<summary><b>1. Quais os modos de execução do n8n e qual você usaria em produção?</b></summary>

Simples (processo único + SQLite), fila (editor/worker/webhook com Redis + Postgres) e fila
com task-runners. Em produção, fila, de preferência com task-runners: isola falhas,
permite escalar workers horizontalmente e tira a execução de código do usuário de dentro
do worker.
</details>

<details>
<summary><b>2. Qual problema o task-runner resolve que o modo fila sozinho não resolve?</b></summary>

O efeito cascata do Code node. Sem runner, um código bugado trava o worker; o job volta
para a fila, outro worker pega e trava também. Com o runner, o código roda num processo
separado: se ele cair, falha só aquele node e o worker sobrevive.
</details>

<details>
<summary><b>3. Para que servem o Redis e o Postgres nessa arquitetura? Eles conversam entre si?</b></summary>

Redis é a fila e o barramento de eventos: editor e webhook enfileiram, workers consomem.
Postgres é a fonte da verdade: workflows, credentials, execuções. Eles **não** conversam
entre si; são os processos n8n que falam com os dois. Pelo Redis passa só o sinal leve
(claim check); o dado pesado fica no Postgres.
</details>

<details>
<summary><b>4. Por que existe um container só para webhooks?</b></summary>

Para isolar o tráfego HTTP de entrada. Um pico de webhooks não deixa o editor lento, e o
container webhook pode escalar separadamente. Ele não executa nada: recebe, enfileira e
responde.
</details>

<details>
<summary><b>5. Onde roda uma execução manual e uma de produção?</b></summary>

Produção (webhook, schedule): sempre no worker, via fila. Manual: por padrão no editor;
com `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true`, também vai para a fila e roda no worker.
Com task-runners externos, o offload é obrigatório, porque o editor não tem runner.
</details>

<details>
<summary><b>6. O que é a <code>N8N_ENCRYPTION_KEY</code> e o que acontece se ela for perdida?</b></summary>

É a chave que cifra as credentials salvas no Postgres. Precisa ser igual em todos os
processos n8n (um cifra, outro decifra) e fixa. Se for perdida, o banco continua
intacto, mas as credentials viram blobs ilegíveis. Gerar uma chave nova não recupera
nada; é preciso recadastrar todas. Por isso ela faz parte do backup, guardada separada do dump.
</details>

<details>
<summary><b>7. Exportei um workflow. Ele é seguro para subir no GitHub?</b></summary>

Depende. Credentials configuradas pelo sistema de Credentials saem só como **ID + nome**,
o que é seguro. Mas o n8n não sabe o que é segredo num campo livre: Bearer fixo num header,
token na query string ou valor colado num Edit Fields vão em texto puro. Sempre audite o
`.json` antes de commitar.
</details>

<details>
<summary><b>8. Como você escalaria esse ambiente?</b></summary>

Adicionando workers, que passam a consumir a mesma fila sem mudar nada no editor, e
runners (vários podem atender o mesmo worker; todo worker precisa de pelo menos um).
O editor não escala sem licença multi-main. Ajustando `--concurrency` por worker. Escalando o container webhook
atrás do proxy se a entrada HTTP for o gargalo. Postgres e Redis viram os pontos a cuidar
(conexões, réplica, persistência).
</details>

<details>
<summary><b>9. Por que dá para apagar e recriar o container do worker sem perder nada?</b></summary>

Porque os processos n8n são stateless: o estado vive no Postgres (e transitoriamente no
Redis). Container é descartável; volume, não. Apagar o volume do Postgres apaga tudo.
</details>

<details>
<summary><b>10. Que práticas de segurança esse setup aplica?</b></summary>

Menor privilégio (banco e Redis sem porta publicada; runner sem senha de banco nem
encryption key), segredos fora do código (`.env` gitignored, validação de placeholder),
containers read-only com limite de recursos, versões pinadas. O que faltaria em produção:
HTTPS, senha no Redis, dashboard do Traefik protegido, backup automatizado.
</details>

<details>
<summary><b>11. Por que <code>N8N_PROXY_HOPS=1</code>?</b></summary>

Porque há um proxy (Traefik) na frente. Sem isso, o n8n veria o IP do Traefik como origem
de toda requisição. Com isso, ele confia no `X-Forwarded-For` de um salto e enxerga o IP
real do cliente, o que importa para logs e rate limiting.
</details>
