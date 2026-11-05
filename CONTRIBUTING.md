# Contributing

This project is maintained as original open-source software by Lofrano Tecnologia. General information and contact are available at <https://lofranotecnologia.com.br>.

Use Lua 5.4 and Linux for the complete test suite. Python 3 is used only to prepare the verified dkjson dependency:

```sh
python3 tools/prepare_dependency.py
lua5.4 test/run.lua
lua5.4 bin/byte_corpus_index.lua demo --assert
lua5.4 bin/byte_corpus_index.lua demo --assert --json
```

After preparation, tests must remain offline. `LUA_BIN` can select the Lua executable for process tests. Do not commit `build/dependencies`, `build/install`, downloaded sources, generated rocks, credentials or personal data.

Changes should preserve the documented development version 0.1.0 contract or explicitly update it. Include a regression that would fail without the fix. Keep the independent oracle separate from production search/construction helpers; a shared mistake must not become its own expected result. Use only synthetic fixtures. Explain algorithmic and allocation implications of any new input or result bound.

Keep diagnostics free of corpus contents, manifest paths and raw decoder exceptions. Test validation before allocation and listing caps before collection. Do not weaken real deleted-file or `/dev/full` checks into mocked success assertions. Preserve copied-output and private-state tests.

Keep authored code original. Do not contribute private client code, downloaded dependency bodies, unsupported compliance statements, invented adoption evidence or benchmark claims without reproducible measurements. Document limitations in English and Portuguese. Follow `.editorconfig` and retain MIT notices.

This repository has no publish, release or remote-deployment workflow. Dependency changes require official provenance, a verified hash, retained license and tests of the exact APIs used. A version string alone is not integrity verification.

Security issues should not be filed as public issues; follow [SECURITY.md](SECURITY.md).

## Português

Prepare a dependência verificada, execute os comandos acima e mantenha os testes offline. Use fixtures sintéticas e código original, sem dados pessoais ou código privado. Inclua regressões reais, preserve o oráculo independente e atualize documentação e contrato. Não inclua fontes baixadas ou arquivos gerados. Para problemas de segurança, use relato privado conforme `SECURITY.md`.
