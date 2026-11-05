-- Copyright 2026 Lofrano Tecnologia. MIT license.
local root = arg[0]:match("^(.*)/bin/byte_corpus_index%.lua$") or "."
package.path = root .. "/lua/?.lua;" .. root .. "/build/dependencies/?.lua;" .. package.path
local ok, cli = pcall(require, "byte_corpus_cli")
if not ok then
  pcall(function()
    io.stderr:write("byte-corpus-index: module_load_failed\n")
    io.stderr:flush()
  end)
  os.exit(4)
end
os.exit(cli.main(arg))
