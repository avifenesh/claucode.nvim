-- Debug MCP setup
vim.notify("=== MCP Debug Information ===", vim.log.levels.INFO)

-- Check config
local config = require("claucode").get_config()
vim.notify("show_diff enabled: " .. tostring(config.bridge and config.bridge.show_diff), vim.log.levels.INFO)
vim.notify("MCP enabled: " .. tostring(config.mcp and config.mcp.enabled), vim.log.levels.INFO)

-- Check if MCP module is loaded
local ok, mcp = pcall(require, "claucode.mcp")
if ok then
  vim.notify("MCP module loaded successfully", vim.log.levels.INFO)
  
  -- Check if diff watcher is running
  if mcp.diff_watcher_timer then
    vim.notify("Diff watcher is RUNNING", vim.log.levels.INFO)
  else
    vim.notify("Diff watcher is NOT running", vim.log.levels.WARN)
    
    -- Try to start it manually
    vim.notify("Starting diff watcher manually...", vim.log.levels.INFO)
    mcp.start_diff_watcher()
    
    if mcp.diff_watcher_timer then
      vim.notify("Diff watcher started successfully!", vim.log.levels.INFO)
    else
      vim.notify("Failed to start diff watcher", vim.log.levels.ERROR)
    end
  end
else
  vim.notify("Failed to load MCP module: " .. tostring(mcp), vim.log.levels.ERROR)
end

-- Check MCP server in Claude
vim.notify("Checking MCP server registration...", vim.log.levels.INFO)
local mcp_manager = require("claucode.mcp_manager")
mcp_manager.add_mcp_server(function(success)
  if success then
    vim.notify("MCP server is registered with Claude", vim.log.levels.INFO)
  else
    vim.notify("MCP server registration check failed", vim.log.levels.ERROR)
  end
end)

-- Test creating a diff request
vim.defer_fn(function()
  vim.notify("Creating test diff request...", vim.log.levels.INFO)
  local data_dir = vim.env.XDG_DATA_HOME or vim.fn.expand("~/.local/share")
  local diff_dir = data_dir .. "/claucode/diffs"
  vim.fn.mkdir(diff_dir, "p")
  
  local test_request = {
    hash = "debug_test_" .. os.time(),
    filepath = "/tmp/debug_test.txt",
    original = "Debug original content",
    modified = "Debug modified content!",
    timestamp = os.time()
  }
  
  local request_file = diff_dir .. "/" .. test_request.hash .. ".request.json"
  vim.fn.writefile({vim.fn.json_encode(test_request)}, request_file)
  vim.notify("Test request written to: " .. request_file, vim.log.levels.INFO)
  
  -- Check if it gets processed
  vim.defer_fn(function()
    if vim.fn.filereadable(request_file) == 1 then
      vim.notify("Request file still exists - watcher might not be working", vim.log.levels.WARN)
      vim.fn.delete(request_file)
    else
      vim.notify("Request file was processed!", vim.log.levels.INFO)
    end
  end, 2000)
end, 3000)