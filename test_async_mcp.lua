-- Test async MCP setup
vim.notify("Testing async MCP setup...", vim.log.levels.INFO)

-- Add a marker to show when the test starts
local start_time = vim.loop.hrtime()

-- Load the MCP manager
local mcp_manager = require("claucode.mcp_manager")

-- Test async add
mcp_manager.add_mcp_server(function(success)
  local elapsed = (vim.loop.hrtime() - start_time) / 1e9
  vim.notify(string.format("MCP server add completed in %.2f seconds", elapsed), vim.log.levels.INFO)
  vim.notify("Success: " .. tostring(success), vim.log.levels.INFO)
end)

vim.notify("Async operation started, should return immediately", vim.log.levels.INFO)