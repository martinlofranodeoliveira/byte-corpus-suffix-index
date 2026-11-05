-- Copyright 2026 Lofrano Tecnologia. MIT license.
return function(T)
  local I = require("byte_corpus_index")
  local h = assert(I.build({ "banana", "ananas", "band" }))
  local golden = {
    {1,6}, {1,4}, {1,2}, {2,1}, {2,3}, {3,2}, {2,5}, {1,1},
    {3,1}, {3,4}, {1,5}, {1,3}, {2,2}, {2,4}, {3,3}, {2,6}
  }
  T.positions(assert(I.suffixes(h)).items, golden)
  local ana = assert(I.occurrences(h, "ana"))
  T.eq(ana.count, 4)
  T.positions(ana.items, { {1,2}, {1,4}, {2,1}, {2,3} })
  local range = assert(I.prefix_range(h, "ana"))
  T.eq(range.lo, 2); T.eq(range.hi, 6); T.eq(range.count, 4)
  local docs = assert(I.distinct_documents(h, "ana"))
  T.eq(docs.count, 2); T.eq(docs.documents[1], 1); T.eq(docs.documents[2], 2)
  T.positions(assert(I.occurrences(h, "ban")).items, { {1,1}, {3,1} })
  local absent = assert(I.prefix_range(h, "xyz"))
  T.eq(absent.lo, 17); T.eq(absent.hi, 17)
  T.eq(assert(I.occurrences(h, "xyz")).count, 0)
  T.eq(assert(I.distinct_documents(h, "xyz")).count, 0)
  local capped = assert(I.occurrences(h, "ana", 3))
  T.eq(capped.complete, false); T.eq(capped.count, 4); T.eq(capped.items, nil)
  T.eq(assert(I.occurrences(h, "xyz", 0)).complete, true)
  T.eq(assert(I.suffixes(h, 0)).items, nil)

  local boundary = assert(I.build({ "ab", "cd" }))
  T.eq(assert(I.occurrences(boundary, "bc")).count, 0)
  local binary = assert(I.build({ "\0\255\0" }))
  T.positions(assert(I.suffixes(binary)).items, { {1,3}, {1,1}, {1,2} })
  T.positions(assert(I.occurrences(binary, "\0")).items, { {1,1}, {1,3} })
  T.positions(assert(I.occurrences(binary, "\255\0")).items, { {1,2} })
  for _, input in ipairs({ { "a", "aa" }, { "a", "aa", "" } }) do
    T.positions(assert(I.suffixes(assert(I.build(input)))).items, { {1,1}, {2,2}, {2,1} })
  end
  local empty = assert(I.build({ "", "", "" }))
  T.eq(assert(I.stats(empty)).documents, 3)
  T.eq(assert(I.suffixes(empty)).count, 0)
  local er = assert(I.prefix_range(empty, "a"))
  T.eq(er.lo, 1); T.eq(er.hi, 1)
  local gap = assert(I.build({ "", "x", "" }))
  T.positions(assert(I.occurrences(gap, "x")).items, { {2,1} })

  local source = { "aaaa", "ba" }
  local private = assert(I.build(source))
  source[1], source[2], source[3] = "changed", "", "new"
  local exposed = assert(I.occurrences(private, "aa"))
  exposed.items[1].offset = 999
  exposed.items[2] = nil
  local full = assert(I.suffixes(private))
  full.items[1].document_id = 99
  local distinct = assert(I.distinct_documents(private, "a"))
  distinct.documents[1] = 99
  local stats = assert(I.stats(private)); stats.bytes = 999
  local pr = assert(I.prefix_range(private, "aa")); pr.lo = 999
  T.positions(assert(I.occurrences(private, "aa")).items, { {1,1}, {1,2}, {1,3} })
  T.eq(assert(I.stats(private)).bytes, 6)
  T.eq(assert(I.distinct_documents(private, "a")).documents[1], 1)
  T.eq(pcall(function() private.extra = true end), false)
  rawset(private, "docs", { "not captured" })
  T.eq(assert(I.occurrences(private, "aa")).count, 3)

  T.rejected("invalid_documents", I.build, nil)
  T.rejected("invalid_documents", I.build, "a")
  T.rejected("invalid_documents", I.build, { [2] = "x" })
  T.rejected("invalid_documents", I.build, { [1] = "x", other = "y" })
  T.rejected("invalid_documents", I.build, { [0] = "x" })
  T.rejected("invalid_documents", I.build, { [1.5] = "x" })
  T.rejected("invalid_document", I.build, { false })
  T.rejected("document_too_large", I.build, { string.rep("a", 4097) })
  local touched = false
  local hostile = setmetatable({}, {
    __index = function() touched = true; error("getter") end,
    __pairs = function() touched = true; error("pairs") end,
    __len = function() touched = true; error("length") end
  })
  T.rejected("invalid_documents", I.build, hostile)
  T.eq(touched, false)
  local many = {}
  for i = 1, 33 do many[i] = "" end
  T.rejected("too_many_documents", I.build, many)
  many[33] = nil
  T.eq(assert(I.stats(assert(I.build(many)))).documents, 32)

  for _, query in ipairs({ "", string.rep("x", 257), false, {}, 1 }) do
    T.rejected("invalid_query", I.prefix_range, h, query)
    T.rejected("invalid_query", I.occurrences, h, query)
    T.rejected("invalid_query", I.distinct_documents, h, query)
  end
  T.rejected("invalid_query", I.occurrences, h, nil)
  for _, cap in ipairs({ -1, 65537, math.maxinteger, 3.0, 0.5, math.huge, -math.huge, 0/0, "3", false, {} }) do
    T.rejected("invalid_cap", I.occurrences, h, "ana", cap)
    T.rejected("invalid_cap", I.suffixes, h, cap)
  end
  T.rejected("invalid_index", I.prefix_range, {}, "a")
  T.rejected("invalid_index", I.occurrences, nil, "a")
  T.rejected("invalid_index", I.distinct_documents, false, "a")
  T.rejected("invalid_index", I.suffixes, {})
  T.rejected("invalid_index", I.stats, {})

  -- Exercise admission at both total-byte boundaries, and a huge matching range
  -- whose occurrence array must not be allocated under a small cap.
  local maximum = {}
  for i = 1, 16 do maximum[i] = string.rep("a", 4096) end
  local big = assert(I.build(maximum))
  T.eq(assert(I.stats(big)).bytes, 65536)
  local large = assert(I.occurrences(big, "a", 3))
  T.eq(large.count, 65536); T.eq(large.complete, false); T.eq(large.items, nil)
  T.eq(assert(I.distinct_documents(big, "a")).count, 16)
  T.eq(assert(I.prefix_range(big, string.rep("a", 256))).count, 16 * 3841)
  T.eq(math.type(large.count), "integer")
  maximum[17] = "a"
  T.rejected("corpus_too_large", I.build, maximum)
  T.eq(assert(I.stats(big)).bytes, 65536)
end
