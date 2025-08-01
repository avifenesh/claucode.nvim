-- Test Claude command directly
local config = require("claucode").get_config()

vim.notify("=== Testing Claude Directly ===", vim.log.levels.INFO)

-- Test 1: Simple command
local cmd = config.command .. " -p 'say hello'"
vim.notify("Running: " .. cmd, vim.log.levels.INFO)

local handle = io.popen(cmd .. " 2>&1")
local output = handle:read("*a")
local success = handle:close()

vim.notify("Success: " .. tostring(success), vim.log.levels.INFO)
vim.notify("Output length: " .. #output, vim.log.levels.INFO)
if #output > 0 then
  vim.notify("First 300 chars: " .. output:sub(1, 300), vim.log.levels.INFO)
else
  vim.notify("No output received!", vim.log.levels.ERROR)
end

-- Test 2: Check what our bridge is actually doing
local bridge = require("claucode.bridge")

-- Register ALL callbacks
bridge.register_callback("on_start", function()
  vim.notify("[CALLBACK] on_start triggered", vim.log.levels.INFO)
end)

bridge.register_callback("on_stream", function(data)
  vim.notify("[CALLBACK] on_stream: " .. vim.inspect(data):sub(1, 100), vim.log.levels.INFO)
end)

bridge.register_callback("on_result", function(result)
  vim.notify("[CALLBACK] on_result: " .. vim.inspect(result):sub(1, 200), vim.log.levels.INFO)
end)

bridge.register_callback("on_exit", function(code, signal)
  vim.notify("[CALLBACK] on_exit: code=" .. tostring(code) .. " signal=" .. tostring(signal), vim.log.levels.INFO)
end)

-- Send a test prompt
vim.defer_fn(function()
  vim.notify("Sending via bridge...", vim.log.levels.INFO)
  local success = bridge.send_to_claude("say hello", {})
  vim.notify("Bridge send result: " .. tostring(success), vim.log.levels.INFO)
end, 500)