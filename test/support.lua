-- Copyright 2026 Lofrano Tecnologia. MIT license.
local T = { assertions = 0, owned = {} }

function T.check(condition, message)
  T.assertions = T.assertions + 1
  if not condition then error(message or "check failed", 2) end
end

function T.eq(actual, expected, message)
  T.check(actual == expected, (message or "equality") .. ": expected " .. tostring(expected)
    .. ", got " .. tostring(actual))
end

function T.positions(actual, expected)
  T.eq(#actual, #expected, "position length")
  for i = 1, #expected do
    T.eq(actual[i].document_id, expected[i][1], "document identity")
    T.eq(actual[i].offset, expected[i][2], "offset")
  end
end

function T.order(actual, expected)
  T.eq(#actual, #expected, "order length")
  for i = 1, #expected do
    T.eq(actual[i].document_id, expected[i].document_id, "ordered document")
    T.eq(actual[i].offset, expected[i].offset, "ordered offset")
  end
end

function T.rejected(code, fn, ...)
  local value, err = fn(...)
  T.eq(value, nil, "rejected value")
  T.eq(err, code, "rejection code")
end

function T.quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

function T.write(path, contents)
  local file = assert(io.open(path, "wb"))
  assert(file:write(contents))
  assert(file:close())
end

function T.read(path)
  local file = assert(io.open(path, "rb"))
  local contents = assert(file:read("a"))
  assert(file:close())
  return contents
end

function T.tempfile(contents)
  local path = os.tmpname()
  T.owned[#T.owned + 1] = path
  T.write(path, contents or "")
  return path
end

function T.tempdir()
  local path = os.tmpname()
  assert(os.remove(path))
  local ok = os.execute("mkdir " .. T.quote(path))
  assert(ok, "temporary directory")
  T.owned[#T.owned + 1] = path
  return path
end

function T.child(command, stdout_path)
  local out = stdout_path or T.tempfile()
  local err = T.tempfile()
  local ok, reason, code = os.execute(command .. " >" .. T.quote(out) .. " 2>" .. T.quote(err))
  local status = reason == "exit" and code or 127
  if ok == true then status = 0 end
  return status, stdout_path and "" or T.read(out), T.read(err)
end

function T.cli(arguments, stdout_path)
  local command = T.quote(T.lua) .. " " .. T.quote(T.root .. "/bin/byte_corpus_index.lua")
  for _, argument in ipairs(arguments) do command = command .. " " .. T.quote(argument) end
  return T.child(command, stdout_path)
end

function T.cleanup()
  for i = #T.owned, 1, -1 do os.remove(T.owned[i]) end
end

return T
