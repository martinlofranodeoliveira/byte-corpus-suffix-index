-- Copyright 2026 Lofrano Tecnologia. MIT license.
local root = arg[0]:match("^(.*)/test/run%.lua$") or "."
package.path = root .. "/lua/?.lua;" .. root .. "/test/?.lua;" .. root .. "/build/dependencies/?.lua;" .. package.path
local T = require("support")
local pwd = assert(io.popen("pwd", "r"))
local working = assert(pwd:read("l"))
assert(pwd:close())
T.root = root:sub(1, 1) == "/" and root or working .. "/" .. root
T.lua = os.getenv("LUA_BIN") or arg[-1] or "lua5.4"
local ok, message = xpcall(function()
  assert(_VERSION == "Lua 5.4", "Lua 5.4 required")
  assert(math.maxinteger >= 2147483647, "Lua integer support required")
  assert(require("byte_corpus_manifest").json(), "prepare dkjson 2.11 first")
  for _, suite in ipairs({ "core", "exhaustive", "cli" }) do
    require(suite)(T)
    assert(io.stdout:write(suite .. ": ok\n"))
    assert(io.stdout:flush())
  end
end, debug.traceback)
T.cleanup()
if not ok then
  io.stderr:write(message .. "\n")
  os.exit(1)
end
assert(io.stdout:write("all tests passed (" .. T.assertions .. " checks)\n"))
assert(io.stdout:flush())
