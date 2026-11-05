-- Copyright 2026 Lofrano Tecnologia. MIT license.
return function(T)
  local manifest = require("byte_corpus_manifest")
  local json = assert(manifest.json())
  local valid = '{"documents_hex":["62616e616e61","616e616e6173","62616e64"],"query_hex":"616e61"}'
  local fixture = T.tempfile(valid)
  local code, output, errors = T.cli({ "query", fixture, "--json" })
  T.eq(code, 0); T.eq(errors, "")
  local result = assert(json.decode(output))
  T.eq(result.ok, true); T.eq(result.occurrences.count, 4)
  T.positions(result.occurrences.items, { {1,2}, {1,4}, {2,1}, {2,3} })
  T.eq(result.distinct_documents.count, 2)
  T.eq(result.range.lo, 2); T.eq(result.range.hi, 6)
  code, output, errors = T.cli({ "demo", "--assert" })
  T.eq(code, 0); T.eq(errors, "")
  T.check(output:find("ana: count=4 documents=2 range=[2,6) positions=1:2,1:4,2:1,2:3", 1, true))
  local second_code, second_output = T.cli({ "demo", "--assert" })
  T.eq(second_code, 0); T.eq(second_output, output, "deterministic human output")
  code, output = T.cli({ "demo", "--assert", "--json" })
  T.eq(code, 0)
  result = assert(json.decode(output))
  T.eq(result.ok, true); T.eq(#result.cases, 6)
  T.eq(result.cases[1].occurrences.count, 4)
  local json_code, json_output = T.cli({ "demo", "--assert", "--json" })
  T.eq(json_code, 0); T.eq(json_output, output, "deterministic machine output")

  local limited = T.tempfile(valid:sub(1, -2) .. ',"result_cap":3}')
  code, output, errors = T.cli({ "query", limited, "--json" })
  T.eq(code, 3); T.eq(errors, "")
  result = assert(json.decode(output))
  T.eq(result.ok, false); T.eq(result.occurrences.complete, false)
  T.eq(result.occurrences.count, 4); T.eq(result.occurrences.items, nil)
  T.eq(result.distinct_documents.count, 2)

  local deleted = T.tempfile(valid)
  assert(os.remove(deleted))
  code, output, errors = T.cli({ "query", deleted, "--json" })
  T.eq(code, 5); T.eq(output, "")
  T.eq(errors, "byte-corpus-index: file_open\n")
  T.check(not errors:find(deleted, 1, true), "no input path in diagnostics")
  local directory = T.tempdir()
  code, output, errors = T.cli({ "query", directory })
  T.eq(code, 5); T.eq(output, "")
  T.check(errors == "byte-corpus-index: file_read\n" or errors == "byte-corpus-index: file_open\n",
    "actual directory read/open failure")

  local invalid = {
    "", "[]", "{}", valid .. " false", valid .. "\v", "\239\187\191" .. valid,
    '{"documents_hex":[],"query_hex":""}',
    '{"documents_hex":["0"],"query_hex":"00"}',
    '{"documents_hex":["gg"],"query_hex":"00"}',
    '{"documents_hex":[null],"query_hex":"00"}',
    '{"documents_hex":{},"query_hex":"00"}',
    '{"documents_hex":[],"query_hex":"00","result_cap":3.0}',
    '{"documents_hex":[],"query_hex":"00","result_cap":1e999}',
    '{"documents_hex":[],"query_hex":"00","result_cap":9223372036854775807}',
    '{"documents_hex":[],"query_hex":"00","result_cap":-1}',
    '{"documents_hex":[],"query_hex":"00","result_cap":null}',
    '{"documents_hex":[],"query_hex":"00","private_marker":"SYNTHETIC_SECRET_MARKER"}',
    '{"documents_hex":[],"query_hex":"00",}',
    '{"documents_hex":["00",],"query_hex":"00"}',
    '{/* comment */"documents_hex":[],"query_hex":"00"}',
    '{"documents_hex":[],"query_hex":"00" // comment\n}',
    '{"documents_hex":[],"query_hex":"00","extra":' .. string.rep("[", 9)
      .. "0" .. string.rep("]", 9) .. "}",
    '{"documents_hex":["' .. string.rep("00", 4097) .. '"],"query_hex":"00"}',
    '{"documents_hex":[],"query_hex":"' .. string.rep("00", 257) .. '"}'
  }
  for _, text in ipairs(invalid) do
    local path = T.tempfile(text)
    code, output, errors = T.cli({ "query", path, "--json" })
    T.eq(code, 2); T.eq(output, "")
    T.eq(errors, "byte-corpus-index: invalid_manifest\n")
    T.check(not errors:find("SYNTHETIC_SECRET_MARKER", 1, true))
  end
  local huge = T.tempfile(string.rep(" ", manifest.MAX_BYTES + 1))
  code, output, errors = T.cli({ "query", huge })
  T.eq(code, 2); T.eq(output, "")
  T.eq(errors, "byte-corpus-index: manifest_too_large\n")
  local duplicate = T.tempfile('{"documents_hex":["61"],"query_hex":"62","query_hex":"61"}')
  code, output = T.cli({ "query", duplicate, "--json" })
  T.eq(code, 0); T.eq(assert(json.decode(output)).occurrences.count, 1)
  local escaped = T.tempfile('{"documents_hex":["00FF00"],"query_hex":"\\u0030\\u0030"}')
  code, output = T.cli({ "query", escaped, "--json" })
  T.eq(code, 0)
  T.positions(assert(json.decode(output)).occurrences.items, { {1,1}, {1,3} })
  code, output = T.cli({ "demo" })
  T.eq(code, 2); T.eq(output, "")

  -- Linux device tests exercise both buffered flush and a larger direct write.
  local full = io.open("/dev/full", "wb")
  assert(full, "tests require Linux /dev/full")
  assert(full:close())
  code, _, errors = T.cli({ "demo", "--assert", "--json" }, "/dev/full")
  T.eq(code, 5); T.eq(errors, "byte-corpus-index: output_failed\n")
  local large = T.tempfile('{"documents_hex":["' .. string.rep("61", 512)
    .. '"],"query_hex":"61","result_cap":512}')
  code, _, errors = T.cli({ "query", large, "--json" }, "/dev/full")
  T.eq(code, 5); T.eq(errors, "byte-corpus-index: output_failed\n")

  -- Install just the authored core into an owned temporary package directory.
  -- No checkout path, JSON dependency, network or host home is needed by the child.
  local stage = T.tempdir()
  local module_path = stage .. "/byte_corpus_index.lua"
  T.owned[#T.owned + 1] = module_path
  T.write(module_path, T.read(T.root .. "/lua/byte_corpus_index.lua"))
  local script = "local i=require('byte_corpus_index'); local h=assert(i.build({'aaaa'})); "
    .. "local r=assert(i.occurrences(h,'aa')); assert(r.count==3); "
    .. "assert(r.items[3].offset==3); io.write('standalone ok\\n')"
  code, output, errors = T.child("cd " .. T.quote(stage)
    .. " && LUA_PATH='./?.lua' LUA_CPATH='' " .. T.quote(T.lua) .. " -e " .. T.quote(script))
  T.eq(code, 0); T.eq(output, "standalone ok\n"); T.eq(errors, "")
  -- Also run the source-tree CLI from outside the checkout.
  code, output, errors = T.child("cd " .. T.quote(stage) .. " && " .. T.quote(T.lua)
    .. " " .. T.quote(T.root .. "/bin/byte_corpus_index.lua") .. " demo --assert --json")
  T.eq(code, 0); T.eq(assert(json.decode(output)).ok, true); T.eq(errors, "")
end
