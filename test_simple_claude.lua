-- Simple test to check if Claude is working
vim.notify("Testing basic Claude functionality...", vim.log.levels.INFO)

-- Test with a minimal configuration
local bridge = require("claucode.bridge")

-- Register all callbacks to see what's happening
bridge.register_callback("on_start", function()
  vim.notify("[START] Claude started", vim.log.levels.INFO)
end)

bridge.register_callback("on_stream", function(text)
  vim.notify("[STREAM] " .. vim.inspect(text):sub(1, 100), vim.log.levels.INFO)
end)

bridge.register_callback("on_result", function(result)
  vim.notify("[RESULT] " .. vim.inspect(result):sub(1, 200), vim.log.levels.INFO)
end)

bridge.register_callback("on_tool_use", function(tool)
  vim.notify("[TOOL] " .. vim.inspect(tool):sub(1, 100), vim.log.levels.INFO)
end)

bridge.register_callback("on_exit", function(code, signal)
  vim.notify("[EXIT] Code: " .. tostring(code) .. ", Signal: " .. tostring(signal), vim.log.levels.INFO)
end)

-- Send a simple test prompt
vim.defer_fn(function()
  vim.notify("Sending test prompt...", vim.log.levels.INFO)
  local success = bridge.send_to_claude("Say hello", {})
  vim.notify("Send result: " .. tostring(success), vim.log.levels.INFO)
end, 500)