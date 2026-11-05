-- Copyright 2026 Lofrano Tecnologia. MIT license.
local M = { VERSION = "0.1.0" }
local states = setmetatable({}, { __mode = "k" })
local DEFAULT_CAP, MAX_CAP = 4096, 65536

local function admit(documents)
  if type(documents) ~= "table" or getmetatable(documents) ~= nil then
    return nil, "invalid_documents"
  end
  local count, highest, total, longest = 0, 0, 0, 0
  for key, value in next, documents do
    count = count + 1
    if count > 32 then return nil, "too_many_documents" end
    if math.type(key) ~= "integer" or key < 1 then
      return nil, "invalid_documents"
    end
    if key > 32 then return nil, "too_many_documents" end
    if type(value) ~= "string" then return nil, "invalid_document" end
    local size = #value
    if size > 4096 then return nil, "document_too_large" end
    total = total + size
    if total > 65536 then return nil, "corpus_too_large" end
    highest = math.max(highest, key)
    longest = math.max(longest, size)
  end
  if highest ~= count then return nil, "invalid_documents" end
  return { documents = count, bytes = total, longest = longest }
end

local function cap_value(cap)
  if cap == nil then return DEFAULT_CAP end
  if math.type(cap) ~= "integer" or cap < 0 or cap > MAX_CAP then
    return nil, "invalid_cap"
  end
  return cap
end

local function checked(index, query)
  local state = states[index]
  if not state then return nil, "invalid_index" end
  if type(query) ~= "string" or #query < 1 or #query > 256 then
    return nil, "invalid_query"
  end
  return state
end

function M.build(documents)
  local admission, err = admit(documents)
  if not admission then return nil, err end
  -- Nothing is published, and no suffix storage is allocated, before admission.
  local docs, sa, owners, offsets, ends, ranks = {}, {}, {}, {}, {}, {}
  local n = 0
  for document_id = 1, admission.documents do
    local text = documents[document_id]
    docs[document_id] = text
    for offset = 1, #text do
      n = n + 1
      sa[n], owners[n], offsets[n] = n, document_id, offset
      ranks[n] = string.byte(text, offset) + 1
    end
    ends[document_id] = n
  end
  if n > 0 then
    local width = 1
    while true do
      local function second(id)
        if id + width <= ends[owners[id]] then return ranks[id + width] end
        return 0
      end
      table.sort(sa, function(a, b)
        if ranks[a] ~= ranks[b] then return ranks[a] < ranks[b] end
        local ar, br = second(a), second(b)
        if ar ~= br then return ar < br end
        -- IDs were assigned in document/offset order. Ties must not
        -- participate in rank equivalence, only in the total sort order.
        return a < b
      end)
      local next_ranks, classes, previous = {}, 0, nil
      for position = 1, n do
        local id = sa[position]
        if previous == nil or ranks[id] ~= ranks[previous]
          or second(id) ~= second(previous) then
          classes = classes + 1
        end
        next_ranks[id] = classes
        previous = id
      end
      ranks = next_ranks
      if classes == n or width * 2 >= admission.longest then break end
      width = width * 2
    end
  end
  local handle = setmetatable({}, {
    __metatable = "byte-corpus-index",
    __newindex = function() error("index is opaque", 2) end
  })
  states[handle] = {
    docs = docs, sa = sa, owners = owners, offsets = offsets,
    documents = admission.documents, bytes = admission.bytes, size = n
  }
  return handle
end

-- Compare a suffix with a pattern: zero means the whole pattern is a prefix.
local function compare(state, id, query)
  local text, offset = state.docs[state.owners[id]], state.offsets[id]
  for k = 1, #query do
    local a = string.byte(text, offset + k - 1)
    if a == nil then return -1 end
    local b = string.byte(query, k)
    if a < b then return -1 end
    if a > b then return 1 end
  end
  return 0
end

local function bounds(state, query)
  local function search(upper)
    local lo, hi = 1, state.size + 1
    while lo < hi do
      local mid = (lo + hi) // 2
      local relation = compare(state, state.sa[mid], query)
      if relation < 0 or (upper and relation == 0) then
        lo = mid + 1
      else
        hi = mid
      end
    end
    return lo
  end
  return search(false), search(true)
end

function M.prefix_range(index, query)
  local state, err = checked(index, query)
  if not state then return nil, err end
  local lo, hi = bounds(state, query)
  return { lo = lo, hi = hi, count = hi - lo }
end

local function position(state, id)
  return { document_id = state.owners[id], offset = state.offsets[id] }
end

function M.occurrences(index, query, cap)
  local state, err = checked(index, query)
  if not state then return nil, err end
  local limit, cap_err = cap_value(cap)
  if limit == nil then return nil, cap_err end
  local lo, hi = bounds(state, query)
  local count = hi - lo
  if count > limit then return { count = count, complete = false } end
  local items = {}
  for i = lo, hi - 1 do items[#items + 1] = position(state, state.sa[i]) end
  table.sort(items, function(a, b)
    if a.document_id ~= b.document_id then return a.document_id < b.document_id end
    return a.offset < b.offset
  end)
  return { count = count, complete = true, items = items }
end

function M.distinct_documents(index, query)
  local state, err = checked(index, query)
  if not state then return nil, err end
  local lo, hi = bounds(state, query)
  local seen, documents = {}, {}
  for i = lo, hi - 1 do seen[state.owners[state.sa[i]]] = true end
  for document_id = 1, state.documents do
    if seen[document_id] then documents[#documents + 1] = document_id end
  end
  return { count = #documents, documents = documents }
end

-- Bounded inspection, not a persistent representation.
function M.suffixes(index, cap)
  local state = states[index]
  if not state then return nil, "invalid_index" end
  local limit, err = cap_value(cap)
  if limit == nil then return nil, err end
  if state.size > limit then return { count = state.size, complete = false } end
  local items = {}
  for i = 1, state.size do items[i] = position(state, state.sa[i]) end
  return { count = state.size, complete = true, items = items }
end

function M.stats(index)
  local state = states[index]
  if not state then return nil, "invalid_index" end
  return { documents = state.documents, bytes = state.bytes, suffixes = state.size }
end

return M
