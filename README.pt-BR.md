# Byte Corpus Suffix Index

**Versão de desenvolvimento 0.1.0**, da [Lofrano Tecnologia](https://lofranotecnologia.com.br).
Biblioteca original para Lua 5.4 que localiza substrings exatas em pequenos conjuntos imutáveis de documentos binários. Conta ocorrências sobrepostas e documentos distintos sem banco de dados, serviço de modelo, telemetria ou rede durante a execução.

[English](README.md) · [Contrato preciso](docs/contract.md) · [Projeto](docs/design.md) · [Dependências](docs/dependencies.md)

## Instalação, testes e demonstração

Use Lua 5.4. Python 3 serve apenas para preparar a dependência pública. Os testes usam Linux, shell POSIX e `/dev/full`. No diretório do projeto:

```sh
python3 tools/prepare_dependency.py
lua5.4 test/run.lua
lua5.4 bin/byte_corpus_index.lua demo --assert
lua5.4 bin/byte_corpus_index.lua demo --assert --json
lua5.4 bin/byte_corpus_index.lua query fixtures/corpus.json --json
```

A preparação baixa exatamente o código oficial do dkjson 2.11 e verifica o SHA-256 registrado **antes do uso**. O arquivo fica em `build/dependencies/dkjson.lua`, ignorado pelo controle de versão. O preparador não executa o conteúdo baixado. Um arquivo local com hash correto é reutilizado sem rede; um arquivo diferente é recusado. Preserve a licença de terceiros. Também é possível disponibilizar o mesmo código verificado por `LUA_PATH`. Depois da preparação, testes e CLI funcionam offline. O código da dependência não está incluído neste projeto.

A biblioteca principal depende somente de Lua 5.4:

```sh
LUA_PATH='./lua/?.lua;;' lua5.4 -e 'local i=require("byte_corpus_index"); local h=assert(i.build({"aaaa"})); print(assert(i.occurrences(h,"aa")).count)'
```

Saída: `3`. Com LuaRocks já instalado, a instalação opcional do núcleo é local e offline:

```sh
luarocks --lua-version=5.4 make --tree build/install --deps-mode=none byte-corpus-suffix-index-0.1.0-1.rockspec
```

O rockspec instala somente `byte_corpus_index`, não a CLI do diretório-fonte. Não afirma que exista um rock publicado nem uma revisão LuaRocks específica do dkjson. Ajuste `package.path` para a árvore escolhida. Os testes também copiam o núcleo para um diretório temporário próprio e o carregam fora do checkout, sem dkjson.

## Demonstração determinística

`demo --assert` verifica posições literais, resultados de um oráculo ingênuo independente, intervalos, identidades dos documentos e desempate de sufixos iguais. Saída humana esperada:

```text
Byte Corpus Suffix Index 0.1.0 (development)
demo: 6 queries and suffix tie order verified against assertions
ana: count=4 documents=2 range=[2,6) positions=1:2,1:4,2:1,2:3
ban: count=2 documents=2 range=[8,10) positions=1:1,3:1
xyz: count=0 documents=0 range=[17,17) positions=none
boundary: count=0 documents=0 range=[3,3) positions=none
nul: count=2 documents=1 range=[1,3) positions=1:1,1:3
ff00: count=1 documents=1 range=[3,4) positions=1:2
```

Com `--json`, a saída contém `version`, `kind`, `ok` e os resultados. Para o manifesto fornecido, os campos relevantes são:

```json
{"range":{"lo":2,"hi":6,"count":4},"occurrences":{"count":4,"complete":true,"items":[{"document_id":1,"offset":2},{"document_id":1,"offset":4},{"document_id":2,"offset":1},{"document_id":2,"offset":3}]},"distinct_documents":{"count":2,"documents":[1,2]}}
```

Esse trecho é um exemplo de uso, não um recibo de execução armazenado. Todas as entradas de exemplo são sintéticas.

## API Lua

```lua
local indice = require("byte_corpus_index")
local corpus = assert(indice.build({ "banana", "ananas", "band", "" }))
local intervalo = assert(indice.prefix_range(corpus, "ana")) -- [2,6), count 4
local ocorrencias = assert(indice.occurrences(corpus, "ana", 20))
for _, item in ipairs(ocorrencias.items) do
  print(item.document_id, item.offset)
end
local documentos = assert(indice.distinct_documents(corpus, "ana"))
assert(documentos.count == 2)
local limitado = assert(indice.occurrences(corpus, "ana", 3))
assert(not limitado.complete and limitado.count == 4 and limitado.items == nil)
```

IDs e deslocamentos começam em 1 e são inteiros Lua. Intervalos são posições no vetor de sufixos, com início inclusivo e fim exclusivo, não deslocamentos no corpus. As ocorrências vêm em ordem de documento e deslocamento, independentemente da ordem dos sufixos. `suffixes` permite inspeção limitada na ordem de sufixos; `stats` devolve contadores copiados. Erros de entrada retornam `nil, codigo`, sem mensagens que incluam a entrada. A ordem de validação e os códigos estão no [contrato](docs/contract.md).

`build` admite apenas tabela simples e densa: até 32 strings, 4096 bytes por documento e 65536 bytes no total. Documentos vazios mantêm seus IDs e não acrescentam sufixos. Consultas têm 1–256 bytes, inclusive NUL e `0xff`. Não existem correspondências atravessando documentos. O limite de listagem é inteiro Lua entre 0 e 65536, padrão 4096; floats, NaN e infinitos são rejeitados. Acima do limite, a contagem continua exata, `complete=false` e **não há campo `items`**. Documentos distintos continuam exatos.

## Manifesto e erros da CLI

```json
{"documents_hex":["00ff00",""],"query_hex":"ff00","result_cap":10}
```

Somente esses campos são aceitos. Hexadecimal explícito usa ASCII, quantidade par de dígitos e aceita maiúsculas ou minúsculas. `result_cap` é opcional. Não há referências a arquivos de corpus, descoberta de diretórios ou avaliação de expressões. A CLI abre somente o caminho de manifesto informado. Antes de decodificar, limita a entrada a 140000 bytes e oito contêineres aninhados. Chaves duplicadas seguem a regra do último valor do dkjson; evite duplicatas. Comentários, BOM, vírgulas finais e conteúdo adicional são rejeitados. Não há alegação de conformidade JSON universal.

Códigos de saída: `0` sucesso completo; `2` uso/entrada/dependência inválidos; `3` listagem incompleta com contagem exata; `4` falha interna ou de asserção; `5` falha de arquivo ou saída. Uma resposta incompleta tem `ok=false`. Erros de entrada não produzem stdout. Diagnósticos usam códigos fixos, sem caminhos, bytes do corpus ou trechos do decodificador. Só aceite um recibo com código 0 e flush bem-sucedido. Uma saída parcialmente escrita não pode ser desfeita.

## Decisões e limitações

A duplicação de prefixos respeita cada documento e não depende de separadores: todos os 256 valores de byte são válidos. Comparações usam números sem sinal, não ordenação textual por locale. O estado fica privado e as respostas são cópias. A busca binária conta antes de alocar a lista. O oráculo usa substrings literais e varredura linear, sem reutilizar ranks do índice.

A suíte define 961 pares ordenados de strings binárias de tamanho 0–4 e 14 padrões de tamanho 1–3, totalizando 13454 comparações de consultas. Inclui intervalos vazios, ordem literal de sufixos, sobreposição, bytes extremos, mutações externas, limites, números adversariais, manifestos inválidos, remoção real de fixture antes da abertura e falhas reais de escrita/flush em Linux. Isso descreve os testes, não resultados medidos nem desempenho.

- Não interpreta Unicode, normaliza texto ou oferece offsets em caracteres.
- Não é um índice comprimido ou persistente; não promete compatibilidade de serialização.
- Tabelas Lua podem ser caras nos limites superiores. Limites lógicos **não** garantem disco, RSS, tempo ou memória do contêiner.
- Consultas não têm relógios nem caches mutáveis compartilhados. Serialize construção e publicação; não há primitiva de sincronização entre threads.
- Metatables não são sandbox contra `rawset`, `debug`, getters hostis externos ou código arbitrário. Operações normais da API não alteram o estado capturado; código no mesmo VM deve ser confiável.
- Falta de memória do VM pode levantar erro fora do contrato de retornos. Nenhum handle parcialmente construído é publicado.
- O teste completo requer Linux. A preparação da CI usa rede; ela não representa por si só o perfil isolado de execução.

Para execução offline isolada, disponibilize previamente runtime, dependência verificada e projeto dentro do ambiente. Use usuário não root, rede desabilitada, todas as capabilities removidas, 1 GiB e 2 CPUs. Não monte home do host, chaves, socket Docker ou outros diretórios do host. O registro fornecido de qualificação do runtime está em [dependências](docs/dependencies.md); ele não implica garantia de RSS.

Licença MIT, copyright 2026 Lofrano Tecnologia. Contato geral: [site oficial](https://lofranotecnologia.com.br). Segurança: [relato privado no GitHub](https://github.com/martinlofranodeoliveira/byte-corpus-suffix-index/security/advisories/new).
