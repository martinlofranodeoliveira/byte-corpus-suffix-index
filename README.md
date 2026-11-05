# Byte Corpus Suffix Index

**Development version 0.1.0**, by [Lofrano Tecnologia](https://lofranotecnologia.com.br).
An original Lua 5.4 library for exact substring evidence in small, immutable binary corpora. It counts overlapping occurrences and identifies distinct matching documents, without a database, model service, telemetry or runtime network access.

[Português](README.pt-BR.md) · [Precise contract](docs/contract.md) · [Design](docs/design.md) · [Dependency provenance](docs/dependencies.md)

## Install and run

Use Lua 5.4. Python 3 is needed only for public dependency preparation. The Linux test suite also uses a POSIX shell and `/dev/full`. From the project directory:

```sh
python3 tools/prepare_dependency.py
lua5.4 test/run.lua
lua5.4 bin/byte_corpus_index.lua demo --assert
lua5.4 bin/byte_corpus_index.lua demo --assert --json
lua5.4 bin/byte_corpus_index.lua query fixtures/corpus.json --json
```

Preparation fetches exactly the official dkjson 2.11 source, verifies its recorded SHA-256 **before use**, and saves it to ignored `build/dependencies/dkjson.lua`. It does not execute downloaded code. An existing matching file is reused without network access; a mismatching file is refused. Keep the third-party license notice. Alternatively, provide the same verified source through `LUA_PATH`. Tests and CLI execution are offline after this step. No dependency source is bundled here.

The core library itself has **no dependencies** beyond Lua 5.4. For source-tree use:

```sh
LUA_PATH='./lua/?.lua;;' lua5.4 -e 'local i=require("byte_corpus_index"); local h=assert(i.build({"aaaa"})); print(assert(i.occurrences(h,"aa")).count)'
```

Output: `3`. Optional core-only installation with an existing LuaRocks installation is local and offline:

```sh
luarocks --lua-version=5.4 make --tree build/install --deps-mode=none byte-corpus-suffix-index-0.1.0-1.rockspec
```

The rockspec installs only `byte_corpus_index`, not the source-tree diagnostic CLI. It does not claim a published rock or a dkjson LuaRocks release. Configure your application's `package.path` for your chosen installation tree. The suite additionally copies the core into an owned temporary directory and requires it from outside the checkout, without dkjson.

## Deterministic demo

`demo --assert` checks literal expected locations, independent naive substring results, prefix ranges, document identities and a tied suffix-order golden. Expected human output:

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

Machine output is deterministic JSON with `version`, `kind`, `ok` and either `cases` or the query result. For the supplied manifest, the significant fields are:

```json
{"range":{"lo":2,"hi":6,"count":4},"occurrences":{"count":4,"complete":true,"items":[{"document_id":1,"offset":2},{"document_id":1,"offset":4},{"document_id":2,"offset":1},{"document_id":2,"offset":3}]},"distinct_documents":{"count":2,"documents":[1,2]}}
```

This excerpt is a usage example, not a stored execution receipt. All fixtures are synthetic.

## Callable API

```lua
local index = require("byte_corpus_index")
local corpus = assert(index.build({ "banana", "ananas", "band", "" }))
local range = assert(index.prefix_range(corpus, "ana")) -- [2,6), count 4
local hits = assert(index.occurrences(corpus, "ana", 20))
for _, hit in ipairs(hits.items) do
  print(hit.document_id, hit.offset)
end
local documents = assert(index.distinct_documents(corpus, "ana"))
assert(documents.count == 2)
local limited = assert(index.occurrences(corpus, "ana", 3))
assert(not limited.complete and limited.count == 4 and limited.items == nil)
```

IDs and offsets are 1-based integers. Prefix ranges are 1-based, half-open suffix-array positions, not corpus offsets. Occurrence lists are in document/offset order; suffix inspection uses suffix order. Errors return `nil, code`, not input-bearing messages. See the contract for all error codes and validation order.

`build` admits only plain dense tables, at most 32 strings, 4096 bytes per string, 65536 bytes total. Empty documents retain IDs but contribute no suffixes. Queries are arbitrary byte strings of length 1–256, including NUL and `0xff`. There is no cross-document matching. Caps are Lua integers 0–65536, default 4096; floats, NaN and infinities are refused. Over-cap listings return the exact count, `complete=false`, and **no `items` field**. Distinct-document queries remain exact.

## Manifest and CLI behavior

```json
{"documents_hex":["00ff00",""],"query_hex":"ff00","result_cap":10}
```

Only these fields are allowed. Hex is explicit, even-length ASCII; either letter case is accepted. `result_cap` is optional. There are no referenced corpus files, directory discovery or executable expressions. The CLI opens only its explicit manifest path. The 140000-byte manifest limit and eight-container nesting limit are checked before decoding. See [JSON details](docs/contract.md#manifest-format) for duplicate keys and syntax restrictions.

Exit status: `0` complete success; `2` usage/input/dependency error; `3` exact but incomplete listing; `4` assertion/internal error; `5` file/output I/O failure. Incomplete JSON has `ok=false`. Input errors produce no stdout. Diagnostics contain fixed codes, not manifest paths, corpus bytes or decoder excerpts. A receipt is valid only with exit 0 and successful stdout flush; consumers must check exit status. A failed output stream cannot be rolled back.

## Why this design?

Document-bounded prefix doubling avoids separator-byte assumptions: every one of the 256 byte values is legal. Byte comparisons are numeric, not locale-sensitive string ordering. Private state and copied outputs separate construction from immutable publication. Binary search determines an exact count before any occurrence listing is allocated. A separate naive oracle uses literal substring slices and a linear scan, rather than reusing index ranks.

The regression suite exhausts **961 ordered pairs** of binary strings of lengths 0–4 against **14 patterns** of lengths 1–3: 13454 query comparisons, including empty insertion points. It also covers literal suffix orders, overlapping matches, NUL/high bytes, mutated inputs/outputs, admission limits, invalid numeric caps, manifest attacks, actual deleted-file opening failure and Linux stdout write/flush failure. These are test definitions, not benchmark or deployment claims.

## Limitations and safe use

- Not Unicode-aware: no normalization, collation, tokenization or character offsets.
- Not compressed or persistent; no serialized-index compatibility is promised.
- Lua tables can be costly at the upper bounds. Logical limits are **not** disk, RSS, time or container-memory guarantees.
- Queries have no clocks or shared mutable caches. Serialize construction and publication; this is not a thread synchronization primitive.
- Metatables are not a sandbox for `rawset`, `debug`, hostile getters elsewhere or arbitrary code. Ordinary API operations cannot change captured state; treat code in the same Lua VM as trusted.
- Resource exhaustion such as VM allocation failure can raise outside the returned-error contract. No partially built handle is published.
- The test harness targets Linux. CI downloads tools and the verified dependency during preparation; it is not the isolated runtime profile itself.

For an offline isolated run, have the runtime, verified dependency and this project available inside the environment beforehand. Use a non-root account, network disabled, all capabilities dropped, 1 GiB memory and 2 CPUs. Do not mount a host home, keys, Docker socket or other host directories. A supplied runtime qualification record is documented separately; this project does not infer an RSS guarantee from it.

MIT, copyright 2026 Lofrano Tecnologia. General contact: [official homepage](https://lofranotecnologia.com.br). Security: [private vulnerability reporting](https://github.com/martinlofranodeoliveira/byte-corpus-suffix-index/security/advisories/new).
