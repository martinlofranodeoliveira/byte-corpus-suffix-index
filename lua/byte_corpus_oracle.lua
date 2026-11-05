-- Copyright 2026 Lofrano Tecnologia. MIT license.
-- Deliberately simple, separate algorithm for small synthetic fixtures only.
local M = {}

local function fixture(documents)
  assert(type(documents) == "table" and #documents <= 4, "oracle fixture")
  for i = 1, #documents do
    assert(type(documents[i]) == "string" and #documents[i] <= 64, "oracle fixture")
  end
end

local function lexical(a, b)
  for i = 1, math.min(#a, #b) do
    local x, y = a:byte(i), b:byte(i)
    if x ~= y then return x < y end
  end
  return #a < #b
end

function M.suffixes(documents)
  fixture(documents)
  local order = {}
  for d = 1, #documents do
    for p = 1, #documents[d] do
      order[#order + 1] = { document_id = d, offset = p }
    end
  end
  table.sort(order, function(a, b)
    local x = documents[a.document_id]:sub(a.offset)
    local y = documents[b.document_id]:sub(b.offset)
    if x ~= y then return lexical(x, y) end
    if a.document_id ~= b.document_id then return a.document_id < b.document_id end
    return a.offset < b.offset
  end)
  return order
end

function M.analyze(documents, query, order)
  fixture(documents)
  assert(type(query) == "string" and #query >= 1 and #query <= 256, "oracle query")
  local items, ids = {}, {}
  for d = 1, #documents do
    local found = false
    for p = 1, #documents[d] - #query + 1 do
      if documents[d]:sub(p, p + #query - 1) == query then
        items[#items + 1] = { document_id = d, offset = p }
        found = true
      end
    end
    if found then ids[#ids + 1] = d end
  end
  order = order or M.suffixes(documents)
  -- Linear scan, with freshly sliced suffixes, rather than binary searching ranks.
  local lo, hi = #order + 1, #order + 1
  for i, entry in ipairs(order) do
    local suffix = documents[entry.document_id]:sub(entry.offset)
    local matches = suffix:sub(1, #query) == query
    if matches then
      if lo == #order + 1 then lo = i end
      hi = i + 1
    elseif lo == #order + 1 and lexical(query, suffix) then
      lo, hi = i, i
      break
    end
  end
  return {
    range = { lo = lo, hi = hi, count = #items },
    occurrences = { count = #items, complete = true, items = items },
    distinct_documents = { count = #ids, documents = ids }
  }
end

return M
