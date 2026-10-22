# Workflows de exemplo

Para importar: no editor, **Workflows → Import from file**.

| Arquivo | O que demonstra |
|---------|-----------------|
| `teste-credential-header-auth.json` | HTTP Request usando uma credential **Header Auth** contra `httpbin.org/headers`. O header é injetado em runtime, e o export carrega só o **ID** da credential, nunca o segredo. |

> Ao importar, a credential referenciada não existe na sua instância. Crie uma Header Auth
> (ex.: `X-Api-Key` = `valor-de-teste`) e selecione-a no node.
