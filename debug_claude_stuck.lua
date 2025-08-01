-- Debug why Claude is stuck on "thinking"
vim.notify("=== Claude Debug ===", vim.log.levels.INFO)

-- Check Claude config
local config = require("claucode").get_config()
vim.notify("Command: " .. config.command, vim.log.levels.INFO)
vim.notify("MCP enabled: " .. tostring(config.mcp and config.mcp.enabled), vim.log.levels.INFO)
vim.notify("Show diff: " .. tostring(config.bridge and config.bridge.show_diff), vim.log.levels.INFO)

-- Test simple Claude command
vim.defer_fn(function()
  vim.notify("Testing Claude command...", vim.log.levels.INFO)
  
  -- Try to send a simple prompt
  local success = require("claucode.bridge").send_to_claude("echo test", {})
  vim.notify("Command sent: " .. tostring(success), vim.log.levels.INFO)
  
  -- Monitor callbacks
  local bridge = require("claucode.bridge")
  bridge.register_callback("on_start", function()
    vim.notify("Claude started!", vim.log.levels.INFO)
  end)
  
  bridge.register_callback("on_stream", function(text)
    vim.notify("Stream: " .. (text:sub(1, 50) or ""), vim.log.levels.INFO)
  end)
  
  bridge.register_callback("on_result", function(result)
    vim.notify("Result received!", vim.log.levels.INFO)
  end)
  
  bridge.register_callback("on_exit", function(code)
    vim.notify("Claude exited with code: " .. tostring(code), vim.log.levels.INFO)
  end)
end, 1000)