# Security policy

## Reporting

Report suspected vulnerabilities privately using GitHub private vulnerability reporting:

<https://github.com/martinlofranodeoliveira/byte-corpus-suffix-index/security/advisories/new>

Do not include real personal data, credentials or private corpora. Prefer a minimal synthetic manifest, exact Lua/dependency versions, the command used and the observed failure. Avoid public disclosure of an exploitable issue before private discussion. No response-time SLA is promised.

General contact is through the official homepage: <https://lofranotecnologia.com.br>.

## Scope

Development version 0.1.0 is the documented code line. It is not a production-readiness or support-lifetime claim. Relevant issues include input validation bypasses, cross-document matches, falsely complete capped listings, decoder boundary mistakes, diagnostics disclosing corpus data and unexpected file access.

The core performs no I/O or networking. The CLI reads an explicitly selected manifest and writes stdout/stderr; it does not discover files or execute manifest expressions. Public dependency preparation is the only network-enabled tool and verifies the fixed official source hash before use.

Run code and dependency preparation in trusted owned directories. A hostile Lua search path, `debug`, arbitrary same-VM code, concurrent mutation during construction, operating-system compromise and replaced runtime files are not sandboxed by the index. Metatables cannot enforce such a sandbox. Logical limits are not memory, disk or CPU quotas; apply external isolation for untrusted workloads.

Consumers must check CLI exit status. A partial output stream after an I/O failure is not a success receipt. No successful output can be inferred merely from a prefix of JSON.

## Português

Relate vulnerabilidades de forma privada pelo endereço GitHub acima, usando exemplos sintéticos e sem segredos ou dados pessoais. Não há SLA de resposta. Contato geral é pelo site oficial. A versão de desenvolvimento 0.1.0 não alega prontidão para produção. Metatables não isolam código Lua arbitrário, e limites de entrada não substituem cotas do sistema operacional. Verifique sempre o código de saída da CLI.
