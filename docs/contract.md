# Contract — development version 0.1.0

This document defines the supported library and CLI behavior. No persistent format, cross-version index compatibility or general JSON/Unicode standard conformance is claimed.

## Values and ownership

The module is `byte_corpus_index`. All functions are module functions, not methods on the index. An index is an opaque table handle whose state is kept in a private weak-key map. No corpus, ranks or internal suffix arrays are fields of the handle. Strings are immutable Lua values, the input table is copied after admission, and public result tables are fresh copies. Normal API calls cannot modify an index or a previously returned result.

Metatable protection is an ergonomic guard, not a sandbox. `rawset` may add irrelevant fields to the handle; library functions ignore them. `debug`, modified module code, arbitrary hostile Lua code and hostile access to process resources are outside the isolation model. Callers must serialize construction and publication and must not modify inputs concurrently. Queries have no clocks, I/O or mutable shared caches. Handles remain usable while referenced. There is no global current index.

IDs are the consecutive integers 1 through the admitted document count. Offsets are 1-based byte offsets. Empty documents keep their IDs; they have zero suffixes. There is no empty suffix at document length + 1. Every byte value 0–255 is legal and compared numerically as unsigned. Locale and UTF-8 do not affect ordering.

## Build

`build(documents) -> index | nil, code`

Input must be a plain table with no metatable and exactly the keys 1 through n, where 0 <= n <= 32. Validation uses `next`, checks every visited key and value, and stops on excess entries or out-of-range keys. It does not infer density from `#` or `ipairs`. Lua canonicalizes integral numeric table keys, so a key written as `1.0` is indistinguishable from key `1`.

Values must be strings, each at most 4096 bytes; total at most 65536 bytes. No suffix storage or public handle is created until the complete input has passed admission. Excessive input is rejected as a unit, without truncation and without modifying existing indexes. The empty table is valid.

Suffixes are ordered by unsigned-byte lexicographic value, with a shorter equal-prefix suffix first. Identical full suffixes tie by document ID, then offset. Construction uses document-bounded prefix doubling; neither bytes nor ranks cross a document boundary.

Build errors are `invalid_documents` (wrong container, metatable, bad key or hole), `too_many_documents` (more than 32 visited entries or an integer key above 32), `invalid_document` (non-string value), `document_too_large`, and `corpus_too_large`. When multiple defects exist, the first encountered by `next` wins; traversal order of invalid tables is not promised. Container/metatable checks occur first. Valid input has deterministic output.

## Query validation

All query functions first validate index identity, then the query, then a cap if applicable, before searching the suffix array. A query must be a string of 1 through 256 bytes. Empty queries are rejected, including for empty corpora. Invalid handles return `nil, "invalid_index"`; invalid queries return `nil, "invalid_query"`.

A cap omitted or `nil` means 4096. An explicit cap must satisfy `math.type(cap) == "integer"` and 0 <= cap <= 65536. Floats (even `3.0`), fractions, strings, booleans, NaN, infinities and `math.maxinteger` outside the range are rejected with `nil, "invalid_cap"`. No result traversal or occurrence collection occurs before cap validation.

All supported offsets, ranks, interval endpoints and counts use exact Lua integers. A standard Lua 5.4 build with integer range at least signed 32-bit suffices for the bounded arithmetic; supplied runtime qualification used signed 64-bit integers.

## `prefix_range(index, query)`

Returns `{lo=integer, hi=integer, count=integer}`. Endpoints are **1-based, half-open suffix-array positions**: matching suffixes occupy lo through hi-1 and count = hi-lo. Both endpoints lie in 1 through N+1, where N is the number of suffixes. For no matches, lo=hi is the insertion point before the first suffix greater than the query under prefix comparison. An empty index always returns `[1,1)`. A query that is a prefix of a longer suffix matches that suffix.

For `banana`, `ananas`, `band`, `ana` yields `[2,6)`, `ban` yields `[8,10)`, and `xyz` yields `[17,17)`.

## `occurrences(index, query, cap)`

Returns `{count=integer, complete=boolean, items=array?}`. Count is always exact. If count <= cap, complete is true and items is an array of `{document_id=integer, offset=integer}`, sorted by document ID, then offset. Matches may overlap. A complete zero-result listing contains an empty items array.

If count > cap, complete is false and **items is absent**, not an empty or truncated alleged complete list. The count is computed from interval endpoints before allocating an occurrence array. There is no pagination contract.

## `distinct_documents(index, query)`

Returns `{count=integer, documents=array}` with the exact matching document IDs in ascending order. Each document contributes once, regardless of repeated or overlapping occurrences. At most 32 IDs are returned. It scans the matching suffix interval with a bounded document-membership set, without constructing an occurrence list. An occurrence cap does not affect this query.

## Inspection

`suffixes(index, cap)` returns the same count/complete/items shape as occurrences, but its items are the **entire suffix order**, not document/offset order. It applies the same cap/default before copying any positions. This is bounded diagnostic inspection, not serialization.

`stats(index)` returns a fresh `{documents=integer, bytes=integer, suffixes=integer}`. Both inspection functions reject invalid handles first; `suffixes` then validates its cap.

## Returned errors and resource failures

