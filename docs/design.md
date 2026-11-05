# Design — development version 0.1.0

## Intended use

Small public binary fixture corpora can need exact substring locations without a database. This is a use hypothesis, not evidence of adoption or a performance advantage. The implementation favors explicit limits, independent checks and auditable state over a large API.

## Admission and atomic publication

Admission checks container identity, absence of metatables, bounded entry count, integer keys, dense IDs, string types, per-document bytes and total bytes. `next` avoids caller-defined iteration; rejecting metatables happens before length or content access. An oversized table does not get copied or traversed to its end. There is no guarantee about hostile VM instrumentation or the cost of traversing an already allocated pathological Lua table.

Only admitted input is copied. Strings are immutable, so copying string references into a private table is sufficient. Construction arrays remain local. A handle is associated with its finished state only after construction completes. Invalid construction cannot change another index. Queries use read-only captured tables and return fresh tables. No getter or metamethod protocol is supported for input documents.

The private weak-key map lets an unreferenced handle and its corpus be collected. The empty handle has no data-bearing fields. Regular writes are rejected as a convenience. This is not a security boundary against `debug` or arbitrary same-VM code; even `rawset` can add fields, although normal API functions never consult them.

## Document-bounded doubling

Each real byte offset gets a numeric internal ID, in document/offset order. The initial rank is byte+1. Rank zero denotes an exhausted suffix, so a shorter equal-prefix suffix precedes a longer one without reserving a corpus byte.

At width w, sort IDs by `(rank[id], second_rank)`, where second_rank is `rank[id+w]` only if that offset is still in the same document, otherwise zero. Sort ties by internal ID, equivalent to document ID then offset. New equivalence classes ignore that tie-break: identical prefix pairs must share a rank even when their document IDs differ.

Each round doubles the known prefix length. Stop when all ranks are distinct, or the doubled width covers the longest document. At that point the sorted order is the full suffix order. Empty documents never introduce internal IDs. Every byte comparison starts with numeric `string.byte`, avoiding Lua's locale-sensitive string relational operators.

The implementation uses comparison sorting per round rather than counting/radix sorting. A conventional upper bound is O(N log N log L) comparison work for N suffixes and maximum document length L, with O(N+D) working arrays. This is algorithmic analysis, not an observed benchmark, optimality claim or RSS bound. Table layout, garbage collection and sorting overhead can dominate.

## Query path

Two binary searches compare bytes of a document-bounded suffix with the pattern. Equality means the complete pattern is a prefix of the suffix. Lower/upper endpoints delimit all matches, including overlapping starts. For absent patterns, both endpoints are the same valid insertion position.

An occurrence count is `hi-lo`. Only after that count passes the cap does the function allocate position records and sort them by document/offset. The distinct-document query scans the interval into a membership table with at most 32 keys, then emits ascending IDs. It does not need or reuse an occurrence listing. These choices keep an excessive listing from being accidentally collected before discovering its cap.

Approximate operation bounds, not runtime guarantees:

- Range: O(Q log N) byte comparisons, Q <=256.
- Occurrences: range work plus O(K log K) sorting only when K <=cap.
- Distinct documents: range work plus O(K+D) membership scanning, no K-element location array.
- Suffix inspection: either an immediate exact incomplete result, or O(N) copied positions.

Ranks used during construction are not retained as a public or persistent interface. The published corpus and suffix order suffice for queries.

## Independent checks

The diagnostic oracle shares no construction or search code with the index. It materializes short suffix slices and compares unsigned bytes directly. For occurrences it enumerates every legal document/offset and uses literal substring equality; for ranges it linearly scans the independently sorted suffixes. It is intentionally limited to tiny trusted synthetic fixtures, not an alternative production query API.

Regression checks include a literal 16-suffix golden for banana/ananas/band and the exact tie order for a/aa. Exhaustive checks cover all ordered pairs of 31 binary strings and all 14 nonempty patterns of lengths through three. Comparing empty interval endpoints detects search mistakes that comparing occurrence counts alone would miss. Literal acceptance fixtures protect against an oracle/index bug coincidence.

Adversarial tests exercise dense-table validation, metatable rejection without invoking getters, source and result mutation, numeric edge cases, maximum logical input, absent/boundary matches, syntactic/schema attacks and actual process I/O errors. The deleted fixture test removes an owned file before invoking the CLI; the `/dev/full` tests make real output calls fail rather than mocking success flags. A temporary external package directory verifies that the core does not depend on the checkout or JSON.

## CLI trust boundary

The CLI opens only an explicit manifest, reads a bounded amount, and checks close before doing successful work. No content is loaded as Lua code. A depth-bounded syntax gate runs before dkjson decoding; byte strings are represented as hexadecimal and admitted before conversion. Duplicate object keys intentionally follow the pinned decoder's last-value rule, documented rather than mistaken for uniqueness.

Fixed diagnostic codes prevent content/path disclosure through parser excerpts or OS error messages. Stdout write and flush are checked. A process exit code, not the mere presence of some output bytes, defines success. There is no success file to leave behind after an error and no attempt to pretend ordinary streams support rollback.

## Non-goals and deployment boundary

No text edits, Unicode semantics, filesystem discovery, persistent index format, streaming corpus, database integration, network API or compressed-index promise is included. No clocks, telemetry, credentials or hidden external service are used.

For a constrained offline environment, prepare runtime and dependency before isolation, then use non-root execution, disabled network, dropped capabilities, 1 GiB and 2 CPUs without host-directory mounts. Input counters constrain algorithmic cardinalities only; they do not prove that a particular upper-bound build fits an operating-system budget. CI preparation uses network and distro package tools and is intentionally separate from this runtime profile.

## Português

A construção só publica o handle após admitir e copiar o corpus e ordenar todos os sufixos. Ranks de segunda metade nunca atravessam documentos; zero representa fim de sufixo, não um byte reservado. Empates de ordenação usam documento/offset, mas não criam classes de rank distintas para prefixos iguais.

Consultas usam busca binária por bytes. A contagem vem antes da alocação de ocorrências, e documentos distintos usam um conjunto de no máximo 32 IDs. O oráculo independente usa substrings literais e varredura linear em fixtures pequenas. Estado privado e respostas copiadas evitam mutações pela API normal, sem alegar sandbox contra código Lua arbitrário. Limites lógicos e análise assintótica não são medições de desempenho nem garantias de memória.
