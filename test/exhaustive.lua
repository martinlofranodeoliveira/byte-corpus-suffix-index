-- Copyright 2026 Lofrano Tecnologia. MIT license.
return function(T)
  local I = require("byte_corpus_index")
  local oracle = require("byte_corpus_oracle")
  local function words(maximum, include_empty)
    local all = include_empty and { "" } or {}
    local level = { "" }
    for _ = 1, maximum do
      local next_level = {}
      for _, prefix in ipairs(level) do
        for _, byte in ipairs({ "\0", "\255" }) do
          local word = prefix .. byte
          next_level[#next_level + 1] = word
          all[#all + 1] = word
        end
      end
      level = next_level
    end
    return all
  end
  local documents, patterns = words(4, true), words(3, false)
  T.eq(#documents, 31); T.eq(#patterns, 14)
  local pairs, queries = 0, 0
  for _, a in ipairs(documents) do
    for _, b in ipairs(documents) do
      pairs = pairs + 1
      local corpus = { a, b }
      local handle = assert(I.build(corpus))
      local order = oracle.suffixes(corpus)
      T.order(assert(I.suffixes(handle)).items, order)
      for _, pattern in ipairs(patterns) do
        queries = queries + 1
        local expected = oracle.analyze(corpus, pattern, order)
        local range = assert(I.prefix_range(handle, pattern))
        T.eq(range.lo, expected.range.lo, "exhaustive lower endpoint")
        T.eq(range.hi, expected.range.hi, "exhaustive upper endpoint")
        T.eq(range.count, expected.occurrences.count, "exhaustive range count")
        local occurrences = assert(I.occurrences(handle, pattern, 65536))
        T.eq(occurrences.complete, true)
        T.eq(occurrences.count, expected.occurrences.count)
        T.order(occurrences.items, expected.occurrences.items)
        local distinct = assert(I.distinct_documents(handle, pattern))
        T.eq(distinct.count, expected.distinct_documents.count)
        T.eq(#distinct.documents, #expected.distinct_documents.documents)
        for i, id in ipairs(expected.distinct_documents.documents) do
          T.eq(distinct.documents[i], id, "exhaustive document identity")
        end
        local capped = assert(I.occurrences(handle, pattern, 0))
        T.eq(capped.count, expected.occurrences.count)
        T.eq(capped.complete, expected.occurrences.count == 0)
        if expected.occurrences.count > 0 then T.eq(capped.items, nil) end
      end
    end
  end
  T.eq(pairs, 961); T.eq(queries, 13454)
end