Expected validation failures return `nil, code`; inputs are never embedded in codes. Ordinary allocation failures or an externally terminated VM are not made recoverable by this contract. A failing construction never publishes a partial handle. Logical counts do not establish time, RSS, disk or operating-system limits. Arrays and sort overhead remain significant at maximum input.

## Manifest format

CLI commands:

- `lua5.4 bin/byte_corpus_index.lua demo --assert [--json]`
- `lua5.4 bin/byte_corpus_index.lua query MANIFEST [--json]`

Only one explicit manifest is opened. No stdin protocol, directory scanning, referenced corpus filenames, evaluation, output files or persistent indexes are supported. Manifest paths must be nonempty, at most 4096 bytes and contain no NUL. The caller is responsible for choosing an owned file and avoiding races in its directory.

Input is at most **140000 bytes**, measured by a bounded read of limit+1 bytes. The file is closed before parsing or emitting output. A string-aware syntax gate limits nesting to **eight containers**, counting the root, before invoking dkjson 2.11. Brackets inside strings do not increase depth. The gate rejects comments, BOMs, trailing commas, invalid escape syntax, unescaped control bytes, malformed numbers and trailing nonwhitespace. Only space, tab, CR and LF are whitespace.

The top-level value must be an object containing:

| Field | Meaning |
| --- | --- |
| `documents_hex` | Required JSON array, 0–32 strings, dense, each 0–8192 hex digits, combined decoded bytes <=65536 |
| `query_hex` | Required string of 2–512 hex digits |
| `result_cap` | Optional decoded Lua integer in 0–65536; default 4096 |

Unknown fields, nulls in place of fields, objects in place of arrays, odd digit counts and nonhex characters are rejected. Only ASCII hexadecimal `0-9a-fA-F` is accepted after decoding JSON strings. The decoder may process JSON escapes such as `\u0030`; the resulting value still must be ASCII hex. Numeric caps must decode as Lua integers; write `3`, not `3.0` or `3e0`.

Duplicate JSON object members use dkjson's **last-value-wins** semantics, including escaped equivalent keys. Uniqueness is not enforced. Do not use this representation as a canonical signing or authorization format. Syntax extensions such as comments and trailing commas accepted by some decoders are blocked by the gate. The project neither validates arbitrary UTF-8 JSON documents nor exposes a general JSON parser: known keys and all accepted data strings resolve to ASCII. No universal RFC compliance is claimed. Decoding, escaping and encoding use the pinned mature dependency, never `load` or `eval`.

Malformed/schema-invalid manifests yield `invalid_manifest`; oversized ones yield `manifest_too_large`. A missing or differently versioned JSON module yields `json_dependency`. Hex strings are fully size-admitted before conversion and core construction.

## CLI output and failure semantics

Human output contains only fixed labels, counts, ranges and locations. JSON query output contains `version`, `kind="query"`, `ok`, `documents` (corpus document count), `bytes`, `range`, `occurrences`, and `distinct_documents`. Demo JSON contains `version`, `kind="demo"`, `ok=true`, and six named query results in `cases`. Object key order and array order are deterministic for this implementation. Receipts do not echo corpus or query bytes.

Exit statuses:

| Code | Meaning |
| --- | --- |
| 0 | Complete result, assertions passed when applicable, stdout write and flush succeeded |
| 2 | Usage, invalid path, manifest, admission or JSON dependency error |
| 3 | Exact counts but occurrence listing exceeds its cap; query JSON has `ok=false` |
| 4 | Assertion, module loading, encoding or unexpected internal error |
| 5 | Actual input open/read/close failure or stdout write/flush failure |

Input processing failures emit no stdout. Fixed diagnostics go to stderr with prefix `byte-corpus-index: `. File errors are `file_open`, `file_read`, `file_close`; output errors are `output_failed`. Underlying exception text, input paths and contents are not printed. Unexpected failures are sanitized to `internal_error`; demo assertion failures to `assertion_failed`. Stderr failure is best-effort and never changes failure to success.

A complete receipt is valid **only when the process exits 0**. Output streams cannot be transactional: partial bytes already accepted by a stream cannot be withdrawn, and a later flush can fail. Consumers must discard output on I/O failure. The CLI does not create a success receipt file. It does not close caller-owned stdout; it checks its write and flush, and explicitly checks the owned manifest's close.

## Resumo normativo em português

A versão de desenvolvimento 0.1.0 usa documentos e offsets em bytes, começando em 1. `build` aceita somente tabela simples, densa, sem metatable, com até 32 documentos de até 4096 bytes e total de 65536. Não há sufixo vazio nem correspondência entre documentos. A ordenação é lexicográfica por bytes sem sinal; empates usam documento e offset.

`prefix_range` retorna `[lo,hi)` em posições do vetor de sufixos, incluindo ponto de inserção válido quando vazio. `occurrences` ordena por documento/offset, permite sobreposição e, acima do cap, informa contagem exata sem `items`. `distinct_documents` retorna IDs únicos em ordem crescente. Consultas têm 1–256 bytes; caps são inteiros Lua 0–65536, padrão 4096. Os retornos públicos são cópias e o estado é privado. Isso não torna metatables uma sandbox nem garante RSS. Os detalhes normativos completos estão nas seções acima.
