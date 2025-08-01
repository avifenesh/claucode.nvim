-- Test Claude without MCP to isolate the issue
vim.notify("Testing Claude without MCP...", vim.log.levels.INFO)

-- Temporarily disable MCP
local config = require("claucode").get_config()
local original_show_diff = config.bridge.show_diff
local original_mcp_enabled = config.mcp.enabled

config.bridge.show_diff = false
config.mcp.enabled = false

-- Now test Claude
vim.defer_fn(function()
  vim.cmd("Claude test without MCP")
  
  -- Restore settings after 5 seconds
  vim.defer_fn(function()
    config.bridge.show_diff = original_show_diff
    config.mcp.enabled = original_mcp_enabled
    vim.notify("Settings restored", vim.log.levels.INFO)
  end, 5000)
end, 500)