rockspec_format = "3.0"
package = "byte-corpus-suffix-index"
version = "0.1.0-1"
source = {
  url = "https://github.com/martinlofranodeoliveira/byte-corpus-suffix-index/archive/refs/heads/main.zip"
}
description = {
  summary = "Bounded immutable byte-corpus suffix index",
  detailed = "Development version 0.1.0. Core API only; the source-tree CLI uses separately verified dkjson 2.11.",
  homepage = "https://lofranotecnologia.com.br",
  license = "MIT",
  maintainer = "Lofrano Tecnologia"
}
dependencies = { "lua >= 5.4, < 5.5" }
build = {
  type = "builtin",
  modules = { byte_corpus_index = "lua/byte_corpus_index.lua" }
}
