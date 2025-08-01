local M = {}

-- Check if our MCP server is already added to Claude
local function is_mcp_server_added()
  -- Check if claude has our server configured
  -- We'll check by running `claude mcp list` and parsing output
  local output = vim.fn.system("claude mcp list 2>&1")
  if vim.v.shell_error ~= 0 then
    return false
  end
  
  -- Look for our server name in the output
  return output:match("claucode%-nvim") ~= nil
end

-- Add our MCP server to Claude configuration
function M.add_mcp_server()
  -- Check if already added
  if is_mcp_server_added() then
    vim.notify("Claucode MCP server already configured in Claude", vim.log.levels.INFO)
    return true
  end
  
  -- Get the MCP server path
  local source_path = debug.getinfo(1, "S").source:match("@(.*)")
  local current_file_dir = vim.fn.fnamemodify(source_path, ":h")
  local plugin_root = vim.fn.fnamemodify(current_file_dir, ":h")
  
  -- Try multiple possible paths
  local possible_paths = {
    plugin_root .. "/mcp-server/build/index.js",
    vim.fn.stdpath("data") .. "/lazy/claucode.nvim/mcp-server/build/index.js",
    vim.fn.expand("~/.local/share/nvim/lazy/claucode.nvim/mcp-server/build/index.js")
  }
  
  local mcp_server = nil
  for _, path in ipairs(possible_paths) do
    if vim.fn.filereadable(path) == 1 then
      mcp_server = path
      break
    end
  end
  
  if not mcp_server then
    -- Log all attempted paths for debugging
    vim.notify("MCP server not found. Attempted paths:", vim.log.levels.ERROR)
    for _, path in ipairs(possible_paths) do
      vim.notify("  - " .. path, vim.log.levels.ERROR)
    end
    mcp_server = possible_paths[1] -- Use first path as fallback
  end
  
  -- Check if MCP server is built
  if vim.fn.filereadable(mcp_server) == 0 then
    -- Try to build it
    local mcp = require("claucode.mcp")
    if mcp.setup then
      vim.notify("MCP server not found, attempting to build...", vim.log.levels.INFO)
      mcp.setup(require("claucode").get_config())
      -- Check again
      if vim.fn.filereadable(mcp_server) == 0 then
        vim.notify("MCP server build failed. Path: " .. mcp_server, vim.log.levels.ERROR)
        return false
      end
    else
      vim.notify("MCP server not built. Please build it first.", vim.log.levels.ERROR)
      return false
    end
  else
    vim.notify("Found MCP server at: " .. mcp_server, vim.log.levels.DEBUG)
  end
  
  -- Add the MCP server using claude mcp add command
  local cmd = string.format(
    'claude mcp add --scope user claucode-nvim node "%s"',
    mcp_server
  )
  
  vim.notify("Adding Claucode MCP server to Claude configuration...", vim.log.levels.INFO)
  
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to add MCP server: " .. output, vim.log.levels.ERROR)
    return false
  end
  
  vim.notify("Claucode MCP server successfully added to Claude!", vim.log.levels.INFO)
  vim.notify("You may need to restart Claude for changes to take effect.", vim.log.levels.INFO)
  return true
end

-- Remove our MCP server from Claude configuration
function M.remove_mcp_server()
  local cmd = "claude mcp remove claucode-nvim"
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to remove MCP server: " .. output, vim.log.levels.ERROR)
    return false
  end
  
  vim.notify("Claucode MCP server removed from Claude", vim.log.levels.INFO)
  return true
end

-- Setup function
function M.setup(config)
  -- Only setup if MCP is enabled and show_diff is true
  if config.mcp and config.mcp.enabled and config.bridge and config.bridge.show_diff then
    -- Delay to ensure everything is loaded
    vim.defer_fn(function()
      M.add_mcp_server()
    end, 1000)
  end
end

return M