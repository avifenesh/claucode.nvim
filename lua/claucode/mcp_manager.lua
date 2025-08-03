local M = {}

-- Get the claude command path
local function get_claude_command()
  local config = require("claucode").get_config()
  return config.command or "claude"
end

-- Check if our MCP server is already added to Claude (async)
local function is_mcp_server_added_async(callback)
  local claude_cmd = get_claude_command()
  local output = ""
  
  vim.fn.jobstart({claude_cmd, "mcp", "list"}, {
    on_stdout = function(_, data)
      if data then
        output = output .. table.concat(data, "\n")
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        callback(false)
      else
        -- Look for our server name in the output
        callback(output:match("claucode%-nvim") ~= nil)
      end
    end
  })
end

-- Add our MCP server to Claude configuration (async)
function M.add_mcp_server(callback)
  -- Check if already added
  is_mcp_server_added_async(function(is_added)
    if is_added then
      -- MCP server already configured - silent
      if callback then callback(true) end
      return
    end
    
    -- Continue with the rest of the function
    M._continue_add_mcp_server(callback)
  end)
end

-- Internal function to continue adding MCP server
function M._continue_add_mcp_server(callback)
  
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
    if mcp.build_async then
      vim.notify("MCP server not found, attempting to build...", vim.log.levels.DEBUG)
      mcp.build_async(require("claucode").get_config(), function(success)
        if success and vim.fn.filereadable(mcp_server) == 1 then
          -- Continue with adding the server
          M._do_add_mcp_server(mcp_server, callback)
        else
          vim.notify("MCP server build failed. Path: " .. mcp_server, vim.log.levels.ERROR)
          if callback then callback(false) end
        end
      end)
      return
    else
      vim.notify("MCP server not built. Please build it first.", vim.log.levels.ERROR)
      if callback then callback(false) end
      return
    end
  else
    vim.notify("Found MCP server at: " .. mcp_server, vim.log.levels.DEBUG)
  end
  
  -- Continue with adding the server
  M._do_add_mcp_server(mcp_server, callback)
end

-- Actually add the MCP server
function M._do_add_mcp_server(mcp_server, callback)
  
  -- Add the MCP server using claude mcp add command
  local claude_cmd = get_claude_command()
  
  -- Adding MCP server to Claude configuration
  
  local output = ""
  vim.fn.jobstart({claude_cmd, "mcp", "add", "--scope", "user", "claucode-nvim", "node", mcp_server}, {
    on_stdout = function(_, data)
      if data then
        output = output .. table.concat(data, "\n")
      end
    end,
    on_stderr = function(_, data)
      if data then
        output = output .. table.concat(data, "\n")
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.notify("Failed to add MCP server: " .. output, vim.log.levels.ERROR)
        
        -- Check if it's because claude doesn't support mcp subcommand
        if output:match("Unknown command") or output:match("command not found") then
          vim.notify("Your Claude CLI version doesn't support 'mcp' command.", vim.log.levels.ERROR)
          vim.notify("Please update Claude Code CLI to the latest version.", vim.log.levels.ERROR)
        end
        
        if callback then callback(false) end
      else
        -- MCP server added successfully
        if callback then callback(true) end
      end
    end
  })
end

-- Remove our MCP server from Claude configuration
function M.remove_mcp_server()
  local claude_cmd = get_claude_command()
  local cmd = claude_cmd .. " mcp remove claucode-nvim"
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
      M.add_mcp_server(function(success)
        if success then
          -- MCP server setup complete
        end
      end)
    end, 1000)
  end
end

return M