-- Copyright 2026 Lofrano Tecnologia. MIT license.
local M = { MAX_BYTES = 140000, MAX_DEPTH = 8 }

-- A bounded syntax gate, not a second decoder. Values are decoded only by dkjson.
-- In particular this rejects comments, BOMs, trailing commas and trailing data.
local function syntax(text)
  local i, n = 1, #text
  local function white()
    while i <= n do
      local c = text:byte(i)
      if c ~= 32 and c ~= 9 and c ~= 10 and c ~= 13 then break end
      i = i + 1
    end
  end
  local function quoted()
    if text:sub(i, i) ~= '"' then return false end
    i = i + 1
    while i <= n do
      local c = text:byte(i)
      if c == 34 then i = i + 1; return true end
      if c < 32 then return false end
      if c == 92 then
        i = i + 1
        local escape = text:sub(i, i)
        if escape == "u" then
          local hex = text:sub(i + 1, i + 4)
          if #hex ~= 4 or hex:find("[^0-9a-fA-F]") then return false end
          i = i + 5
        elseif escape ~= "" and ('"\\/bfnrt'):find(escape, 1, true) then
          i = i + 1
        else
          return false
        end
      else
        i = i + 1
      end
    end
    return false
  end
  local function digit()
    local c = text:byte(i)
    return c ~= nil and c >= 48 and c <= 57
  end
  local function number()
    if text:sub(i, i) == "-" then i = i + 1 end
    if text:sub(i, i) == "0" then
      i = i + 1
    elseif digit() then
      repeat i = i + 1 until not digit()
    else
      return false
    end
    if text:sub(i, i) == "." then
      i = i + 1
      if not digit() then return false end
      repeat i = i + 1 until not digit()
    end
    local c = text:sub(i, i)
    if c == "e" or c == "E" then
      i = i + 1
      c = text:sub(i, i)
      if c == "+" or c == "-" then i = i + 1 end
      if not digit() then return false end
      repeat i = i + 1 until not digit()
    end
    return true
  end
  local value
  value = function(depth)
    white()
    local c = text:sub(i, i)
    if c == '"' then return quoted() end
    if c == "{" or c == "[" then
      if depth >= M.MAX_DEPTH then return false end
      local object, closing = c == "{", c == "{" and "}" or "]"
      i = i + 1
      white()
      if text:sub(i, i) == closing then i = i + 1; return true end
      while true do
        if object then
          if not quoted() then return false end
          white()
          if text:sub(i, i) ~= ":" then return false end
          i = i + 1
        end
        if not value(depth + 1) then return false end
        white()
        c = text:sub(i, i)
        i = i + 1
        if c == closing then return true end
        if c ~= "," then return false end
        white()
      end
    end
    for _, literal in ipairs({ "true", "false", "null" }) do
      if text:sub(i, i + #literal - 1) == literal then
        i = i + #literal
        return true
      end
    end
    return number()
  end
  if not value(0) then return false end
  white()
  return i == n + 1
end

function M.json()
  local ok, json = pcall(require, "dkjson")
  if not ok or type(json) ~= "table" or json.version ~= "dkjson 2.11" then
    return nil, "json_dependency"
  end
  return json
end

local function kind(value, expected)
  if type(value) ~= "table" then return false end
  local meta = getmetatable(value)
  return type(meta) == "table" and meta.__jsontype == expected
end

local function hex_size(value, minimum, maximum)
  return type(value) == "string" and #value >= minimum * 2
    and #value <= maximum * 2 and #value % 2 == 0
    and not value:find("[^0-9a-fA-F]")
end

local function unhex(value)
  return (value:gsub("..", function(pair) return string.char(tonumber(pair, 16)) end))
end

function M.parse(text)
  if type(text) ~= "string" then return nil, "invalid_manifest" end
  if #text > M.MAX_BYTES then return nil, "manifest_too_large" end
  if not syntax(text) then return nil, "invalid_manifest" end
  local json, err = M.json()
  if not json then return nil, err end
  local decoded, pos, decode_err = json.decode(text, 1, json.null)
  if decode_err or pos ~= #text + 1 and not text:sub(pos):match("^[ \t\r\n]*$") then
    return nil, "invalid_manifest"
  end
  if not kind(decoded, "object") then return nil, "invalid_manifest" end
  for key in pairs(decoded) do
    if key ~= "documents_hex" and key ~= "query_hex" and key ~= "result_cap" then
      return nil, "invalid_manifest"
    end
  end
  local input = decoded.documents_hex
  if not kind(input, "array") then return nil, "invalid_manifest" end
  local count, highest, total = 0, 0, 0
  for key, value in pairs(input) do
    count = count + 1
    if count > 32 or math.type(key) ~= "integer" or key < 1 or key > 32 then
      return nil, "invalid_manifest"
    end
    if not hex_size(value, 0, 4096) then return nil, "invalid_manifest" end
    total = total + #value // 2
    if total > 65536 then return nil, "invalid_manifest" end
    highest = math.max(highest, key)
  end
  if highest ~= count or not hex_size(decoded.query_hex, 1, 256) then
    return nil, "invalid_manifest"
  end
  local cap = decoded.result_cap
  if cap ~= nil and (math.type(cap) ~= "integer" or cap < 0 or cap > 65536) then
    return nil, "invalid_manifest"
  end
  local documents = {}
  for d = 1, count do documents[d] = unhex(input[d]) end
  return { documents = documents, query = unhex(decoded.query_hex), cap = cap }
end

return M
