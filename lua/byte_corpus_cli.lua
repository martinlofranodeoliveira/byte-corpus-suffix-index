-- Copyright 2026 Lofrano Tecnologia. MIT license.
local index = require("byte_corpus_index")
local manifest = require("byte_corpus_manifest")
local M = {}

local function diagnostic(code)
  pcall(function()
    io.stderr:write("byte-corpus-index: " .. code .. "\n")
    io.stderr:flush()
  end)
end

local function read_manifest(path)
  if type(path) ~= "string" or #path == 0 or #path > 4096 or path:find("\0", 1, true) then
    return nil, "invalid_path"
  end
  local file = io.open(path, "rb")
  if not file then return nil, "file_open" end
  local data, read_err = file:read(manifest.MAX_BYTES + 1)
  local closed = file:close()
  if read_err then return nil, "file_read" end
  if not closed then return nil, "file_close" end
  data = data or ""
  if #data > manifest.MAX_BYTES then return nil, "manifest_too_large" end
  return manifest.parse(data)
end

local function evaluate(documents, query, cap)
  local handle, err = index.build(documents)
  if not handle then return nil, err end
  local occurrences, occurrence_err = index.occurrences(handle, query, cap)
  if not occurrences then return nil, occurrence_err end
  local stats = assert(index.stats(handle))
  return {
    documents = stats.documents, bytes = stats.bytes,
    range = assert(index.prefix_range(handle, query)),
    occurrences = occurrences,
    distinct_documents = assert(index.distinct_documents(handle, query))
  }, handle
end

local function equal_positions(a, b)
  assert(#a == #b, "position count")
  for i = 1, #a do
    assert(a[i].document_id == b[i].document_id and a[i].offset == b[i].offset,
      "position mismatch")
  end
end

local function demo()
  local oracle = require("byte_corpus_oracle")
  local samples = {
    { name = "ana", docs = { "banana", "ananas", "band" }, query = "ana",
      expected = { {1,2}, {1,4}, {2,1}, {2,3} }, distinct = 2 },
    { name = "ban", docs = { "banana", "ananas", "band" }, query = "ban",
      expected = { {1,1}, {3,1} }, distinct = 2 },
    { name = "xyz", docs = { "banana", "ananas", "band" }, query = "xyz",
      expected = {}, distinct = 0 },
    { name = "boundary", docs = { "ab", "cd" }, query = "bc",
      expected = {}, distinct = 0 },
    { name = "nul", docs = { "\0\255\0" }, query = "\0",
      expected = { {1,1}, {1,3} }, distinct = 1 },
    { name = "ff00", docs = { "\0\255\0" }, query = "\255\0",
      expected = { {1,2} }, distinct = 1 }
  }
  local cases = {}
  for i, sample in ipairs(samples) do
    local result = assert(evaluate(sample.docs, sample.query, 65536))
    local naive = oracle.analyze(sample.docs, sample.query)
    equal_positions(result.occurrences.items, naive.occurrences.items)
    assert(result.range.lo == naive.range.lo and result.range.hi == naive.range.hi,
      "range mismatch")
    assert(result.occurrences.count == #sample.expected, "literal count")
    assert(result.distinct_documents.count == sample.distinct, "literal distinct count")
    assert(result.distinct_documents.count == naive.distinct_documents.count,
      "oracle distinct count")
    for j, id in ipairs(naive.distinct_documents.documents) do
      assert(result.distinct_documents.documents[j] == id, "document identity")
    end
    for j, pair in ipairs(sample.expected) do
      local actual = result.occurrences.items[j]
      assert(actual.document_id == pair[1] and actual.offset == pair[2], "literal position")
    end
    result.name = sample.name
    cases[i] = result
  end
  local tied = assert(index.build({ "a", "aa", "" }))
  equal_positions(assert(index.suffixes(tied)).items, {
    { document_id = 1, offset = 1 }, { document_id = 2, offset = 2 },
    { document_id = 2, offset = 1 }
  })
  return { version = index.VERSION, kind = "demo", ok = true, cases = cases }
end

local function line(name, result)
  local positions = {}
  local occurrence = result.occurrences
  if occurrence.complete then
    for i, item in ipairs(occurrence.items) do
      positions[i] = item.document_id .. ":" .. item.offset
    end
  end
  local listing = occurrence.complete and (#positions > 0 and table.concat(positions, ",") or "none")
    or "incomplete (no listing)"
  return string.format("%s: count=%d documents=%d range=[%d,%d) positions=%s\n",
    name, occurrence.count, result.distinct_documents.count,
    result.range.lo, result.range.hi, listing)
end

local function render(receipt, machine)
  if machine then
    local json, err = manifest.json()
    if not json then return nil, err end
    local text, encode_err = json.encode(receipt, { keyorder = {
      "version", "kind", "ok", "cases", "name", "documents", "bytes", "range",
      "lo", "hi", "count", "occurrences", "complete", "items", "document_id",
      "offset", "distinct_documents"
    } })
    if not text then return nil, encode_err and "json_encode" or "json_encode" end
    return text .. "\n"
  end
  local output = { "Byte Corpus Suffix Index 0.1.0 (development)\n" }
  if receipt.kind == "demo" then
    output[#output + 1] = "demo: 6 queries and suffix tie order verified against assertions\n"
    for _, result in ipairs(receipt.cases) do output[#output + 1] = line(result.name, result) end
  else
    output[#output + 1] = line("query", receipt)
  end
  return table.concat(output)
end

local function write_output(text)
  local ok, written = pcall(function()
    if not io.stdout:write(text) then return false end
    return io.stdout:flush() ~= nil
  end)
  return ok and written
end

local function main(args)
  local command, machine, receipt, err = args[1], false, nil, nil
  if command == "demo" then
    if args[2] ~= "--assert" or (args[3] ~= nil and args[3] ~= "--json") or args[4] ~= nil then
      diagnostic("usage: demo --assert [--json] | query MANIFEST [--json]")
      return 2
    end
    machine = args[3] == "--json"
    -- The demo intentionally exercises the same pinned dependency as query.
    local json
    json, err = manifest.json()
    if not json then diagnostic(err); return 2 end
    local ok
    ok, receipt = pcall(demo)
    if not ok then diagnostic("assertion_failed"); return 4 end
  elseif command == "query" then
    if args[2] == nil or (args[3] ~= nil and args[3] ~= "--json") or args[4] ~= nil then
      diagnostic("usage: demo --assert [--json] | query MANIFEST [--json]")
      return 2
    end
    machine = args[3] == "--json"
    local input
    input, err = read_manifest(args[2])
    if not input then
      diagnostic(err)
      if err == "file_open" or err == "file_read" or err == "file_close" then return 5 end
      return 2
    end
    receipt, err = evaluate(input.documents, input.query, input.cap)
    if not receipt then diagnostic(err); return 2 end
    receipt.version, receipt.kind = index.VERSION, "query"
    receipt.ok = receipt.occurrences.complete
  else
    diagnostic("usage: demo --assert [--json] | query MANIFEST [--json]")
    return 2
  end
  local text
  text, err = render(receipt, machine)
  if not text then diagnostic(err); return 4 end
  if not write_output(text) then diagnostic("output_failed"); return 5 end
  return receipt.ok and 0 or 3
end

function M.main(args)
  local ok, code = pcall(main, args)
  if not ok then diagnostic("internal_error"); return 4 end
  return code
end

return M
