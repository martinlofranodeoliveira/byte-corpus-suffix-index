# Runtime and dependency provenance

## Supplied runtime qualification record

The supplied technical qualification record identifies:

- Lua **5.4.4**, signed 64-bit integers, `math.maxinteger = 9223372036854775807`.
- dkjson **2.11**; its `decode` and `encode` APIs were exercised offline.
- Non-root UID 1000, network disabled and all capabilities dropped for that qualification.
- Private runtime image digest: `sha256:16306be312f4d525a0e969dffcd3451720470aa232114ddd85ce9c6b8633f6c8`.
- Lua license: MIT; official reference: <https://www.lua.org/manual/5.4/> and <https://www.lua.org/license.html>.

These facts describe runtime/dependency qualification, not results of this project's suffix tests, an image distribution offer, a benchmark or a memory guarantee. A public distro installation may have a different Lua 5.4 patch version. No unobserved interoperability or native-code behavior is asserted. Lua, LuaRocks and the private image are not bundled by this project.

## Exact CLI dependency

The CLI and its process tests require the pure-Lua dkjson source:

- Version: **2.11**.
- Official source: <https://dkolf.de/dkjson-lua/dkjson-2.11.lua>.
- Official download listing used for confirmation: <https://dkolf.de/downloads>.
- Homepage: <https://dkolf.de/dkjson-lua/>.
- LuaRocks module information: <https://luarocks.org/modules/dhkolf/dkjson>.
- SHA-256: `197cb50834c642f84b4cf99fe724932c50e6d9c92faec7ad89aa25e91df4d481`.
- License: MIT; copyright 2010–2026 David Heiko Kolf, retained in the official source.

The official source download is the preparation route. There is no invented LuaRocks revision, lockfile or additional checksum. The core rockspec has only the Lua dependency because it installs only the dependency-free index module. CLI tests refuse a module whose reported version differs from `dkjson 2.11`; source integrity is established at preparation, not by that version string alone.

```sh
python3 tools/prepare_dependency.py
lua5.4 test/run.lua
lua5.4 bin/byte_corpus_index.lua demo --assert --json
```

The downloader uses Python's standard library, HTTPS with default certificate validation, a network timeout, a bounded read and exact SHA-256 comparison. It writes only verified bytes using a temporary file in the ignored dependency directory, checks writes/flushes through Python I/O, and replaces the destination after successful verification. It refuses existing mismatched content and symlinked destinations. Run preparation in a trusted, owned project directory without concurrent writers. It neither imports nor executes the downloaded Lua file.

Alternatively, supply the already verified official file as `dkjson.lua` through `LUA_PATH`, such as the qualified runtime's `/opt/lofrano-dkjson` location. The source-tree launchers also search their own ignored `build/dependencies` directory. Do not treat an arbitrary same-version module on a hostile search path as trusted. Tests and demos make no network requests.

The repository authors do not claim authorship of dkjson. Its source must not be folded into the project's original-code claim. Retain its source license when redistributing a prepared environment.

## dkjson MIT notice

Copyright (C) 2010-2026 David Heiko Kolf

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Português

O registro fornecido identifica Lua 5.4.4 com inteiros de 64 bits e dkjson 2.11, com encode/decode verificados offline em UID 1000, sem rede e sem capabilities. Isso não relata testes deste índice nem garante memória. A preparação pública usa o download oficial acima, verifica o SHA-256 real antes de instalar em `build/dependencies` e preserva a licença MIT do autor do dkjson. Não há revisão LuaRocks ou lockfile inventados. Após preparar, testes e CLI não usam rede.
